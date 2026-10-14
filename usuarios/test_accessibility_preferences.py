import json

import pytest
from django.contrib.auth import get_user_model
from drf_spectacular.generators import SchemaGenerator
from rest_framework.settings import api_settings
from rest_framework.test import APIClient

URL = "/api/usuarios/me/accessibility-preferences/"
pytestmark = pytest.mark.django_db


@pytest.fixture
def account():
    User = get_user_model()
    user = User.objects.create_user(nome="prefs-me", email="prefs@me.test", password="test-password")
    other = User.objects.create_user(nome="prefs-other", email="prefs@other.test", password="test-password",
                                     accessibility_preferences=["piso_tatil"])
    client = APIClient()
    client.force_authenticate(user)
    return user, other, client


def test_preferences_are_optional_on_signup_and_current_user_only(account):
    user, other, client = account
    response = client.get(URL)
    assert response.status_code == 200 and response.data["resources"] == []
    assert response["Cache-Control"] == "private, no-store"
    assert user.accessibility_preferences == []
    assert client.get(URL + str(other.pk) + "/").status_code == 404
    assert client.get(URL, {"nome": other.nome}).status_code == 400


def test_create_edit_deduplicate_partial_omit_and_clear(account):
    user, other, client = account
    result = client.put(URL, {"resources": ["piso_tatil", "rampa_acesso", "piso_tatil"]}, format="json")
    assert result.status_code == 200 and result.data["resources"] == ["rampa_acesso", "piso_tatil"]
    assert client.patch(URL, {}, format="json").data["resources"] == result.data["resources"]
    assert client.patch(URL, {"resources": ["atendimento_libras"]}, format="json").status_code == 200
    assert client.get(URL).data["resources"] == ["atendimento_libras"]
    assert client.delete(URL).data["resources"] == []
    assert client.put(URL, {"resources": []}, format="json").status_code == 200
    other.refresh_from_db()
    assert other.accessibility_preferences == ["piso_tatil"]


def test_get_reads_persisted_preferences_with_a_stale_authenticated_instance(account):
    user, other, client = account
    get_user_model().objects.filter(pk=user.pk).update(accessibility_preferences=["sinalizacao_visual"])
    assert user.accessibility_preferences == []
    response = client.get(URL)
    assert response.status_code == 200
    assert response.data["resources"] == ["sinalizacao_visual"]
    assert client.put(URL, {"resources": ["rampa_acesso"]}, format="json").status_code == 200
    assert client.get(URL).data["resources"] == ["rampa_acesso"]
    other.refresh_from_db()
    assert other.accessibility_preferences == ["piso_tatil"]


@pytest.mark.parametrize(
    "body",
    [
        {},
        {"resources": None},
        {"resources": "rampa_acesso"},
        {"resources": [False]},
        {"resources": ["unknown_resource"]},
        {"resources": [], "user": 1},
        {"resources": [], "nome": "prefs-other"},
        {"resources": [], "id_usuario": 1},
        {"resources": ["rampa_acesso"], "unrelated": True},
    ],
)
def test_invalid_write_is_atomic_and_never_uses_client_identity(account, body):
    user, other, client = account
    response = client.put(URL, body, format="json")
    assert response.status_code == 400
    assert isinstance(response.data, dict)
    if set(body) - {"resources"}:
        assert response.data[api_settings.NON_FIELD_ERRORS_KEY]
    user.refresh_from_db()
    other.refresh_from_db()
    assert user.accessibility_preferences == [] and other.accessibility_preferences == ["piso_tatil"]


@pytest.mark.parametrize("body", [None, [], ["rampa_acesso"], "rampa_acesso", 1, True])
@pytest.mark.parametrize("method", ["put", "patch"])
def test_invalid_json_root_returns_a_structured_400_and_preserves_choices(account, method, body):
    user, other, client = account
    assert client.put(URL, {"resources": ["rampa_acesso"]}, format="json").status_code == 200
    response = getattr(client, method)(URL, json.dumps(body), content_type="application/json")
    assert response.status_code == 400
    assert response.data[api_settings.NON_FIELD_ERRORS_KEY]
    assert client.get(URL).data["resources"] == ["rampa_acesso"]
    user.refresh_from_db()
    other.refresh_from_db()
    assert user.accessibility_preferences == ["rampa_acesso"]
    assert other.accessibility_preferences == ["piso_tatil"]


@pytest.mark.parametrize("method", ["get", "put", "patch", "delete"])
def test_unauthenticated_request_cannot_read_or_write(account, method):
    response = getattr(APIClient(), method)(URL, {"resources": []}, format="json")
    assert response.status_code in (401, 403)


def test_unknown_retired_choice_is_reported_until_explicitly_removed(account):
    user, other, client = account
    user.accessibility_preferences = ["retired_resource", "rampa_acesso"]
    user.save(update_fields=["accessibility_preferences"])
    result = client.get(URL).data
    assert result["resources"] == ["retired_resource", "rampa_acesso"]
    assert result["unavailable_resources"] == ["retired_resource"]
    assert client.put(URL, {"resources": result["resources"]}, format="json").status_code == 400
    assert client.put(URL, {"resources": ["rampa_acesso"]}, format="json").status_code == 200


def test_preferences_are_not_in_profile_login_users_or_public_reviews(account):
    user, other, client = account
    client.put(URL, {"resources": ["atendimento_libras", "piso_tatil"]}, format="json")
    for response in [client.get("/api/usuarios/perfil/", {"nome": user.nome}),
                     client.get("/auth/users/"), client.get("/auth/users/me/"),
                     client.get("/api/avaliacoes/modal-avaliacoes/")]:
        assert "accessibility_preferences" not in json.dumps(response.data)
    login = APIClient().post("/api/login/", {"nome": user.nome, "password": "test-password"}, format="json")
    assert login.status_code == 200
    assert "accessibility_preferences" not in json.dumps(login.data)
    response = client.put("/api/usuarios/perfil/?nome=prefs-me", {
        "nome_completo": "Must not persist", "accessibility_preferences": []}, format="json")
    assert response.status_code == 400
    user.refresh_from_db()
    assert user.nome_completo == "" and user.accessibility_preferences == ["atendimento_libras", "piso_tatil"]


def test_swapping_authentication_changes_only_the_private_owner(account):
    user, other, client = account
    client.put(URL, {"resources": ["rampa_acesso"]}, format="json")
    client.force_authenticate(other)
    assert client.get(URL).data["resources"] == ["piso_tatil"]
    client.put(URL, {"resources": ["sinalizacao_visual"]}, format="json")
    client.force_authenticate(user)
    assert client.get(URL).data["resources"] == ["rampa_acesso"]


def test_openapi_describes_filters_catalog_states_and_private_payload():
    schema = SchemaGenerator().get_schema(request=None, public=True)
    assert URL in schema["paths"] and "/api/locais/recursos/" in schema["paths"]
    params = {entry["name"] for entry in schema["paths"]["/api/locais/"]["get"]["parameters"]}
    assert {"recursos", "categorias", "origens", "incluir_desconhecidos"} <= params
    assert "security" in schema["paths"][URL]["put"]
    request_ref = schema["paths"][URL]["put"]["requestBody"]["content"]["application/json"]["schema"]["$ref"]
    body = schema["components"]["schemas"][request_ref.rsplit("/", 1)[1]]
    assert set(body["properties"]) == {"resources"} and body["required"] == ["resources"]
