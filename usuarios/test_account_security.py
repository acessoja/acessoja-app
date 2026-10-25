"""R01–R08: synthetic accounts, memory mail and controlled clocks only."""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta
from unittest.mock import patch
import smtplib
import threading

from django.contrib.auth.tokens import default_token_generator
from django.core import mail
from django.core.cache import cache
from django.db import close_old_connections, connection
from django.test import Client
from django.utils import timezone
from djoser.utils import encode_uid
import pytest
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient

from usuarios.account_services import process_mail_jobs
from usuarios.models import AccountMailJob, Usuario

pytestmark = pytest.mark.django_db
REQUEST = "/auth/users/reset_password/"
CONFIRM = "/auth/users/reset_password_confirm/"
OLD = "Old-access!9461"
NEW = "Fresh-access!5813"


@pytest.fixture(autouse=True)
def isolated_cache(settings):
    cache.clear()
    settings.EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"
    yield
    cache.clear()


@pytest.fixture
def account():
    return Usuario.objects.create_user("recovery-synthetic", email="reset@example.test", password=OLD)


def payload(account, **extra):
    return {"uid": encode_uid(account.pk), "token": default_token_generator.make_token(account),
            "new_password": NEW, "re_new_password": NEW, **extra}


def test_r01_async_email_uses_trusted_frontend_and_no_request_host(account, settings):
    settings.FRONTEND_PUBLIC_ORIGIN = "https://web.example.test"
    settings.DJOSER = {**settings.DJOSER, "EMAIL_FRONTEND_PROTOCOL": "https",
                       "EMAIL_FRONTEND_DOMAIN": "web.example.test"}
    client = APIClient()
    response = client.post(REQUEST, {"email": " RESET@example.test "}, format="json", HTTP_HOST="testserver")
    assert response.status_code == 204
    assert not getattr(mail, "outbox", [])
    assert process_mail_jobs() == 1
    assert len(mail.outbox) == 1
    text = mail.outbox[0].body
    assert "https://web.example.test/#/recuperar-senha/" in text
    assert "testserver" not in text and OLD not in text
    assert mail.outbox[0].to == [account.email]
    assert not AccountMailJob.objects.exists()


@pytest.mark.parametrize("kind", ["existing", "missing", "inactive", "unusable"])
def test_r02_neutral_for_all_eligibility_states(account, kind):
    if kind == "inactive":
        account.is_active = False
        account.save()
    if kind == "unusable":
        account.set_unusable_password()
        account.save()
    email = "missing@example.test" if kind == "missing" else account.email
    response = APIClient().post(REQUEST, {"email": email}, format="json")
    assert response.status_code == 204 and response.content == b""
    assert response["Cache-Control"] == "private, no-store"
    process_mail_jobs()
    assert len(getattr(mail, "outbox", [])) == (1 if kind == "existing" else 0)


def test_r03_r06_valid_reset_changes_password_revokes_tokens_and_sessions(account):
    token = Token.objects.create(user=account)
    session = Client()
    session.force_login(account, backend="django.contrib.auth.backends.ModelBackend")
    previous_session = session.session.session_key
    body = payload(account)
    response = APIClient().post(CONFIRM, body, format="json")
    assert response.status_code == 204
    account.refresh_from_db()
    assert account.check_password(NEW) and not account.check_password(OLD)
    assert not Token.objects.filter(key=token.key).exists()
    from django.contrib.sessions.models import Session
    assert not Session.objects.filter(session_key=previous_session).exists()
    private = APIClient()
    private.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")
    assert private.get("/auth/users/me/").status_code == 401
    assert APIClient().post(CONFIRM, body, format="json").status_code == 400
    assert APIClient().post("/api/login/", {"nome": account.nome, "password": OLD}).status_code == 401
    assert APIClient().post("/api/login/", {"nome": account.nome, "password": NEW}).status_code == 200
    process_mail_jobs()
    assert len(mail.outbox) == 1 and NEW not in mail.outbox[0].body
    assert "senha" in mail.outbox[0].body


@pytest.mark.parametrize("changes", [{"uid": "bad!"}, {"uid": "OTk5OTk5OTk5OTk5OTk5OTk5"},
                                     {"uid": encode_uid(987654)}, {"token": "tampered"}])
def test_r04_invalid_link_preserves_password(account, changes):
    response = APIClient().post(CONFIRM, payload(account, **changes), format="json")
    assert response.status_code == 400
    account.refresh_from_db()
    assert account.check_password(OLD) and not AccountMailJob.objects.exists()


def test_r04_expired_token_controlled_clock(account, settings):
    settings.PASSWORD_RESET_TIMEOUT = 60
    now = datetime(2026, 10, 21, 12)
    with patch.object(default_token_generator, "_now", return_value=now):
        body = payload(account)
    with patch.object(default_token_generator, "_now", return_value=now + timedelta(seconds=61)):
        assert APIClient().post(CONFIRM, body, format="json").status_code == 400
    account.refresh_from_db()
    assert account.check_password(OLD)


@pytest.mark.parametrize("password,repeated", [("12345678", "12345678"), ("short", "short"),
                                               (NEW, "different")])
def test_r05_weak_or_mismatched_password(account, password, repeated):
    result = APIClient().post(CONFIRM, payload(account, new_password=password, re_new_password=repeated), format="json")
    assert result.status_code == 400
    account.refresh_from_db()
    assert account.check_password(OLD)


@pytest.mark.parametrize("endpoint", ["/auth/users/set_password/", "/api/usuarios/alterar-senha/"])
def test_r06_all_password_change_paths_validate_and_revoke(account, endpoint):
    token = Token.objects.create(user=account)
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")
    custom = "alterar-senha" in endpoint
    weak = {"nome": account.nome, "senha_atual": OLD, "nova_senha": "12345678"} if custom else {
        "current_password": OLD, "new_password": "12345678", "re_new_password": "12345678"}
    assert client.post(endpoint, weak, format="json").status_code == 400
    strong = {"nome": account.nome, "senha_atual": OLD, "nova_senha": NEW} if custom else {
        "current_password": OLD, "new_password": NEW, "re_new_password": NEW}
    assert client.post(endpoint, strong, format="json").status_code in (200, 204)
    assert client.get("/auth/users/me/").status_code == 401
    account.refresh_from_db()
    assert account.check_password(NEW)


def test_r06_public_actions_ignore_stale_authentication(account):
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION="Token invalid-old-session")
    assert client.post(REQUEST, {"email": account.email}).status_code == 204
    assert client.post(CONFIRM, payload(account), format="json").status_code == 204
    assert client.post("/auth/token/login/", {"nome": account.nome, "password": NEW}).status_code == 200


def test_r06_alternate_username_routes_are_not_an_account_reset_bypass(account):
    client = APIClient()
    client.force_authenticate(account)
    for action in ("set_nome", "reset_nome", "reset_nome_confirm", "activation", "resend_activation"):
        assert client.post(f"/auth/users/{action}/", {}, format="json").status_code == 404


def test_registration_uses_password_validators():
    response = APIClient().post("/auth/users/", {"nome": "synthetic-new", "email": "new@example.test",
                                                 "password": "12345678"})
    assert response.status_code == 400 and not Usuario.objects.filter(nome="synthetic-new").exists()


def test_r07_request_and_confirmation_throttle_use_hashed_identifiers(account, settings):
    settings.SECURITY_RATES = {**settings.SECURITY_RATES, "reset_request": (20, 2, 3600),
                               "reset_confirm": (20, 2, 900)}
    client = APIClient()
    for _ in range(2):
        assert client.post(REQUEST, {"email": account.email}).status_code == 204
    limited = client.post(REQUEST, {"email": account.email.upper()})
    assert limited.status_code == 429 and int(limited["Retry-After"]) > 0
    for _ in range(2):
        assert client.post(CONFIRM, payload(account, token="invalid"), format="json").status_code == 400
    assert client.post(CONFIRM, payload(account), format="json").status_code == 429
    keys = str(getattr(cache, "_cache", {}))
    assert account.email not in keys and "security:" in keys


def test_r07_mail_timeout_is_private_retryable_and_cannot_enumerate(account, caplog):
    with patch("djoser.email.BaseEmailMessage.send", side_effect=smtplib.SMTPException("secret@example.test TOKEN")):
        assert APIClient().post(REQUEST, {"email": account.email}).status_code == 204
        assert process_mail_jobs() == 1
    job = AccountMailJob.objects.get()
    assert job.state == "pending" and job.attempts == 1
    assert "secret@example.test" not in caplog.text and "TOKEN" not in caplog.text
    AccountMailJob.objects.filter(pk=job.pk).update(available_at=timezone.now())
    process_mail_jobs()
    assert len(mail.outbox) == 1


def test_r07_notification_failure_does_not_undo_success(account):
    assert APIClient().post(CONFIRM, payload(account), format="json").status_code == 204
    with patch("djoser.email.BaseEmailMessage.send", side_effect=TimeoutError):
        process_mail_jobs()
    account.refresh_from_db()
    assert account.check_password(NEW) and AccountMailJob.objects.get().state == "pending"


def test_cache_outage_fails_closed_without_fallback(account):
    with patch("usuarios.security_throttles.cache.add", side_effect=ConnectionError):
        assert APIClient().post(REQUEST, {"email": account.email}).status_code == 503
    assert not AccountMailJob.objects.exists()


@pytest.mark.django_db(transaction=True)
def test_r08_postgresql_concurrent_reset_accepts_only_one_confirmation(account):
    if connection.vendor != "postgresql":
        pytest.skip("Real PostgreSQL row locks required; SQLite is not concurrency evidence.")
    body = payload(account)
    barrier = threading.Barrier(2)

    def confirm():
        close_old_connections()
        try:
            barrier.wait(timeout=10)
            return APIClient().post(CONFIRM, body, format="json").status_code
        finally:
            close_old_connections()

    with ThreadPoolExecutor(max_workers=2) as pool:
        assert sorted(pool.map(lambda _: confirm(), range(2))) == [204, 400]
    assert AccountMailJob.objects.filter(kind="changed").count() == 1
