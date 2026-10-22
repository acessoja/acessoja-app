"""I01–I04: configuration, proxy boundary, log canaries and controlled readiness failure."""
from datetime import timedelta
import io
import json
import logging
import os
from unittest.mock import patch

from django.core.cache import cache
from django.core.exceptions import ImproperlyConfigured
from django.test import RequestFactory
from django.utils import timezone
import environ
import pytest
from rest_framework.test import APIClient

from acessoja.security_middleware import ProxyGuardMiddleware, SafeEventFormatter
from acessoja.security_settings import configure_security
from usuarios.models import AccountMailJob


def configuration(tmp_path):
    return {
        'BASE_DIR': tmp_path, 'DEBUG': False,
        'SECRET_KEY': 'test-only-fake-key-ABCDEF0123456789!@#' * 3,
        'ALLOWED_HOSTS': ['staging.example.test'],
        'DATABASES': {'default': {'ENGINE': 'django.db.backends.postgresql'}},
        'CACHES': {'default': {'BACKEND': 'django.core.cache.backends.redis.RedisCache'}},
        'MIDDLEWARE': [], 'REST_FRAMEWORK': {}, 'DJOSER': {}, 'LOGGING': {},
        'CORS_ALLOWED_ORIGINS': ['https://staging.example.test'],
        'SPECTACULAR_SETTINGS': {'SWAGGER_UI_SETTINGS': {}},
    }


def stage_environment(tmp_path):
    return {'APP_ENV': 'staging', 'FRONTEND_PUBLIC_ORIGIN': 'https://staging.example.test',
            'ALLOWED_HOSTS': 'staging.example.test',
            'CSRF_TRUSTED_ORIGINS': 'https://staging.example.test',
            'EMAIL_BACKEND': 'django.core.mail.backends.smtp.EmailBackend', 'EMAIL_HOST': 'smtp.example.test',
            'EMAIL_USE_TLS': 'True', 'DEFAULT_FROM_EMAIL': 'AcessoJa <no-reply@example.test>',
            'TRUSTED_PROXY_CIDRS': '10.85.0.10/32', 'SECURE_LOG_DIR': str(tmp_path / 'logs'),
            'DELETION_JOURNAL_DIR': str(tmp_path / 'journal'), 'PRIVACY_CONTACT_EMAIL': 'privacy@example.test'}


def test_i01_staging_restricts_authentication_hosts_origins_cookies_and_logs(tmp_path):
    config = configuration(tmp_path)
    with patch.dict(os.environ, stage_environment(tmp_path), clear=True):
        configure_security(config, environ.Env())
    assert config['SECURE_SSL_REDIRECT'] and config['SESSION_COOKIE_SECURE'] and config['CSRF_COOKIE_SECURE']
    assert not config['SECURE_HSTS_PRELOAD'] and not config['SECURE_HSTS_INCLUDE_SUBDOMAINS']
    assert config['SECURE_HSTS_SECONDS'] == 3600
    assert config['REST_FRAMEWORK']['DEFAULT_AUTHENTICATION_CLASSES'] == [
        'acessoja.authentication.ExpiringTokenAuthentication']
    assert config['SPECTACULAR_SETTINGS']['SERVE_PERMISSIONS'] == ['rest_framework.permissions.IsAdminUser']
    assert not config['SPECTACULAR_SETTINGS']['SWAGGER_UI_SETTINGS']['persistAuthorization']
    assert config['LOGGING']['handlers']['safe']['class'] == 'logging.handlers.WatchedFileHandler'


@pytest.mark.parametrize('key,value', [('APP_ENV', 'production'), ('FRONTEND_PUBLIC_ORIGIN', 'http://example.test'),
                                       ('FRONTEND_PUBLIC_ORIGIN', 'https://user:password@example.test'),
                                       ('EMAIL_USE_SSL', 'True'), ('EMAIL_USE_TLS', 'False'),
                                       ('EMAIL_TIMEOUT', '0'), ('PASSWORD_RESET_TIMEOUT', '1'),
                                       ('TRUSTED_PROXY_CIDRS', '0.0.0.0/0'), ('TRUSTED_PROXY_CIDRS', 'invalid'),
                                       ('DELETION_JOURNAL_DIR', ''), ('SECURE_LOG_DIR', ''),
                                       ('CSRF_TRUSTED_ORIGINS', '*'), ('PRIVACY_CONTACT_EMAIL', ''),
                                       ('PASSWORD_RESET_CONFIRM_URL', 'https://attacker.test/{token}')])
def test_i01_invalid_staging_environment_aborts_startup(tmp_path, key, value):
    env = {**stage_environment(tmp_path), key: value}
    with patch.dict(os.environ, env, clear=True), pytest.raises(ImproperlyConfigured):
        configure_security(configuration(tmp_path), environ.Env())


@pytest.mark.parametrize('name,replacement', [('DEBUG', True), ('SECRET_KEY', 'weak'), ('ALLOWED_HOSTS', ['*']),
                                              ('CACHES', {'default': {'BACKEND': 'locmem'}}),
                                              ('DATABASES', {'default': {'ENGINE': 'sqlite'}}),
                                              ('CORS_ALLOWED_ORIGINS', ['https://*'])])
def test_i01_invalid_critical_base_setting_aborts(tmp_path, name, replacement):
    config = {**configuration(tmp_path), name: replacement}
    with patch.dict(os.environ, stage_environment(tmp_path), clear=True), pytest.raises(ImproperlyConfigured):
        configure_security(config, environ.Env())


@pytest.mark.django_db
def test_i01_invalid_host_and_cors_origin_do_not_get_authority(settings):
    settings.ALLOWED_HOSTS = ['testserver']
    settings.CORS_ALLOWED_ORIGINS = ['https://allowed.example.test']
    settings.DEBUG = False
    client = APIClient()
    assert client.get('/health/live/', HTTP_HOST='attacker.example.test').status_code == 400
    refused = client.get('/health/live/', HTTP_ORIGIN='https://attacker.example.test')
    assert 'Access-Control-Allow-Origin' not in refused
    allowed = client.get('/health/live/', HTTP_ORIGIN='https://allowed.example.test')
    assert allowed['Access-Control-Allow-Origin'] == 'https://allowed.example.test'


@pytest.mark.parametrize('remote,protocol,secure', [('203.0.113.4', 'https', False),
                                                    ('10.85.0.10', 'https', True),
                                                    ('10.85.0.10', 'https,http', False)])
def test_i02_forwarding_only_from_the_exact_proxy(settings, remote, protocol, secure):
    settings.TRUSTED_PROXY_CIDRS = ['10.85.0.10/32']
    settings.SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
    request = RequestFactory().get('/api/usuarios/me/privacy/', REMOTE_ADDR=remote,
                                   HTTP_X_FORWARDED_PROTO=protocol, HTTP_FORWARDED='for=secret',
                                   HTTP_X_FORWARDED_FOR='spoofed', HTTP_X_REAL_IP='192.0.2.44')
    captured = []
    ProxyGuardMiddleware(lambda req: captured.append(req))(request)
    assert request.is_secure() is secure
    assert 'HTTP_X_FORWARDED_FOR' not in request.META and 'HTTP_FORWARDED' not in request.META
    assert request.META['REMOTE_ADDR'] == ('192.0.2.44' if remote == '10.85.0.10' else remote)


@pytest.mark.django_db
def test_i02_plain_http_redirects_and_forged_https_cannot_bypass(settings):
    settings.TRUSTED_PROXY_CIDRS = ['10.85.0.10/32']
    settings.SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
    settings.SECURE_SSL_REDIRECT = True
    client = APIClient()
    assert client.get('/auth/users/me/', HTTP_X_FORWARDED_PROTO='https').status_code == 301
    assert client.get('/auth/users/me/', REMOTE_ADDR='10.85.0.10', HTTP_X_FORWARDED_PROTO='https').status_code == 401
    csrf = APIClient(enforce_csrf_checks=True)
    assert csrf.post('/admin/login/', {}, secure=True).status_code == 403


def test_i03_structured_logger_ignores_secret_canaries_and_exception_text():
    secrets = ['password=CANARY', 'token=secret-reset-link', 'Authorization: Token old-secret',
               'Cookie: session=private', 'synthetic-secret@example.test', '-16.328,-48.951']
    output = io.StringIO()
    handler = logging.StreamHandler(output)
    handler.setFormatter(SafeEventFormatter())
    record = logging.LogRecord('test', logging.ERROR, '', 1, ' '.join(secrets), (), None)
    record.security_event = 'http_request'
    record.status = 503
    record.duration_ms = 21.4
    record.correlation_id = 'attacker-controlled-token'
    record.exc_text = ' '.join(secrets)
    handler.handle(record)
    text = output.getvalue()
    assert all(secret not in text for secret in secrets)
    assert json.loads(text) == {'event': 'http_request', 'level': 'ERROR', 'status': 503, 'duration_ms': 21.4}


@pytest.mark.django_db
def test_i04_readiness_db_cache_and_mail_failure_are_neutral_and_recover(settings):
    cache.clear()
    client = APIClient()
    assert client.get('/health/live/').json() == {'status': 'ok'}
    assert client.get('/health/ready/').status_code == 200
    with patch('acessoja.health.connection.cursor', side_effect=ConnectionError('SECRET_DSN')):
        failure = client.get('/health/ready/')
        assert failure.status_code == 503 and failure.json() == {'status': 'unavailable'}
        assert client.get('/health/live/').status_code == 200
    assert client.get('/health/ready/').status_code == 200
    with patch('acessoja.health.cache.add', side_effect=ConnectionError('SECRET_REDIS')):
        assert client.get('/health/ready/').status_code == 503
    assert client.get('/health/ready/').status_code == 200
    job = AccountMailJob.objects.create(kind='reset', created_at=timezone.now() - timedelta(minutes=6))
    assert client.get('/health/ready/').status_code == 503
    job.delete()
    assert client.get('/health/ready/').status_code == 200
