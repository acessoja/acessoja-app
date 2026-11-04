"""Synthetic isolated regression for the two transports and credential failures."""
from types import SimpleNamespace
from unittest.mock import patch

from django.core.cache import cache
from django.utils import timezone
import pytest
from rest_framework.authtoken.models import Token
from rest_framework.exceptions import Throttled
from rest_framework.test import APIClient

from usuarios.models import Usuario
from usuarios.security_throttles import LoginProtection, SecurityUnavailable

pytestmark = pytest.mark.django_db
PASSWORD = "Maple clouds!8294"


@pytest.fixture(autouse=True)
def fresh_cache():
    cache.clear()
    yield
    cache.clear()


@pytest.fixture
def user():
    return Usuario.objects.create_user("synthetic.auth", email="synthetic@example.test", password=PASSWORD)


def browser_login(user):
    browser = APIClient(enforce_csrf_checks=True)
    bootstrap = browser.get("/auth/session/login/")
    assert bootstrap.status_code == 200
    csrf = bootstrap.json()["csrfToken"]
    response = browser.post("/auth/session/login/", {"nome": user.nome, "password": PASSWORD},
                            format="json", HTTP_X_CSRFTOKEN=csrf)
    assert response.status_code == 200
    assert "token" not in response.json()
    assert response.cookies["sessionid"]["httponly"]
    assert response.cookies["sessionid"]["samesite"] == "Lax"
    return browser, response.json()["csrfToken"]


def test_cookie_login_requires_csrf_and_rejects_external_origin(user):
    browser = APIClient(enforce_csrf_checks=True)
    body = {"nome": user.nome, "password": PASSWORD}
    assert browser.post("/auth/session/login/", body).status_code == 403
    csrf = browser.get("/auth/session/login/").json()["csrfToken"]
    assert browser.post("/auth/session/login/", body, HTTP_X_CSRFTOKEN="incorrect").status_code == 403
    assert browser.post("/auth/session/login/", body, HTTP_X_CSRFTOKEN=csrf,
                        HTTP_ORIGIN="https://attacker.example").status_code == 403
    assert not Token.objects.filter(user=user).exists()


def test_cookie_authenticates_product_api_and_requires_csrf_for_mutation(user):
    browser, csrf = browser_login(user)
    response = browser.get("/api/usuarios/me/")
    assert response.status_code == 200 and response.json()["id_usuario"] == user.pk
    assert "no-store" in response["Cache-Control"]
    endpoint = "/api/usuarios/me/route-history-preferences/"
    assert browser.patch(endpoint, {"save_history": False}, format="json").status_code == 403
    assert browser.patch(endpoint, {"save_history": False}, format="json",
                         HTTP_X_CSRFTOKEN=csrf).status_code == 200
    assert browser.post("/auth/session/logout/", HTTP_X_CSRFTOKEN=csrf).status_code == 204
    assert browser.get("/api/usuarios/me/").status_code == 401


def test_absolute_cookie_ttl_applies_to_every_private_endpoint(user):
    browser, _ = browser_login(user)
    session = browser.session
    session["web_login_at"] = timezone.now().timestamp() - 43201
    session.save()
    assert browser.get("/api/usuarios/me/route-history-preferences/").status_code == 401


def test_native_me_and_revocation_remain_token_based(user):
    browser = APIClient()
    response = browser.post("/api/login/", {"nome": user.nome, "password": PASSWORD})
    browser.credentials(HTTP_AUTHORIZATION="Token " + response.json()["token"])
    assert browser.get("/api/usuarios/me/").status_code == 200
    assert browser.post("/api/usuarios/logout/").status_code == 200
    assert browser.get("/api/usuarios/me/").status_code == 401


def test_failure_progression_and_cooldowns_without_sleep():
    request = SimpleNamespace(META={"REMOTE_ADDR": "192.0.2.17"})
    guard = LoginProtection(request, "synthetic")
    now = 1793700000
    with patch("usuarios.security_throttles.time.time", side_effect=lambda: now):
        for count in range(1, 13):
            guard.check()
            guard.result(False)
            if count in (5, 6, 7, 8, 9, 10, 11, 12):
                delay = 900 if count >= 12 else 120 if count >= 8 else 30
                with pytest.raises(Throttled) as exc:
                    guard.check()
                assert exc.value.wait == delay
                now += delay
        guard.result(True)
        guard.check()
        assert cache.get(guard.key) is None
    assert "synthetic" not in guard.key and "192.0.2" not in guard.key


def test_cache_failure_is_503_not_credential_failure():
    guard = LoginProtection(SimpleNamespace(META={}), "synthetic")
    with patch("usuarios.security_throttles.cache.get", side_effect=ConnectionError):
        with pytest.raises(SecurityUnavailable):
            guard.check()


@pytest.mark.parametrize("endpoint", ["/api/login/", "/auth/token/login/", "/auth/session/login/"])
def test_login_contracts_share_failed_credential_budget(endpoint, user):
    browser = APIClient()
    for _ in range(5):
        assert browser.post("/api/login/", {"nome": user.nome, "password": "incorrect"}).status_code == 401
    response = browser.post(endpoint, {"nome": user.nome, "password": PASSWORD})
    assert response.status_code == 429
    assert 1 <= int(response["Retry-After"]) <= 30
    assert "no-store" in response["Cache-Control"]


@pytest.mark.parametrize("password,accepted", [
    ("xY!7qWe", False), ("password", False), ("12345678", False),
    ("xY!7qWe9", True), ("Maple clouds " * 8, True), ("Árvores e nuvens 雲!91 ", True),
])
def test_registration_password_policy(password, accepted):
    response = APIClient().post("/auth/users/", {"nome": "new.synthetic", "email": "NEW@example.test",
                                                 "password": password})
    assert response.status_code == (201 if accepted else 400)
    if accepted:
        account = Usuario.objects.get(nome="new.synthetic")
        assert account.check_password(password) and account.email == "new@example.test"


@pytest.mark.parametrize("name", ["ab", "admin", "with space", "invisible\u200bname", "a" * 31])
def test_registration_rejects_invalid_new_names(name):
    assert APIClient().post("/auth/users/", {"nome": name, "email": "new@example.test",
                                             "password": PASSWORD}).status_code == 400


def test_case_insensitive_name_and_email_duplicates(user):
    browser = APIClient()
    assert browser.post("/auth/users/", {"nome": user.nome.upper(), "email": "new@example.test",
                                         "password": PASSWORD}).status_code == 400
    assert browser.post("/auth/users/", {"nome": "different", "email": user.email.upper(),
                                         "password": PASSWORD}).status_code == 400


def test_deactivation_revokes_token_and_cookie_even_after_reactivation(user):
    browser, _ = browser_login(user)
    native = APIClient()
    token = Token.objects.create(user=user)
    native.credentials(HTTP_AUTHORIZATION="Token " + token.key)
    user.is_active = False
    user.save(update_fields=["is_active"])
    user.is_active = True
    user.save(update_fields=["is_active"])
    assert browser.get("/api/usuarios/me/").status_code == 401
    assert native.get("/api/usuarios/me/").status_code == 401


def test_csrf_and_missing_password_do_not_count_as_credential_failures(user):
    browser = APIClient(enforce_csrf_checks=True)
    assert browser.post("/auth/session/login/", {"nome": user.nome, "password": PASSWORD}).status_code == 403
    assert browser.post("/api/login/", {"nome": user.nome}).status_code == 400
    guard = LoginProtection(SimpleNamespace(META={"REMOTE_ADDR": "127.0.0.1"}), user.nome)
    assert cache.get(guard.key) is None


def test_base_429_does_not_count_as_bad_password(user, settings):
    settings.SECURITY_RATES = {**settings.SECURITY_RATES, "login": (1, 1, 60)}
    browser = APIClient()
    assert browser.post("/api/login/", {"nome": user.nome}).status_code == 400
    assert browser.post("/api/login/", {"nome": user.nome, "password": "incorrect"}).status_code == 429
    guard = LoginProtection(SimpleNamespace(META={"REMOTE_ADDR": "127.0.0.1"}), user.nome)
    assert cache.get(guard.key) is None


def test_base_cache_outage_returns_503_without_counting_bad_password(user):
    with patch("usuarios.security_throttles.cache.add", side_effect=ConnectionError):
        assert APIClient().post("/api/login/", {"nome": user.nome, "password": "incorrect"}).status_code == 503
    guard = LoginProtection(SimpleNamespace(META={"REMOTE_ADDR": "127.0.0.1"}), user.nome)
    assert cache.get(guard.key) is None


@pytest.mark.parametrize("endpoint", ["/api/login/", "/auth/token/login/", "/auth/session/login/"])
def test_unknown_and_wrong_password_have_identical_public_response(endpoint, user):
    browser = APIClient()
    known = browser.post(endpoint, {"nome": user.nome, "password": "incorrect"})
    unknown = browser.post(endpoint, {"nome": "unknown.synthetic", "password": "incorrect"})
    assert known.status_code == unknown.status_code == 401
    assert known.json() == unknown.json()


def test_stale_tab_identity_cannot_act_with_another_cookie_and_does_not_destroy_new_session(user):
    browser, csrf = browser_login(user)
    assert browser.get("/api/usuarios/me/", HTTP_X_SESSION_USER=str(user.pk + 1)).status_code == 401
    assert browser.patch("/api/usuarios/me/route-history-preferences/", {"save_history": False}, format="json",
                         HTTP_X_CSRFTOKEN=csrf, HTTP_X_SESSION_USER=str(user.pk + 1)).status_code == 401
    assert browser.get("/api/usuarios/me/", HTTP_X_SESSION_USER=str(user.pk)).status_code == 200


@pytest.mark.parametrize("endpoint", ["/api/login/", "/auth/token/login/", "/auth/session/login/"])
def test_extra_identifiers_and_rotating_ips_cannot_bypass_account_volume_limit(endpoint, user):
    browser = APIClient()
    with patch("usuarios.security_throttles.time.time", return_value=1793700000):
        for index in range(11):
            response = browser.post(endpoint, {"nome": user.nome, "password": "incorrect",
                                               "email": f"spoof{index}@example.test", "uid": str(index)},
                                    REMOTE_ADDR=f"192.0.2.{index + 1}")
            assert response.status_code == (401 if index < 10 else 429)
