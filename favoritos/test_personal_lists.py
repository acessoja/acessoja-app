import pytest
from django.contrib.auth import get_user_model
from django.db import connection
from django.test.utils import CaptureQueriesContext
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient

from locais.models import Local, VisitaRecente
from modal_avaliacao.models import ModalAvaliacao
from .models import EstadoPessoalLocal, Favorito, ItemLista, ListaPessoal

pytestmark = pytest.mark.django_db


def make_user(name):
    user = get_user_model().objects.create_user(nome=name, email=f"{name}@test.invalid", password="password-123")
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Token {Token.objects.get_or_create(user=user)[0].key}")
    return user, client


def test_lists_are_private_and_legacy_favorite_is_mirrored():
    owner, api = make_user("owner")
    other, other_api = make_user("other")
    local = Local.objects.create(nome="Biblioteca", endereco="Rua 1", distancia=0)

    assert api.get("/api/favoritos/listas/").status_code == 200
    created = api.post("/api/favoritos/", {"local": local.pk}, format="json")
    assert created.status_code == 201
    default = ListaPessoal.objects.get(user=owner, sistema=True)
    assert ItemLista.objects.filter(lista=default, local=local).exists()
    assert other_api.get("/api/favoritos/listas/").json()[0]["quantidade"] == 0
    assert other_api.post(f"/api/favoritos/listas/{default.pk}/itens/", {"local": local.pk}).status_code == 404


def test_saved_total_unions_favorites_and_lists_without_cross_account_rows():
    owner, api = make_user("saved-total-owner")
    _, other_api = make_user("saved-total-other")
    first = Local.objects.create(nome="Primeiro", endereco="Rua 1", distancia=0)
    second = Local.objects.create(nome="Segundo", endereco="Rua 2", distancia=0)
    custom = api.post("/api/favoritos/listas/", {"nome": "Passeios"}, format="json").json()["id"]
    api.post(f"/api/favoritos/listas/{custom}/itens/", {"local": first.pk}, format="json")
    api.post(f"/api/favoritos/listas/{custom}/itens/", {"local": second.pk}, format="json")
    api.post("/api/favoritos/", {"local": first.pk}, format="json")
    assert api.get("/api/favoritos/salvos-total/").json() == {"total": 2}
    assert other_api.get("/api/favoritos/salvos-total/").json() == {"total": 0}
    assert APIClient().get("/api/favoritos/salvos-total/").status_code == 401
    api.post(f"/api/favoritos/listas/{custom}/itens/", {"local": first.pk, "salvo": False}, format="json")
    assert api.get("/api/favoritos/salvos-total/").json() == {"total": 2}
    api.delete(f"/api/favoritos/listas/{custom}/")
    assert api.get("/api/favoritos/salvos-total/").json() == {"total": 1}


def test_same_local_can_be_in_multiple_lists_and_state_does_not_create_visit():
    user, api = make_user("lists")
    local = Local.objects.create(nome="Teatro", endereco="Rua 2", distancia=0)
    first = api.post("/api/favoritos/listas/", {"nome": "Passeios", "icone": "flag", "cor": "teal"}, format="json")
    second = api.post(
        "/api/favoritos/listas/",
        {"nome": "Fim de semana", "icone": "star", "cor": "purple"},
        format="json",
    )
    assert first.status_code == second.status_code == 201
    for response in (first, second):
        assert api.post(
            f"/api/favoritos/listas/{response.json()['id']}/itens/",
            {"local": local.pk},
            format="json",
        ).status_code == 200
    state = api.post(
        "/api/favoritos/estados/",
        {"local": local.pk, "status": "want", "nota": "Confirmar acesso"},
        format="json",
    )
    assert state.status_code == 201
    assert EstadoPessoalLocal.objects.get(user=user, local=local).nota == "Confirmar acesso"
    assert not VisitaRecente.objects.exists()
    assert api.post(
        "/api/favoritos/estados/", {"local": local.pk, "status": "visited"}, format="json",
    ).status_code == 200
    assert EstadoPessoalLocal.objects.get(user=user, local=local).nota == "Confirmar acesso"
    assert ItemLista.objects.filter(lista_id=first.json()["id"], local=local).exists()


def test_default_list_item_changes_keep_legacy_favorite_and_other_lists_in_sync():
    user, api = make_user("default-list-sync")
    local = Local.objects.create(nome="Mercado", endereco="Rua 8", distancia=0)
    assert api.get("/api/favoritos/listas/").status_code == 200
    default = ListaPessoal.objects.get(user=user, sistema=True)
    custom = api.post(
        "/api/favoritos/listas/",
        {"nome": "Compras", "icone": "shopping-cart", "cor": "green"},
        format="json",
    )
    assert custom.status_code == 201

    added = api.post(
        f"/api/favoritos/listas/{default.pk}/itens/",
        {"local": local.pk, "salvo": True},
        format="json",
    )
    assert added.status_code == 200
    assert Favorito.objects.filter(user=user, local=local).exists()
    assert ItemLista.objects.filter(lista_id=default.pk, local=local).exists()

    api.post(
        f"/api/favoritos/listas/{custom.json()['id']}/itens/",
        {"local": local.pk, "salvo": True},
        format="json",
    )
    removed = api.post(
        f"/api/favoritos/listas/{default.pk}/itens/",
        {"local": local.pk, "salvo": False},
        format="json",
    )
    assert removed.status_code == 200
    assert not Favorito.objects.filter(user=user, local=local).exists()
    assert not ItemLista.objects.filter(lista_id=default.pk, local=local).exists()
    assert ItemLista.objects.filter(lista_id=custom.json()["id"], local=local).exists()


def test_icon_catalog_accepts_bundle_identifiers():
    _, api = make_user("icon-catalog")
    for icon in ("heart", "wheelchair", "shopping-cart", "book-open"):
        response = api.post(
            "/api/favoritos/listas/",
            {"nome": f"Lista {icon}", "icone": icon, "cor": "purple"},
            format="json",
        )
        assert response.status_code == 201
        assert response.json()["icone"] == icon


def test_map_layer_returns_one_deterministic_marker_per_local():
    _, api = make_user("map-layer")
    local = Local.objects.create(nome="Praça", endereco="Rua 3", distancia=0)
    first = api.post("/api/favoritos/listas/", {"nome": "Principal", "icone": "flag", "cor": "teal"}, format="json")
    second = api.post("/api/favoritos/listas/", {"nome": "Depois", "icone": "star", "cor": "purple"}, format="json")
    for response in (first, second):
        assert api.post(
            f"/api/favoritos/listas/{response.json()['id']}/itens/",
            {"local": local.pk},
            format="json",
        ).status_code == 200
    response = api.get(f"/api/favoritos/listas/camada/?locais={local.pk}")
    assert response.status_code == 200
    assert response.json()["results"] == [{
        "local": local.pk, "icone": "flag", "cor": "teal", "listas": ["Principal", "Depois"], "status": "unknown",
    }]


def test_lists_endpoint_serializes_public_reviews_and_empty_rating_without_leaking_private_state():
    owner, api = make_user("list-reviews-owner")
    reviewer, _ = make_user("list-reviews-author")
    _, other_api = make_user("list-reviews-other")
    rated = Local.objects.create(nome="Museu", endereco="Rua A", distancia=0)
    unrated = Local.objects.create(nome="Biblioteca", endereco="Rua B", distancia=0)
    ModalAvaliacao.objects.create(user=reviewer, local=rated, estrelas=4)
    empty = api.get("/api/favoritos/listas/")
    assert empty.status_code == 200
    assert empty.json()[0]["quantidade"] == 0

    personal = ListaPessoal.objects.create(user=owner, nome="Passeios")
    ItemLista.objects.create(lista=personal, local=rated)
    ItemLista.objects.create(lista=personal, local=unrated)
    EstadoPessoalLocal.objects.create(user=owner, local=rated, nota="Somente eu")
    response = api.get("/api/favoritos/listas/")
    assert response.status_code == 200
    data = next(row for row in response.json() if row["id"] == personal.pk)
    assert data["quantidade"] == 2
    places = {item["local"]: item["local_detalhes"] for item in data["itens"]}
    assert places[rated.pk]["public_rating"] == {"average": 4.0, "count": 1}
    assert places[rated.pk]["media_estrelas"] == 4.0
    assert places[rated.pk]["quantidade_avaliacoes"] == 1
    assert places[unrated.pk]["public_rating"] == {"average": None, "count": 0}
    assert places[unrated.pk]["media_estrelas"] is None
    assert places[unrated.pk]["quantidade_avaliacoes"] == 0
    assert "Somente eu" not in str(response.data)
    assert all(row["id"] != personal.pk for row in other_api.get("/api/favoritos/listas/").json())


def test_lists_endpoint_batches_queries_as_list_grows():
    owner, api = make_user("list-batch-owner")
    personal = ListaPessoal.objects.create(user=owner, nome="Roteiro")
    first = Local.objects.create(nome="Local 1", endereco="Rua 1", distancia=0)
    ItemLista.objects.create(lista=personal, local=first)
    with CaptureQueriesContext(connection) as short_queries:
        assert api.get("/api/favoritos/listas/").status_code == 200
    for number in range(2, 12):
        local = Local.objects.create(nome=f"Local {number}", endereco=f"Rua {number}", distancia=0)
        ItemLista.objects.create(lista=personal, local=local)
    with CaptureQueriesContext(connection) as long_queries:
        response = api.get("/api/favoritos/listas/")
    assert response.status_code == 200
    assert len(long_queries) <= len(short_queries) + 2


def test_atomic_save_transfer_and_restore_complete_list_set():
    owner, api = make_user("atomic-personal-save")
    local = Local.objects.create(nome="Museu de Arte", endereco="Rua 9", distancia=0)
    assert api.get("/api/favoritos/listas/").status_code == 200
    favorite_list = ListaPessoal.objects.get(user=owner, sistema=True)
    restaurants = api.post(
        "/api/favoritos/listas/",
        {"nome": "Restaurantes", "icone": "utensils", "cor": "orange"},
        format="json",
    ).json()
    walks = api.post(
        "/api/favoritos/listas/",
        {"nome": "Passeios", "icone": "trees", "cor": "green"},
        format="json",
    ).json()
    ItemLista.objects.create(lista=favorite_list, local=local)
    Favorito.objects.create(user=owner, local=local)
    EstadoPessoalLocal.objects.create(user=owner, local=local, status="want", nota="Anotação privada")

    transfer = api.post("/api/favoritos/listas/aplicar/", {
        "local": local.pk,
        "listas": [restaurants["id"], walks["id"]],
        "novas": [],
        "status": "want",
        "nota": "Anotação privada",
        "esperado": {"listas": [favorite_list.pk], "status": "want", "nota": "Anotação privada"},
    }, format="json")
    assert transfer.status_code == 200, transfer.data
    assert {row["nome"] for row in transfer.data["listas"]} == {"Restaurantes", "Passeios"}
    assert transfer.data["favorito"] is False
    assert not Favorito.objects.filter(user=owner, local=local).exists()
    assert EstadoPessoalLocal.objects.get(user=owner, local=local).nota == "Anotação privada"

    removed = api.post("/api/favoritos/listas/aplicar/", {
        "local": local.pk, "listas": [], "novas": [], "status": "want", "nota": "Anotação privada",
        "esperado": {"listas": [restaurants["id"], walks["id"]], "status": "want", "nota": "Anotação privada"},
    }, format="json")
    assert removed.status_code == 200, removed.data
    assert removed.data["listas"] == []
    assert EstadoPessoalLocal.objects.get(user=owner, local=local).status == "want"

    restored = api.post("/api/favoritos/listas/aplicar/", {
        "local": local.pk, "listas": [restaurants["id"], walks["id"]], "novas": [],
        "status": "want", "nota": "Anotação privada",
        "esperado": {"listas": [], "status": "want", "nota": "Anotação privada"},
    }, format="json")
    assert restored.status_code == 200, restored.data
    assert {row["id"] for row in restored.data["listas"]} == {restaurants["id"], walks["id"]}


def test_atomic_save_rejects_stale_snapshot_without_partial_changes():
    user, api = make_user("atomic-save-conflict")
    local = Local.objects.create(nome="Teatro", endereco="Rua 10", distancia=0)
    assert api.get("/api/favoritos/listas/").status_code == 200
    favorite_list = ListaPessoal.objects.get(user=user, sistema=True)
    custom = ListaPessoal.objects.create(user=user, nome="Cultura")
    ItemLista.objects.create(lista=custom, local=local)
    response = api.post("/api/favoritos/listas/aplicar/", {
        "local": local.pk, "listas": [favorite_list.pk], "novas": [],
        "status": "unknown", "nota": "",
        "esperado": {"listas": [], "status": "unknown", "nota": ""},
    }, format="json")
    assert response.status_code == 409
    assert list(ItemLista.objects.filter(
        lista__user=user, local=local,
    ).values_list("lista_id", flat=True)) == [custom.pk]
