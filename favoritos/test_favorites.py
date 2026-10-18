"""Private favorites: contract, isolation, bounded queries and actual PostgreSQL races."""
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from threading import Barrier

import pytest
from django.contrib.auth import get_user_model
from django.db import IntegrityError, close_old_connections, connection, transaction
from django.test.utils import CaptureQueriesContext
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient

from contribuicoes.models import ContributionPointEvent
from locais.models import Local, RouteHistorySession, VisitaRecente
from modal_avaliacao.models import ModalAvaliacao
from .models import Favorito

pytestmark = pytest.mark.django_db
URL = "/api/favoritos/"


def user(name="ana", **kwargs):
    return get_user_model().objects.create_user(
        nome=name, email=f"{name}@test.invalid", password="test-password", **kwargs
    )


def place(name="Café da praça", **kwargs):
    return Local.objects.create(nome=name, endereco="Rua São José, 10", distancia=0, **kwargs)


def client(owner):
    api = APIClient()
    api.credentials(HTTP_AUTHORIZATION=f"Token {Token.objects.get_or_create(user=owner)[0].key}")
    return api


@pytest.fixture
def setup():
    a, b, local = user(), user("bruno"), place()
    return a, b, local, client(a), client(b)


@pytest.mark.parametrize("auth", [None, "Token invalid"])
def test_requires_authentication(auth):
    api = APIClient()
    if auth:
        api.credentials(HTTP_AUTHORIZATION=auth)
    for path in (URL, URL + "estado/?locais=1"):
        assert api.get(path).status_code == 401
    assert api.post(URL, {"local": 1}).status_code == 401
    assert api.delete(URL + "1/").status_code == 401


def test_expired_token(setup, settings):
    a, _, local, api, _ = setup
    settings.AUTH_TOKEN_TTL = 10
    Token.objects.filter(user=a).update(created=timezone.now() - timedelta(seconds=11))
    assert api.post(URL, {"local": local.pk}).status_code == 401
    assert not Favorito.objects.exists()


def test_idempotence_isolation_and_no_side_effects(setup):
    a, b, local, api, other = setup
    review = ModalAvaliacao.objects.create(user=a, local=local, estrelas=4)
    before = (ContributionPointEvent.objects.filter(user=a).count(), VisitaRecente.objects.count(),
              RouteHistorySession.objects.count())
    created = api.post(URL, {"local": local.pk}, format="json")
    assert created.status_code == 201
    fid = created.data["id"]
    assert api.post(URL, {"local": local.pk}, format="json").data["id"] == fid
    assert api.post(URL, {"local": local.pk}, format="json").status_code == 200
    assert other.get(URL).data["total"] == 0
    assert other.get(f"{URL}{fid}/").status_code == 404
    assert other.delete(f"{URL}{fid}/").status_code == 204
    assert Favorito.objects.filter(pk=fid).exists()
    assert api.delete(f"{URL}{fid}/").status_code == 204
    assert api.delete(f"{URL}{fid}/").status_code == 204
    restored = api.post(URL, {"local": local.pk}, format="json")
    assert restored.data["id"] != fid
    assert Local.objects.filter(pk=local.pk).exists()
    assert ModalAvaliacao.objects.get(pk=review.pk).estrelas == 4
    assert before == (ContributionPointEvent.objects.filter(user=a).count(), VisitaRecente.objects.count(),
                      RouteHistorySession.objects.count())
    assert "no-store" in created["Cache-Control"]
    assert "Authorization" in created["Vary"]


@pytest.mark.parametrize("body", [
    None, [], {}, {"local": True}, {"local": -1}, {"local": 0},
    {"local": 1.5}, {"local": "bad"}, {"local": 999999}, {"local": 1, "user": 2},
    {"local": 1, "id": 3}, {"local": 1, "criado_em": "2020-01-01"},
])
def test_invalid_body(setup, body):
    *_, api, _ = setup
    assert api.post(URL, body, format="json").status_code == 400
    assert not Favorito.objects.exists()


@pytest.mark.parametrize("method,path,body", [
    ("get", "?user=2", None), ("get", "?owner=2", None),
    ("post", "?user=2", {"local": 1}), ("delete", "1/?user=2", None),
    ("delete", "1/", {"user": 2}), ("get", "estado/?locais=1&user=2", None),
    ("get", "?page_size=0", None), ("get", "?page_size=nan", None),
    ("get", "?q=" + "a" * 181, None),
])
def test_rejects_owner_and_bad_queries(setup, method, path, body):
    *_, api, _ = setup
    response = getattr(api, method)(URL + path, body, format="json")
    assert response.status_code == 400


def test_public_stats_and_own_review_are_separate(setup):
    a, b, local, api, other = setup
    private = user("private", mostrar_avaliacoes=False)
    hidden = user("invalid")
    a.mostrar_avaliacoes = False
    a.save()
    own = ModalAvaliacao.objects.create(user=a, local=local, estrelas=1)
    ModalAvaliacao.objects.create(user=b, local=local, estrelas=4)
    ModalAvaliacao.objects.create(user=private, local=local, estrelas=2)
    ModalAvaliacao.objects.create(user=hidden, local=local, estrelas=5, is_valid=False)
    ModalAvaliacao.objects.create(user=hidden, local=local, estrelas=1, is_current=False)
    data = api.post(URL, {"local": local.pk}, format="json").data["local_detalhes"]
    assert data["public_rating"] == {"average": 4.0, "count": 1}
    assert data["media_estrelas"] == 4.0 and data["quantidade_avaliacoes"] == 1
    assert data["own_review"]["id"] == own.pk and data["own_review"]["can_edit"]
    assert data["own_review"]["estrelas"] == 1
    a.mostrar_avaliacoes = True
    a.save()
    assert api.get(URL).data["results"][0]["local_detalhes"]["public_rating"] == {"average": 2.5, "count": 2}
    own.is_valid = False
    own.save()
    data = api.get(URL).data["results"][0]["local_detalhes"]
    assert data["own_review"]["is_valid"] is False
    assert data["public_rating"]["count"] == 1


def test_empty_optional_fields_and_no_invented_hours_or_distance(setup):
    _, _, local, api, _ = setup
    detail = api.post(URL, {"local": local.pk}, format="json").data["local_detalhes"]
    assert detail["public_rating"] == {"average": None, "count": 0}
    assert detail["own_review"] is None
    assert detail["latitude"] is None and detail["categoria"] == ""
    assert "distancia" not in detail and "aberto" not in detail
    assert detail["opening_status"] == "unknown"


def test_pagination_search_and_stable_order(setup):
    a, b, _, api, other = setup
    for i in range(24):
        Favorito.objects.create(user=a, local=place(f"Café {i:02}"))
    outsider = place("Segredo")
    Favorito.objects.create(user=b, local=outsider)
    Favorito.objects.update(criado_em=timezone.now())
    first = api.get(URL).data
    assert first["count"] == first["total"] == 24 and len(first["results"]) == 20
    second = api.get(first["next"]).data
    assert len(second["results"]) == 4
    ids = [row["id"] for row in first["results"] + second["results"]]
    assert ids == sorted(ids, reverse=True)
    found = api.get(URL, {"q": "  CAFE    23  "}).data
    assert found["count"] == 1 and found["total"] == 24
    assert api.get(URL, {"q": "segredo"}).data["count"] == 0
    assert api.get(URL, {"q": "   "}).data["count"] == 24
    assert len(api.get(URL, {"page_size": 999}).data["results"]) == 24
    assert api.get(URL + "?page=200").status_code == 404


def test_state_batch_does_not_confuse_unloaded_pages_or_another_owner(setup):
    a, b, local, api, _ = setup
    other_local = place("other")
    own = Favorito.objects.create(user=a, local=local)
    Favorito.objects.create(user=b, local=other_local)
    data = api.get(URL + f"estado/?locais={local.pk},{other_local.pk},999999,{local.pk}").data["results"]
    assert data == [{"local": local.pk, "id": own.pk, "exists": True},
                    {"local": other_local.pk, "id": None, "exists": True},
                    {"local": 999999, "id": None, "exists": False}]
    assert Favorito.objects.count() == 2


@pytest.mark.parametrize("ids", ["", "0", "-1", "nan", "1.5", "1,,2", "1," * 100 + "2"])
def test_invalid_batch(setup, ids):
    *_, api, _ = setup
    assert api.get(URL + "estado/", {"locais": ids}).status_code == 400


def test_bounded_query_count(setup):
    a, _, local, api, _ = setup
    Favorito.objects.create(user=a, local=local)
    with CaptureQueriesContext(connection) as single:
        assert api.get(URL).status_code == 200
    for i in range(18):
        Favorito.objects.create(user=a, local=place(f"Library {i}"))
    with CaptureQueriesContext(connection) as many:
        data = api.get(URL).data
    assert len(data["results"]) == 19
    assert len(many) <= len(single) + 1
    assert len(many) < 12


def test_database_uniqueness_and_cascade(setup):
    a, b, local, api, _ = setup
    Favorito.objects.create(user=a, local=local)
    with pytest.raises(IntegrityError), transaction.atomic():
        Favorito.objects.create(user=a, local=local)
    Favorito.objects.create(user=b, local=local)
    a.delete()
    assert Favorito.objects.count() == 1
    assert Local.objects.filter(pk=local.pk).exists()
    local.delete()
    assert not Favorito.objects.exists()


@pytest.mark.django_db(transaction=True)
def test_postgresql_concurrent_favorite_create_is_idempotent():
    if connection.vendor != "postgresql":
        pytest.skip("Concurrency requires PostgreSQL row locks, not SQLite")
    owner, local = user(), place()
    token = Token.objects.create(user=owner).key
    barrier = Barrier(2)

    def create():
        close_old_connections()
        try:
            api = APIClient()
            api.credentials(HTTP_AUTHORIZATION=f"Token {token}")
            barrier.wait(timeout=10)
            result = api.post(URL, {"local": local.pk}, format="json")
            return result.status_code, result.data["id"]
        finally:
            close_old_connections()

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda _: create(), range(2)))
    assert sorted(status for status, _ in results) == [200, 201]
    assert len({fid for _, fid in results}) == 1
    assert Favorito.objects.count() == 1


@pytest.mark.django_db(transaction=True)
def test_additive_migration_preserves_existing_domain_data():
    from uuid import uuid4
    from django.db.migrations.executor import MigrationExecutor
    from contribuicoes.models import PointActivity

    executor = MigrationExecutor(connection)
    latest = executor.loader.graph.leaf_nodes()
    executor.migrate([(app, migration) for app, migration in latest if app != "favoritos"] + [("favoritos", None)])
    try:
        owner, local = user("migration"), place()
        review = ModalAvaliacao.objects.create(user=owner, local=local, estrelas=5, verified_author=True)
        visit = VisitaRecente.objects.create(user=owner, local=local)
        route = RouteHistorySession.objects.create(user=owner, local=local, session_id=uuid4(), status="cancelled")
        before = list(ContributionPointEvent.objects.values())
        activity = list(PointActivity.objects.values())
        MigrationExecutor(connection).migrate(latest)
        assert not Favorito.objects.exists()
        assert get_user_model().objects.get(pk=owner.pk).nome == "migration"
        assert Local.objects.get(pk=local.pk).nome == local.nome
        assert ModalAvaliacao.objects.get(pk=review.pk).estrelas == 5
        assert VisitaRecente.objects.filter(pk=visit.pk).exists()
        assert RouteHistorySession.objects.get(pk=route.pk).status == "cancelled"
        assert list(ContributionPointEvent.objects.values()) == before
        assert list(PointActivity.objects.values()) == activity
    finally:
        MigrationExecutor(connection).migrate(latest)
