"""Credential races, current notices and audit copies are privacy boundaries."""
from unittest.mock import patch
from types import SimpleNamespace
import json

from django.contrib.admin.models import CHANGE, LogEntry
from django.contrib.contenttypes.models import ContentType
from django.core.cache import cache
from django.db import transaction
from django.test import RequestFactory
from django.test import Client
from django.contrib.sessions.models import Session
import pytest
from rest_framework.authtoken.models import Token
from rest_framework.authentication import SessionAuthentication
from rest_framework.exceptions import NotAuthenticated
from rest_framework.test import APIClient

from acessoja.private_admin import MinimalAdminLogMixin
from locais.models import Local, VisitaRecente
from modal_avaliacao.models import ModalAvaliacao
from usuarios.account_services import change_password, locked_request_user, revoke_credentials
from usuarios.deletion_journal import journal_identity, read_receipts
from usuarios.models import PrivacyConsent, Usuario

pytestmark = pytest.mark.django_db
PASSWORD = 'Synthetic-regression!73952'


@pytest.fixture
def account(settings, tmp_path):
    cache.clear()
    settings.DELETION_JOURNAL_DIR = tmp_path / 'journal'
    journal_identity(initialize=True)
    user = Usuario.objects.create_user('synthetic-regression', email='owner@example.test', password=PASSWORD)
    token = Token.objects.create(user=user)
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f'Token {token.key}')
    yield user, token, client
    cache.clear()


@pytest.mark.parametrize('path', ['/auth/users/reset_password/', '/auth/users/reset_password_confirm/',
                                  '/api/login/', '/auth/token/login/'])
def test_non_object_json_is_bad_request_not_server_error(path):
    cache.clear()
    assert APIClient().post(path, ['unexpected'], format='json').status_code == 400


@pytest.mark.parametrize('path', ['/auth/users/me/', '/api/usuarios/perfil/?nome=synthetic-regression'])
def test_email_change_requires_current_password_and_normalizes_without_echo(account, path):
    user, _, client = account
    method = client.patch if path.startswith('/auth/') else client.put
    assert method(path, {'email': 'new@example.test'}, format='json').status_code == 400
    assert method(path, {'email': 'new@example.test', 'current_password': 'incorrect'},
                  format='json').status_code == 400
    result = method(path, {'email': 'NEW@example.test', 'current_password': PASSWORD}, format='json')
    assert result.status_code == 200 and 'current_password' not in result.json()
    user.refresh_from_db()
    assert user.email == 'new@example.test'


@pytest.mark.parametrize('path', ['/auth/users/me/', '/api/usuarios/perfil/?nome=synthetic-regression'])
def test_stale_authentication_snapshot_cannot_undo_new_password_or_revive_deleted_owner(account, path):
    user, token, _ = account
    stale = Usuario.objects.get(pk=user.pk)
    change_password(user.pk, PASSWORD, 'Synthetic-fresh!93617')
    client = APIClient()
    client.force_authenticate(user=stale, token=token)
    method = client.patch if path.startswith('/auth/') else client.put
    assert method(path, {'nome_completo': 'stale write'}, format='json').status_code == 401
    user.refresh_from_db()
    assert user.check_password('Synthetic-fresh!93617')
    user.delete()
    assert method(path, {'nome_completo': 'revival'}, format='json').status_code in {401, 404}
    assert not Usuario.objects.filter(pk=stale.pk).exists()


def test_legacy_client_cannot_create_current_notice_proof_without_acknowledging_it(account):
    user, _, client = account
    path = '/api/usuarios/me/route-history-preferences/'
    assert client.patch(path, {'save_history': True}, format='json').status_code == 400
    assert not PrivacyConsent.objects.filter(user=user).exists()
    assert client.patch(path, {'save_history': True, 'notice_version': 'obsolete'}, format='json').status_code == 400
    assert client.patch(path, {'save_history': True, 'notice_version': '2026-10-21'}, format='json').status_code == 200
    assert client.patch(path, {'save_history': False}, format='json').status_code == 200
    assert list(PrivacyConsent.objects.values_list('granted', flat=True)) == [True, False]


def test_erasing_own_visits_preserves_the_other_account_and_shared_catalog(account):
    user, _, client = account
    other = Usuario.objects.create_user('synthetic-other', password=PASSWORD, email='other@example.test')
    place = Local.objects.create(nome='Synthetic shared', endereco='Synthetic', distancia=0)
    VisitaRecente.objects.create(user=user, local=place)
    theirs = VisitaRecente.objects.create(user=other, local=place)
    assert client.delete(f'/api/visitas/limpar/?user={other.pk}').status_code == 400
    assert client.delete('/api/visitas/limpar/').status_code == 204
    assert list(VisitaRecente.objects.values_list('pk', flat=True)) == [theirs.pk]
    assert Local.objects.filter(pk=place.pk).exists()


def test_admin_audit_copies_are_minimal_export_own_metadata_and_scrub_on_deletion(account):
    user, _, client = account
    admin = Usuario.objects.create_superuser('synthetic-admin', password=PASSWORD, email='admin@example.test')
    place = Local.objects.create(nome='Synthetic shared', endereco='Synthetic', distancia=0)
    review = ModalAvaliacao.objects.create(user=user, local=place, comentario='PRIVATE_REVIEW', estrelas=4)
    content_type = ContentType.objects.get_for_model(review)
    copied = LogEntry.objects.create(user=admin, content_type=content_type, object_id=str(review.pk),
                                     object_repr='PRIVATE_REVIEW', change_message='PRIVATE_EMAIL', action_flag=CHANGE)
    request = RequestFactory().post('/admin/')
    request.user = user
    entry = MinimalAdminLogMixin().log_change(request, review, 'PRIVATE_CHANGE')
    assert entry.object_repr == 'Registro administrado' and entry.change_message == '[]'
    exported = client.post('/api/usuarios/me/data-export/', {'current_password': PASSWORD}, format='json')
    assert len(json.loads(exported.content)['categories']['admin_activity']) == 1
    assert b'PRIVATE_EMAIL' not in exported.content and admin.email.encode() not in exported.content
    assert client.post('/api/usuarios/me/delete-account/',
                       {'current_password': PASSWORD, 'confirm': True}, format='json').status_code == 204
    copied.refresh_from_db()
    assert copied.user_id == admin.pk and copied.object_repr == 'Registro removido' and copied.change_message == '[]'


def test_missing_journal_marker_or_wrong_identity_cannot_be_treated_as_empty(account, settings):
    identity = journal_identity()
    (settings.DELETION_JOURNAL_DIR / 'JOURNAL_ID').unlink()
    with pytest.raises(OSError):
        read_receipts()
    replacement = journal_identity(initialize=True)
    assert replacement != identity


def test_photo_writer_checks_live_credential_after_owner_lock(account):
    user, token, _ = account
    stale = Usuario.objects.get(pk=user.pk)
    with transaction.atomic():
        Token.objects.filter(pk=token.pk).delete()
    client = APIClient()
    client.force_authenticate(user=stale, token=token)
    assert client.post('/api/usuarios/foto/', {'nome': user.nome, 'foto_perfil': 'new'},
                       format='json').status_code == 401


def test_readiness_refuses_missing_stage_journal_but_recovers(account, settings):
    _, _, client = account
    settings.APP_ENV = 'staging'
    assert client.get('/health/ready/').status_code == 200

    with patch('acessoja.health.journal_identity', side_effect=OSError):
        assert client.get('/health/ready/').status_code == 503
    assert client.get('/health/ready/').status_code == 200


@pytest.mark.parametrize('revoked', [False, True])
def test_authenticated_session_is_checked_again_after_owner_lock(account, revoked):
    user, _, _ = account
    browser = Client()
    browser.force_login(user, backend='django.contrib.auth.backends.ModelBackend')
    session = browser.session
    request = SimpleNamespace(user=Usuario.objects.get(pk=user.pk), auth=None,
                              _authenticator=SessionAuthentication(), _request=SimpleNamespace(session=session))
    if revoked:
        revoke_credentials(user)
        assert not Session.objects.filter(session_key=session.session_key).exists()
        with transaction.atomic(), pytest.raises(NotAuthenticated):
            locked_request_user(request)
    else:
        with transaction.atomic():
            assert locked_request_user(request).pk == user.pk
