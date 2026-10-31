"""Discovery contracts and manual journeys; all providers controlled, no public network."""

import uuid
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from unittest.mock import patch

import pytest
from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.db import close_old_connections, connection
from rest_framework.test import APIClient

from favoritos.models import Favorito
from locais.models import Local, ManualPlaceRegistration, RouteHistorySession, VisitaRecente
from locais.services.external_places_service import geocode, ExternalServiceError
from modal_avaliacao.models import ModalAvaliacao
from locais.models import ManualRegistrationGuard

pytestmark = pytest.mark.django_db
URL = "/api/locais/"
MANUAL = URL + "cadastro-manual/"


def owner(name="ana"):
    return get_user_model().objects.create_user(nome=name, email=f"{name}@test.invalid", password="test-password")


def client(user=None):
    api = APIClient()
    if user:
        api.force_authenticate(user)
    return api


def place(name, **kwargs):
    return Local.objects.create(nome=name, endereco="Rua Teste, 10", distancia=999, **kwargs)


def body(**kwargs):
    return {
        "request_id": str(uuid.uuid4()),
        "nome": "Café confirmado",
        "endereco": "Rua Teste, 10",
        "categoria": "cafeteria",
        "latitude": 0,
        "longitude": 0,
        "point_confirmed": True,
        **kwargs,
    }


def test_legacy_and_paged_contract_global_order_and_retry():
    a = place("Zulu", latitude=0, longitude=0.1)
    b = place("Alfa", latitude=0, longitude=0)
    c = place("Alfa", latitude=0, longitude=0.2)
    api = client()
    assert [r["id_local"] for r in api.get(URL).data] == [a.pk, b.pk, c.pk]
    query = {"paginated": "true", "page_size": 1, "ordering": "proximity", "origin_lat": 0, "origin_lon": 0}
    response = api.get(URL, query)
    assert response.data["count"] == 3
    ids = []
    while True:
        ids.extend(r["id_local"] for r in response.data["results"])
        if not response.data["next"]:
            break
        response = api.get(response.data["next"])
    assert ids == [b.pk, a.pk, c.pk]
    assert len(set(ids)) == 3
    assert Local.objects.get(pk=b.pk).distancia == 999


@pytest.mark.parametrize(
    "query",
    [
        {"page": "0"},
        {"page": "-1"},
        {"page_size": "51"},
        {"page_size": "x"},
        {"paginated": "yes"},
        {"ordering": "distancia"},
        {"ordering": "proximity"},
        {"origin_lat": "0"},
        {"origin_lat": "NaN", "origin_lon": "0"},
        {"origin_lat": "91", "origin_lon": "0"},
        {"bbox": "1,2,3"},
        {"bbox": "3,0,1,0"},
        {"bbox": "0,0,90,181"},
        {"owner": "1"},
    ],
)
def test_invalid_discovery_contract(query):
    assert client().get(URL, query).status_code == 400


def test_stable_ties_missing_coordinates_and_dateline():
    missing = place("A sem ponto")
    a = place("Mesmo", latitude=0, longitude=179)
    b = place("Mesmo", latitude=0, longitude=-179)
    response = client().get(URL, {"paginated": "true", "ordering": "proximity", "origin_lat": 0, "origin_lon": 180})
    assert [r["id_local"] for r in response.data["results"]] == [a.pk, b.pk, missing.pk]
    response = client().get(URL, {"paginated": "true", "bbox": "-1,178,1,-178"})
    assert response.data["count"] == 2
    assert client().get(URL + "?paginated=true&page=1&page=2").status_code == 400


def test_resource_filters_before_page_and_remote_search():
    place("Não atende", latitude=0, longitude=0)
    expected = place(
        "Destino distante",
        latitude=1,
        longitude=1,
        accessibility_information={"rampa_acesso": {"state": "presence_reported"}},
    )
    response = client().get(URL, {"paginated": "true", "page_size": 1, "recursos": "rampa_acesso"})
    assert response.data["count"] == 1 and response.data["results"][0]["id_local"] == expected.pk
    assert client().get(URL, {"paginated": "true", "search": "distante"}).data["count"] == 1


def test_manual_auth_retry_changed_body_deleted_receipt_and_no_side_effects():
    user = owner()
    api = client(user)
    payload = body()
    assert client().post(MANUAL, payload, format="json").status_code == 401
    created = api.post(MANUAL, payload, format="json")
    assert created.status_code == 201
    assert created.data["opening_status"] == "unknown"
    repeat = api.post(MANUAL, payload, format="json")
    assert repeat.status_code == 200 and repeat.data["id_local"] == created.data["id_local"]
    assert api.post(MANUAL, {**payload, "nome": "Outro"}, format="json").status_code == 409
    assert Local.objects.count() == ManualPlaceRegistration.objects.count() == 1
    assert not any(m.objects.exists() for m in [Favorito, ModalAvaliacao, VisitaRecente, RouteHistorySession])
    Local.objects.all().delete()
    assert api.post(MANUAL, payload, format="json").status_code == 410


@pytest.mark.parametrize(
    "change",
    [
        {"latitude": True},
        {"longitude": 181},
        {"latitude": "NaN"},
        {"point_confirmed": "true"},
        {"categoria": "city"},
        {"nome": "x" * 256},
        {"endereco": ""},
        {"user": 1},
        {"longitude": None},
    ],
)
def test_manual_invalid_fields(change):
    assert client(owner()).post(MANUAL, body(**change), format="json").status_code == 400
    assert not Local.objects.exists()


def test_duplicates_across_owners_require_review_and_homonyms_are_distinct():
    a, b = owner(), owner("bia")
    payload = body()
    created = client(a).post(MANUAL, payload, format="json")
    duplicate = client(b).post(MANUAL, body(), format="json")
    assert duplicate.status_code == 409
    assert duplicate.data["candidates"][0]["id_local"] == created.data["id_local"]
    assert (
        client(b).post(MANUAL, body(distinct_reason="Outra unidade na mesma galeria."), format="json").status_code
        == 201
    )
    assert client(b).post(MANUAL, body(endereco="Outra rua", longitude=0.01), format="json").status_code == 201


def test_coordinate_validation_preserves_legacy_and_write_permissions():
    old = place("Legado")
    assert client().get(f"{URL}{old.pk}/").status_code == 200
    api = client(owner())
    assert (
        api.post(URL, {"nome": "x", "endereco": "y", "distancia": 0, "latitude": 0}, format="json").status_code == 400
    )
    assert api.patch(f"{URL}{old.pk}/", {"latitude": 0, "longitude": 0}, format="json").status_code == 403
    assert Local.objects.get(pk=old.pk).latitude is None


def test_typed_geocode_poi_independent_of_neighborhood_and_public_cache(settings):
    settings.NOMINATIM_URL = "https://provider.test"
    cache.clear()
    payload = [
        {
            "display_name": "Lisboa, Portugal",
            "lat": "38.7",
            "lon": "-9.1",
            "class": "place",
            "type": "city",
            "osm_type": "relation",
            "osm_id": 1,
            "boundingbox": ["38", "39", "-10", "-9"],
        },
        {
            "display_name": "Café, Lisboa",
            "name": "Café",
            "lat": "38.7",
            "lon": "-9.1",
            "class": "amenity",
            "type": "cafe",
            "osm_type": "node",
            "osm_id": 2,
        },
    ]
    with patch("locais.services.external_places_service.request_json", return_value=payload) as request:
        rows = geocode({"q": "Lisboa"})
        assert rows[0]["kind"] == "region" and rows[0]["bounding_box"] == [38, -10, 39, -9]
        assert rows[1]["kind"] == "place" and rows[1]["place"]["registration_token"]
        assert geocode({"q": "Lisboa"})[1]["place"]["external_id"] == "osm:node:2"
        assert request.call_count == 1
    assert not Local.objects.exists()


def test_public_nominatim_requires_opt_in_and_shared_cache(settings):
    settings.NOMINATIM_URL = "https://nominatim.openstreetmap.org"
    settings.NOMINATIM_PUBLIC_OPT_IN = False
    with pytest.raises(ExternalServiceError):
        geocode({"q": "Café"})
    settings.NOMINATIM_PUBLIC_OPT_IN = True
    with pytest.raises(ExternalServiceError):
        geocode({"q": "Café"})


@pytest.mark.django_db(transaction=True)
def test_postgresql_concurrent_manual_registration():
    if connection.vendor != "postgresql":
        pytest.skip("Requires actual independent PostgreSQL connections")

    ManualRegistrationGuard.objects.get_or_create(pk=1)

    user = owner()
    barrier = Barrier(2)

    def create(_):
        close_old_connections()
        try:
            api = client(get_user_model().objects.get(pk=user.pk))
            barrier.wait(timeout=10)
            return api.post(MANUAL, body(), format="json").status_code
        finally:
            close_old_connections()

    with ThreadPoolExecutor(max_workers=2) as pool:
        statuses = list(pool.map(create, range(2)))
    assert sorted(statuses) == [201, 409]
    assert Local.objects.count() == 1


def test_rating_order_uses_only_visible_valid_reviews():
    visible, hidden = owner(), owner("hidden")
    hidden.mostrar_avaliacoes = False
    hidden.save(update_fields=["mostrar_avaliacoes"])
    first, second = place("Primeiro"), place("Segundo")
    ModalAvaliacao.objects.create(user=visible, local=first, estrelas=4)
    ModalAvaliacao.objects.create(user=hidden, local=second, estrelas=5)
    rows = client().get(URL, {"paginated": "true", "ordering": "rating"}).data["results"]
    assert [r["id_local"] for r in rows] == [first.pk, second.pk]
    assert rows[1]["quantidade_avaliacoes"] == 0


def test_access_logs_redact_origin_without_changing_query():
    import logging
    from acessoja.logging_filters import RedactCoordinates

    record = logging.LogRecord(
        "django.server", 20, "", 0, "GET %s", ("/api/locais/?origin_lat=12.3&origin_lon=-40.2&search=Cafe",), None
    )
    assert RedactCoordinates().filter(record)
    assert "12.3" not in record.getMessage() and "-40.2" not in record.getMessage()
    assert "search=Cafe" in record.getMessage()


@pytest.mark.django_db(transaction=True)
def test_manual_migration_preserves_existing_domains():
    from django.db.migrations.executor import MigrationExecutor
    from contribuicoes.models import ContributionPointEvent, PointActivity, UserAchievement
    from locais.models import ManualRegistrationGuard

    user = owner()
    local = place("Preservado", latitude=0, longitude=0)
    ModalAvaliacao.objects.create(user=user, local=local, estrelas=4)
    Favorito.objects.create(user=user, local=local)
    VisitaRecente.objects.create(user=user, local=local)
    RouteHistorySession.objects.create(
        user=user,
        session_id=uuid.uuid4(),
        destination_name="Preservado",
        destination_source="acessoja",
        local=local,
        latitude=0,
        longitude=0,
    )
    models = [
        Local,
        ModalAvaliacao,
        Favorito,
        VisitaRecente,
        RouteHistorySession,
        ContributionPointEvent,
        PointActivity,
        UserAchievement,
    ]
    before = [list(m.objects.order_by("pk").values()) for m in models]
    executor = MigrationExecutor(connection)
    latest = executor.loader.graph.leaf_nodes()
    try:
        executor.migrate([("locais", "0009_routehistorysession")])
    finally:
        MigrationExecutor(connection).migrate(latest)
    assert before == [list(m.objects.order_by("pk").values()) for m in models]
    assert ManualRegistrationGuard.objects.filter(pk=1).exists()
