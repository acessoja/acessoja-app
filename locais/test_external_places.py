"""Sprint 2: contratos reais da API, sem rede ou serviços OSM nos testes."""

import base64
import json
from unittest.mock import MagicMock, patch

import pytest
import requests
from django.contrib.auth import get_user_model
from django.core import signing
from django.core.cache import cache
from rest_framework.test import APIClient

from locais.models import Local
from locais.services.categories import CATEGORIES, category_for
from locais.services.external_places_service import (
    ExternalPlacesService,
    ExternalServiceError,
    TOKEN_SALT,
    geocode,
    normalize_element,
    request_json,
)
from locais.services.matching import find_internal

QUERY = {"latitude": -16.3267, "longitude": -48.9528, "raio": 1500, "limite": 50}


def element(kind="node", number=1, **extra):
    coords = {"lat": QUERY["latitude"], "lon": QUERY["longitude"]}
    return {
        "type": kind,
        "id": number,
        "tags": {
            "name": "Café Teste",
            "amenity": "cafe",
            "addr:full": "Rua Teste, 10",
        },
        **(coords if kind == "node" else {"center": coords}),
        **extra,
    }


def response(payload, status=200):
    result = MagicMock()
    result.status_code = status
    result.__enter__.return_value = result
    result.iter_content.return_value = [json.dumps(payload).encode()]
    return result


@pytest.fixture(autouse=True)
def clear_cache():
    cache.clear()
    yield
    cache.clear()


@pytest.fixture
def client():
    return APIClient()


@pytest.fixture
def osm_place():
    return normalize_element(element())


@pytest.fixture
def user(db):
    return get_user_model().objects.create_user(
        nome="contributor", email="contributor@example.test", password="Senha123!"
    )


@pytest.fixture
def auth_client(client, user):
    encoded = base64.b64encode(b"contributor:Senha123!").decode()
    client.credentials(HTTP_AUTHORIZATION=f"Basic {encoded}")
    return client


@pytest.fixture
def payload(osm_place):
    return {
        "registration_token": signing.dumps(osm_place, salt=TOKEN_SALT),
        "nome": osm_place["nome"],
        "endereco": osm_place["endereco"],
    }


@pytest.mark.parametrize(
    "params",
    [
        {},
        {"latitude": 91},
        {"longitude": -181},
        {"latitude": "nan"},
        {"longitude": "inf"},
        {"raio": 99},
        {"raio": 3001},
        {"raio": "1;out;"},
        {"limite": 0},
        {"limite": 101},
        {"categoria": "restaurant];out;"},
        {"latitude": ""},
        {"longitude": "abc"},
    ],
)
@pytest.mark.django_db
def test_invalid_parameters_never_call_overpass(client, params):
    data = {} if not params else {**QUERY, **params}
    with patch("locais.services.external_places_service.requests.post") as post:
        result = client.get("/api/locais/externos/", data)
    assert result.status_code == 400
    post.assert_not_called()


@pytest.mark.parametrize("kind", ["node", "way", "relation"])
def test_normalizes_osm_types_and_keeps_unknown_data(kind):
    place = normalize_element(element(kind))
    assert place["external_id"] == f"osm:{kind}:1"
    assert place["latitude"] == QUERY["latitude"]
    assert place["media_estrelas"] is None
    assert place["has_community_reviews"] is False
    assert place["accessibility_data"] == {}
    assert "aberto" not in place


@pytest.mark.parametrize(
    "bad",
    [
        None,
        [],
        {},
        element("unknown"),
        element(number=-1),
        element(number=True),
        element(tags={}),
        element(tags={"name": 45}),
        element(lat="invalid"),
        element(lon=181),
        element(lat=float("inf")),
        element("way", center=None),
        element(tags=["name"]),
        element(number="1"),
    ],
)
def test_malformed_elements_are_discarded(bad):
    assert normalize_element(bad) is None


def test_optional_data_is_not_invented():
    place = normalize_element(element(tags={"name": "Farmácia", "amenity": "pharmacy"}))
    assert place["endereco"] == ""
    assert place["categoria"] == "farmacia"
    assert place["additional_data"] == {}


def test_osm_accessibility_is_metadata_only():
    place = normalize_element(element(tags={"name": "Café", "amenity": "cafe", "wheelchair": "no"}))
    assert place["accessibility_data"]["wheelchair"] == "no"
    assert "rampa_acesso" not in place


@pytest.mark.parametrize(
    "tags,expected",
    [
        ({"amenity": "restaurant"}, "restaurante"),
        ({"amenity": "cafe"}, "cafeteria"),
        ({"shop": "supermarket"}, "supermercado"),
        ({"amenity": "pharmacy"}, "farmacia"),
        ({"amenity": "clinic"}, "saude"),
        ({"amenity": "school"}, "educacao"),
        ({"shop": "mall"}, "loja"),
        ({"leisure": "park"}, "parque"),
        ({"amenity": "bank"}, "banco"),
        ({"office": "government"}, "publico"),
        ({}, "outros"),
    ],
)
def test_central_categories(tags, expected):
    assert category_for(tags) == expected


@pytest.mark.django_db
def test_api_returns_results_tokens_attribution_without_writes(client):
    with patch(
        "locais.services.external_places_service.requests.post", return_value=response({"elements": [element()]})
    ):
        result = client.get("/api/locais/externos/", QUERY)
    assert result.status_code == 200
    place = result.data["results"][0]
    assert signing.loads(place["registration_token"], salt=TOKEN_SALT)["external_id"] == "osm:node:1"
    assert result.data["attribution"].startswith("© OpenStreetMap")
    assert Local.objects.count() == 0


def test_cache_avoids_repeated_calls_and_preserves_empty_result(settings):
    settings.EXTERNAL_PLACES_CACHE_SECONDS = 300
    with patch(
        "locais.services.external_places_service.requests.post", return_value=response({"elements": []})
    ) as post:
        service = ExternalPlacesService()
        assert service.search(**QUERY)["results"] == []
        assert service.search(**QUERY)["results"] == []
        assert post.call_count == 1


def test_cache_expires_with_configured_ttl(settings):
    settings.EXTERNAL_PLACES_CACHE_SECONDS = 0
    with patch(
        "locais.services.external_places_service.requests.post", return_value=response({"elements": []})
    ) as post:
        ExternalPlacesService().search(**QUERY)
        cache.delete("geo:gate:overpass")
        ExternalPlacesService().search(**QUERY)
        assert post.call_count == 2


def test_limits_results_deduplicates_object_ids_and_filters_radius():
    elements = [element(number=1), element(number=1), element("way", number=2), element(number=3, lat=0)]
    with patch(
        "locais.services.external_places_service.requests.post", return_value=response({"elements": elements})
    ) as post:
        result = ExternalPlacesService().search(**{**QUERY, "limite": 1})
        query = post.call_args.kwargs["data"]["data"]
    assert len(result["results"]) == 1
    assert result["truncated"] is True
    assert "[timeout:10]" in query and "out center 500" in query
    assert "(around:1500,-16.326700,-48.952800)" in query


def test_category_query_uses_fixed_ql_and_filtered_response():
    with patch(
        "locais.services.external_places_service.requests.post", return_value=response({"elements": [element()]})
    ) as post:
        result = ExternalPlacesService().search(**QUERY, categoria="banco")
    assert "nwr[amenity=bank]" in post.call_args.kwargs["data"]["data"]
    assert "shop" not in post.call_args.kwargs["data"]["data"]
    assert result["results"] == []


@pytest.mark.parametrize("status,expected", [(429, 429), (500, 503), (503, 503), (302, 503)])
@pytest.mark.django_db
def test_upstream_errors_become_explicit_api_errors(client, status, expected):
    with patch("locais.services.external_places_service.requests.post", return_value=response({}, status)):
        result = client.get("/api/locais/externos/", QUERY)
    assert result.status_code == expected
    assert result["Retry-After"]


@pytest.mark.parametrize("exception,status", [(requests.Timeout(), 504), (requests.ConnectionError(), 503)])
@pytest.mark.django_db
def test_connection_and_timeout(client, exception, status):
    with patch("locais.services.external_places_service.requests.post", side_effect=exception):
        assert client.get("/api/locais/externos/", QUERY).status_code == status


@pytest.mark.parametrize("bad", [None, [], {"elements": {}}, {"elements": [], "remark": "runtime timeout"}])
@pytest.mark.django_db
def test_bad_provider_payload_is_not_cached_as_success(client, bad):
    with patch("locais.services.external_places_service.requests.post", return_value=response(bad)):
        assert client.get("/api/locais/externos/", QUERY).status_code == 502


def test_invalid_json_and_oversized_payload():
    result = response({})
    result.iter_content.return_value = [b"not JSON"]
    with patch("locais.services.external_places_service.requests.post", return_value=result):
        with pytest.raises(ExternalServiceError, match="inválida"):
            request_json("overpass", "https://example.test", data={"data": "query"})
    cache.clear()
    result.iter_content.return_value = [b"x" * (2 * 1024 * 1024 + 1)]
    with patch("locais.services.external_places_service.requests.post", return_value=result):
        with pytest.raises(ExternalServiceError, match="limite seguro"):
            request_json("overpass", "https://example.test", data={"data": "query"})


def test_single_inflight_slot_and_cooldown():
    cache.set("geo:gate:overpass", True, 25)
    with patch("locais.services.external_places_service.requests.post") as post:
        with pytest.raises(ExternalServiceError) as exc:
            ExternalPlacesService().search(**QUERY)
    assert exc.value.status == 429
    post.assert_not_called()


@pytest.mark.parametrize(
    "invalid",
    [{"raio": 3001}, {"limite": 101}, {"categoria": "injection"}, {"latitude": float("nan")}, {"longitude": 181}],
)
def test_service_validates_non_http_callers(invalid):
    with pytest.raises(ValueError):
        ExternalPlacesService().search(**{**QUERY, **invalid})


@pytest.mark.django_db
def test_explicit_match_precedes_geographic_candidates(osm_place):
    linked = Local.objects.create(
        nome="Nome distinto",
        endereco="Outro endereço",
        distancia=7,
        latitude=0,
        longitude=0,
        osm_id=osm_place["external_id"],
    )
    Local.objects.create(
        nome=osm_place["nome"],
        endereco=osm_place["endereco"],
        distancia=1,
        latitude=osm_place["latitude"],
        longitude=osm_place["longitude"],
    )
    assert find_internal(osm_place, Local.objects.all()) == linked


@pytest.mark.django_db
def test_conservative_matching_requires_address_name_and_proximity(osm_place):
    args = dict(
        nome=osm_place["nome"],
        endereco=osm_place["endereco"],
        distancia=1,
        latitude=osm_place["latitude"],
        longitude=osm_place["longitude"],
    )
    local = Local.objects.create(**args)
    assert find_internal(osm_place) == local
    for changed in [
        dict(nome="Outro café"),
        dict(endereco="Rua distinta"),
        dict(latitude=0),
        dict(categoria="banco"),
        dict(latitude=None),
    ]:
        for key, value in changed.items():
            setattr(local, key, value)
        local.save()
        assert find_internal(osm_place) is None
        for key, value in {**args, "categoria": ""}.items():
            setattr(local, key, value)
        local.save()


@pytest.mark.django_db
def test_ambiguous_same_address_is_kept_separate(osm_place):
    for _ in range(2):
        Local.objects.create(
            nome=osm_place["nome"],
            endereco=osm_place["endereco"],
            distancia=1,
            latitude=osm_place["latitude"],
            longitude=osm_place["longitude"],
        )
    assert find_internal(osm_place) is None


@pytest.mark.django_db
def test_import_requires_real_authentication(client, payload):
    assert client.post("/api/locais/externos/cadastrar/", payload, format="json").status_code == 401
    client.credentials(HTTP_AUTHORIZATION="Basic " + base64.b64encode(b"contributor:wrong").decode())
    assert client.post("/api/locais/externos/cadastrar/", payload, format="json").status_code == 401
    assert Local.objects.count() == 0


@pytest.mark.django_db
def test_authenticated_import_is_idempotent_and_does_not_invent_accessibility(auth_client, payload):
    created = auth_client.post("/api/locais/externos/cadastrar/", payload, format="json")
    assert created.status_code == 201
    assert created.data["osm_id"] == "osm:node:1"
    assert created.data["rampa_acesso"] is False
    assert created.data["quantidade_avaliacoes"] == 0
    assert auth_client.post("/api/locais/externos/cadastrar/", payload, format="json").status_code == 200
    assert Local.objects.count() == 1


@pytest.mark.django_db
def test_existing_local_keeps_its_reviews_distance_and_flags(auth_client, payload, osm_place):
    local = Local.objects.create(
        nome=osm_place["nome"],
        endereco=osm_place["endereco"],
        distancia=7,
        latitude=osm_place["latitude"],
        longitude=osm_place["longitude"],
        rampa_acesso=True,
    )
    result = auth_client.post("/api/locais/externos/cadastrar/", payload, format="json")
    assert result.status_code == 200
    assert result.data["id_local"] == local.pk
    local.refresh_from_db()
    assert local.distancia == 7 and local.rampa_acesso is True
    assert local.osm_id == osm_place["external_id"]


@pytest.mark.django_db
def test_import_rejects_tampered_and_expired_tokens(auth_client, payload):
    payload["registration_token"] += "tampered"
    assert auth_client.post("/api/locais/externos/cadastrar/", payload, format="json").status_code == 400
    with patch("locais.external_views.signing.loads", side_effect=signing.SignatureExpired("expired")):
        assert auth_client.post("/api/locais/externos/cadastrar/", payload, format="json").status_code == 400
    assert Local.objects.count() == 0


@pytest.mark.django_db
def test_import_ignores_client_coordinates_and_flags(auth_client, payload, osm_place):
    result = auth_client.post(
        "/api/locais/externos/cadastrar/", {**payload, "latitude": 0, "rampa_acesso": True}, format="json"
    )
    assert result.status_code == 201
    assert result.data["latitude"] == osm_place["latitude"]
    assert result.data["rampa_acesso"] is False


@pytest.mark.parametrize("data", [{}, {"nome": ""}, {"endereco": ""}, {"nome": "x" * 256}])
@pytest.mark.django_db
def test_import_validates_confirmed_fields(auth_client, payload, data):
    body = {} if not data else {**payload, **data}
    assert auth_client.post("/api/locais/externos/cadastrar/", body, format="json").status_code == 400


@pytest.mark.django_db
def test_authenticated_endpoint_cannot_set_osm_link(auth_client):
    result = auth_client.post(
        "/api/locais/", {"nome": "Legacy", "endereco": "Rua", "distancia": 4, "osm_id": "osm:node:99"}, format="json"
    )
    assert result.status_code == 201
    assert result.data["osm_id"] is None


@pytest.mark.django_db
def test_api_annotates_matching_without_discarding(client, osm_place):
    local = Local.objects.create(nome="Renomeado", endereco="Rua", distancia=1, osm_id=osm_place["external_id"])
    with patch(
        "locais.services.external_places_service.requests.post", return_value=response({"elements": [element()]})
    ):
        result = client.get("/api/locais/externos/", QUERY)
    assert result.data["results"][0]["internal_id"] == local.pk


@pytest.mark.django_db
def test_category_endpoint_matches_central_catalog(client):
    result = client.get("/api/locais/externos/categorias/")
    assert result.status_code == 200
    assert {row["id"] for row in result.data} == set(CATEGORIES)


@pytest.mark.parametrize(
    "params",
    [
        {},
        {"q": "x", "latitude": 1},
        {"latitude": 1},
        {"q": "x", "latitude": 1, "longitude": 2},
        {"latitude": "nan", "longitude": 1},
    ],
)
@pytest.mark.django_db
def test_geocode_validates_exclusive_parameters(client, params):
    assert client.get("/api/locais/geocodificar/", params).status_code == 400


@pytest.mark.django_db
def test_unconfigured_geocoder_has_useful_error(client, settings):
    settings.NOMINATIM_URL = ""
    result = client.get("/api/locais/geocodificar/", {"q": "Anápolis"})
    assert result.status_code == 503
    assert "Selecione um local" in result.data["detail"]


def test_configured_geocoder_is_cached_and_identifies_app(settings):
    settings.NOMINATIM_URL = "https://geocoder.example.test"
    with patch(
        "locais.services.external_places_service.requests.get",
        return_value=response(
            [
                {"lat": "-16.3267", "lon": "-48.9528", "display_name": "Anápolis"},
            ]
        ),
    ) as get:
        assert geocode({"q": "Anápolis"})[0]["nome"] == "Anápolis"
        assert geocode({"q": "Anápolis"})[0]["longitude"] == -48.9528
        assert get.call_count == 1
        assert get.call_args.kwargs["headers"]["User-Agent"].startswith("AcessoJa/")
        assert get.call_args.kwargs["allow_redirects"] is False


def test_reverse_geocode_and_invalid_coordinates(settings):
    settings.NOMINATIM_URL = "https://geocoder.example.test"
    with patch(
        "locais.services.external_places_service.requests.get",
        return_value=response(
            {
                "lat": "0",
                "lon": "0",
                "display_name": "Origem",
            }
        ),
    ) as get:
        assert geocode({"latitude": 0, "longitude": 0})[0]["latitude"] == 0
        assert get.call_args.kwargs["params"]["lat"] == 0
    cache.clear()
    with patch(
        "locais.services.external_places_service.requests.get",
        return_value=response(
            [
                {"lat": "nan", "lon": "0", "display_name": "Invalid"},
            ]
        ),
    ):
        with pytest.raises(ExternalServiceError):
            geocode({"q": "invalid"})


@pytest.mark.parametrize("payload", [45, {}, [{"lat": "invalid", "lon": 0, "display_name": "Invalid"}]])
def test_malformed_geocoder(settings, payload):
    settings.NOMINATIM_URL = "https://geocoder.example.test"
    with patch("locais.services.external_places_service.requests.get", return_value=response(payload)):
        with pytest.raises(ExternalServiceError):
            geocode({"q": "invalid"})


@pytest.mark.django_db
def test_corrected_address_still_checks_existing_record(auth_client, payload, osm_place):
    local = Local.objects.create(
        nome=osm_place["nome"],
        endereco="Rua Corrigida, 10",
        distancia=5,
        latitude=osm_place["latitude"],
        longitude=osm_place["longitude"],
    )
    result = auth_client.post(
        "/api/locais/externos/cadastrar/", {**payload, "endereco": "Rua Corrigida, 10"}, format="json"
    )
    assert result.status_code == 200
    assert result.data["id_local"] == local.pk


@pytest.mark.django_db
def test_concurrent_unique_constraint_recovers_existing_record(auth_client, payload, osm_place):
    from django.db import IntegrityError

    local = Local.objects.create(
        nome="Vínculo concorrente", endereco="Rua", distancia=0, osm_id=osm_place["external_id"]
    )
    with patch("locais.external_views.find_internal", return_value=None):
        with patch("locais.external_views.Local.objects.create", side_effect=IntegrityError("unique")):
            result = auth_client.post("/api/locais/externos/cadastrar/", payload, format="json")
    assert result.status_code == 200
    assert result.data["id_local"] == local.pk


@pytest.mark.django_db
def test_row_link_race_does_not_overwrite_other_osm_id(auth_client, payload, osm_place):
    local = Local.objects.create(
        nome=osm_place["nome"], endereco=osm_place["endereco"], distancia=0, osm_id="osm:way:99"
    )
    with patch("locais.external_views.find_internal", return_value=local):
        result = auth_client.post("/api/locais/externos/cadastrar/", payload, format="json")
    assert result.status_code == 409
    local.refresh_from_db()
    assert local.osm_id == "osm:way:99"


def test_whole_transfer_has_deadline():
    result = response({"elements": []})
    with patch("locais.services.external_places_service.time.monotonic", side_effect=[0, 20]):
        with patch("locais.services.external_places_service.requests.post", return_value=result):
            with pytest.raises(ExternalServiceError) as exc:
                request_json("overpass", "https://example.test", data={"data": "query"})
    assert exc.value.status == 504


@pytest.mark.django_db
def test_anonymous_endpoint_has_ip_throttle(client):
    with patch("locais.services.external_places_service.requests.post", return_value=response({"elements": []})):
        for _ in range(20):
            assert client.get("/api/locais/externos/", QUERY).status_code == 200
        assert client.get("/api/locais/externos/", QUERY).status_code == 429


@pytest.mark.django_db(transaction=True)
def test_migration_preserves_previous_records_and_evaluations():
    from django.db import connection
    from django.db.migrations.executor import MigrationExecutor

    executor = MigrationExecutor(connection)
    before = ("locais", "0005_alter_local_imagem")
    after = ("locais", "0006_local_categoria_local_osm_id")
    targets = [
        before,
        ("modal_avaliacao", "0003_alter_modalavaliacao_comentario"),
        ("usuarios", "0002_usuario_compartilhar_localizacao_usuario_foto_perfil_and_more"),
    ]
    executor.migrate(targets)
    old_apps = executor.loader.project_state(targets).apps
    old = old_apps.get_model("locais", "Local").objects.create(
        nome="Antes da Sprint 2", endereco="Rua antiga", distancia=4.2, rampa_acesso=True
    )
    ModalAvaliacao = old_apps.get_model("modal_avaliacao", "ModalAvaliacao")
    VisitaRecente = old_apps.get_model("locais", "VisitaRecente")
    HistoricalUser = old_apps.get_model("usuarios", "Usuario")
    user = HistoricalUser.objects.create(
        nome="migration",
        email="migration@example.test",
        password="unused",
        data_criacao=__import__("django.utils.timezone", fromlist=["now"]).now(),
    )
    review = ModalAvaliacao.objects.create(
        local_id=old.pk,
        user=user,
        estrelas=5,
        pergunta_1="Sim",
        pergunta_2="Não",
        pergunta_3="Não sei",
        pergunta_4="Sim",
    )
    visit = VisitaRecente.objects.create(local_id=old.pk, user=user)
    try:
        executor = MigrationExecutor(connection)
        targets[0] = after
        executor.migrate(targets)
        apps = executor.loader.project_state(targets).apps
        saved = apps.get_model("locais", "Local").objects.get(pk=old.pk)
        assert saved.nome == "Antes da Sprint 2"
        assert saved.distancia == 4.2 and saved.rampa_acesso
        assert saved.osm_id is None and saved.categoria == ""
        assert ModalAvaliacao.objects.get(pk=review.pk).estrelas == 5
        assert VisitaRecente.objects.get(pk=visit.pk).local_id == old.pk
    finally:
        executor = MigrationExecutor(connection)
        executor.migrate(executor.loader.graph.leaf_nodes())
