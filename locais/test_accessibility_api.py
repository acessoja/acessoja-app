from unittest.mock import patch

import pytest
from django.contrib.auth import get_user_model
from django.db import connection
from django.db.migrations.executor import MigrationExecutor
from django.test.utils import CaptureQueriesContext
from django.utils import timezone
from rest_framework.test import APIClient

from acessoja.accessibility_catalog import LEGACY_FLAGS, RESOURCE_IDS
from locais.models import Local
from modal_avaliacao.models import ModalAvaliacao

URL = "/api/locais/"
pytestmark = pytest.mark.django_db


@pytest.fixture
def people():
    User = get_user_model()
    staff = User.objects.create_superuser(
        nome="catalog-staff", email="staff@catalog.test", password="test-password"
    )
    author = User.objects.create_user(
        nome="catalog-author", email="author@catalog.test", password="test-password"
    )
    private = User.objects.create_user(
        nome="catalog-private",
        email="private@catalog.test",
        password="test-password",
        mostrar_avaliacoes=False,
    )
    client = APIClient()
    client.force_authenticate(staff)
    return staff, author, private, client


def local(**kwargs):
    return Local.objects.create(nome="Café", endereco="Rua", distancia=0, categoria="cafeteria", **kwargs)


def observation(state):
    return {"state": state, "source": "test-explicit", "note": "fixture", "observed_at": None}


def test_catalog_is_public_and_aligned():
    response = APIClient().get(URL + "recursos/")
    assert response.status_code == 200
    assert [item["id"] for item in response.data["resources"]] == list(RESOURCE_IDS)
    assert response.data["version"] == 1


def test_historical_booleans_true_and_false_remain_unknown():
    record = local(mesa_acessivel=True, cao_guia=True, rampa_acesso=True)
    result = APIClient().get(f"{URL}{record.pk}/").data
    assert result["mesa_acessivel"] is True and result["banheiro_acessivel"] is False
    assert result["accessibility_information"] == {}
    assert all(entry["state"] == "unknown" for entry in result["accessibility"].values())
    assert APIClient().get(URL, {"mesa_acessivel": "true"}).data == []


def test_new_creation_explicit_states_dates_and_omission(people):
    staff, author, private, client = people
    client.force_authenticate(author)
    information = {
        "piso_tatil": {"state": "presence_reported"},
        "atendimento_libras": {"state": "unknown", "note": "Consulte horário"},
    }
    response = client.post(
        URL,
        {
            "nome": "Novo",
            "endereco": "Rua",
            "distancia": 0,
            "accessibility_information": information,
        },
        format="json",
    )
    assert response.status_code == 201
    result = response.data
    assert result["accessibility"]["piso_tatil"]["state"] == "presence_reported"
    assert result["accessibility"]["sinalizacao_visual"]["state"] == "unknown"
    assert result["accessibility_information"]["piso_tatil"]["observed_at"] is None
    assert result["accessibility_information"]["piso_tatil"]["source"] == "acessoja_registration"
    assert result["accessibility_information"]["piso_tatil"]["received_at"]


@pytest.mark.parametrize(
    "invalid",
    [
        None,
        [],
        {"other": {"state": "unknown"}},
        {"piso_tatil": {"state": "yes"}},
        {"piso_tatil": {"state": False}},
        {"piso_tatil": {"state": "unknown", "source": "certified"}},
        {"piso_tatil": {"state": "unknown", "note": 42}},
        {"piso_tatil": {"state": "unknown", "observed_at": "2026-10-13"}},
        {"piso_tatil": {"state": "unknown", "received_at": "2026-10-13T09:00:00Z"}},
    ],
)
def test_invalid_patch_is_atomic(people, invalid):
    client = people[-1]
    record = local(accessibility_information={"piso_tatil": observation("presence_reported")})
    before = record.accessibility_information.copy()
    result = client.patch(
        f"{URL}{record.pk}/", {"nome": "Do not change", "accessibility_information": invalid}, format="json"
    )
    assert result.status_code == 400
    record.refresh_from_db()
    assert record.nome == "Café" and record.accessibility_information == before


def test_patch_preserves_omitted_and_null_removes_one_evidence(people):
    client = people[-1]
    record = local(
        accessibility_information={
            "piso_tatil": observation("presence_reported"),
            "sinalizacao_visual": observation("absence_reported"),
        }
    )
    detail = f"{URL}{record.pk}/"
    assert client.patch(detail, {"nome": "Updated"}, format="json").status_code == 200
    assert (
        client.patch(detail, {"accessibility_information": {"piso_tatil": None}}, format="json").status_code
        == 200
    )
    record.refresh_from_db()
    assert "piso_tatil" not in record.accessibility_information
    assert record.accessibility_information["sinalizacao_visual"]["state"] == "absence_reported"
    assert client.get(detail).data["accessibility"]["piso_tatil"]["state"] == "unknown"


def test_existing_write_permissions_are_preserved(people):
    staff, author, private, client = people
    record = local()
    client.force_authenticate(author)
    assert (
        client.patch(f"{URL}{record.pk}/", {"accessibility_information": {}}, format="json").status_code
        == 403
    )
    client.force_authenticate(None)
    response = client.post(URL, {"nome": "Guest", "endereco": "Rua", "distancia": 0}, format="json")
    assert response.status_code in (401, 403)


def test_filters_combine_categories_sources_resources_and_incomplete():
    both = local(
        osm_id="osm:node:909",
        accessibility_information={
            "rampa_acesso": observation("presence_reported"),
            "banheiro_acessivel": observation("presence_reported"),
        },
    )
    partial = local(accessibility_information={"rampa_acesso": observation("presence_reported")})
    absent = local(accessibility_information={"rampa_acesso": observation("absence_reported")})
    client = APIClient()
    params = {"categorias": "cafeteria,restaurante", "recursos": "rampa_acesso,banheiro_acessivel"}
    assert [row["id_local"] for row in client.get(URL, params).data] == [both.pk]
    result = client.get(URL, {**params, "incluir_desconhecidos": "true"}).data
    assert [row["id_local"] for row in result] == [both.pk, partial.pk]
    assert result[1]["missing_resources"] == ["banheiro_acessivel"]
    assert absent.pk not in [row["id_local"] for row in result]
    assert [row["id_local"] for row in client.get(URL, {**params, "origens": "openstreetmap"}).data] == [
        both.pk
    ]
    assert client.get(URL, {**params, "categorias": "banco"}).data == []
    assert len(client.get(URL).data) == 3


@pytest.mark.parametrize(
    "params",
    [
        {"recursos": "invalid"},
        {"categorias": "hospital"},
        {"origens": "all"},
        {"incluir_desconhecidos": "yes"},
        {"rampa_acesso": "1"},
        {"unknown_parameter": "x"},
    ],
)
def test_invalid_filters_are_not_silently_ignored(params):
    assert APIClient().get(URL, params).status_code == 400


def test_repeated_filter_parameter_is_rejected():
    assert APIClient().get(URL + "?recursos=rampa_acesso&recursos=piso_tatil").status_code == 400


def test_community_unknown_na_divergence_and_private_visibility(people):
    staff, author, private, client = people
    record = local()
    ModalAvaliacao.objects.create(
        local=record,
        user=author,
        estrelas=3,
        questionnaire_version=2,
        answers={"rampa_acesso": "yes", "banheiro_acessivel": "not_applicable"},
    )
    ModalAvaliacao.objects.create(
        local=record, user=private, estrelas=3, questionnaire_version=2, answers={"rampa_acesso": "no"}
    )
    public = APIClient()
    params = {"recursos": "rampa_acesso"}
    assert len(public.get(URL, params).data) == 1
    client.force_authenticate(private)
    # Own private history never changes a public place projection (Cards 38–41).
    signed_in = client.get(URL, params).data
    assert [item["id_local"] for item in signed_in] == [record.pk]
    assert signed_in[0]["accessibility"]["rampa_acesso"]["state"] == "presence_reported"
    assert len(client.get(URL, {**params, "incluir_desconhecidos": "true"}).data) == 1
    assert public.get(URL, {"recursos": "banheiro_acessivel", "incluir_desconhecidos": "true"}).data == []


def test_ambiguous_old_question_cannot_set_a_resource(people):
    staff, author, private, client = people
    record = local(mesa_acessivel=True, cao_guia=True)
    ModalAvaliacao.objects.create(local=record, user=author, estrelas=3, pergunta_3="Sim", pergunta_4="Sim")
    response = client.get(f"{URL}{record.pk}/").data
    assert response["accessibility"]["mesa_acessivel"]["state"] == "unknown"
    assert response["accessibility"]["cao_guia"]["state"] == "unknown"
    assert response["accessibility"]["vagas_reservadas"]["state"] == "unknown"


def test_list_queries_are_bounded_by_batches(people):
    for _ in range(12):
        local()
    with CaptureQueriesContext(connection) as queries:
        result = people[-1].get(URL)
    assert result.status_code == 200 and len(result.data) == 12
    assert len(queries) <= 3


def test_external_matching_includes_linked_state_without_creating_a_record(people):
    record = local(
        osm_id="osm:node:909",
        accessibility_information={"banheiro_acessivel": observation("absence_reported")},
    )
    place = {
        "external_id": "osm:node:909",
        "id": "osm:node:909",
        "nome": "Café",
        "categoria": "cafeteria",
        "endereco": "Rua",
        "latitude": -16.3,
        "longitude": -48.9,
        "accessibility_data": {"wheelchair": "yes", "toilets:wheelchair": "yes"},
    }
    result = {"results": [place], "truncated": False}
    with patch("locais.external_views.ExternalPlacesService.search", return_value=result):
        response = APIClient().get(URL + "externos/", {"latitude": -16.3, "longitude": -48.9})
    assert response.status_code == 200 and Local.objects.count() == 1
    result = response.data["results"][0]
    assert result["internal_id"] == record.pk
    assert result["linked_local"]["accessibility"]["banheiro_acessivel"]["state"] == "divergent"
    assert {
        item["source_kind"]
        for item in result["linked_local"]["accessibility"]["banheiro_acessivel"]["evidence"]
    } == {"not_recorded", "openstreetmap"}
    assert result["accessibility"]["rampa_acesso"]["state"] == "unknown"
    assert response["Cache-Control"] == "private, no-store"


@pytest.mark.django_db(transaction=True)
def test_new_migrations_preserve_raw_flags_review_authors_dates_and_empty_preferences():
    executor = MigrationExecutor(connection)
    after = executor.loader.graph.leaf_nodes()
    before_names = {
        "locais": "0007_visitarecente_arrival_confirmed",
        "usuarios": "0003_usuario_is_active_usuario_is_staff_and_more",
        "modal_avaliacao": "0006_versioned_questionnaire",
    }
    before = [
        (app, before_names.get(app, name)) for app, name in after if app not in {"favoritos", "evidencias"}
    ]
    try:
        # Favorites and evidence depend on later schemas; neither existed at this historical
        # target. Unapply it explicitly instead of mixing current model state
        # with the downgraded local table. All original preservation checks stay.
        executor.migrate(before + [("favoritos", None), ("evidencias", None)])
        apps = executor.loader.project_state(before).apps
        User = apps.get_model("usuarios", "Usuario")
        Place = apps.get_model("locais", "Local")
        Review = apps.get_model("modal_avaliacao", "ModalAvaliacao")
        user = User.objects.create(
            nome="old-catalog",
            email="old@catalog.test",
            password="preserved-hash",
            data_criacao=timezone.now(),
        )
        record = Place.objects.create(
            nome="Historical", endereco="Rua", distancia=0, mesa_acessivel=True, cao_guia=True
        )
        review = Review.objects.create(
            local_id=record.pk,
            user_id=user.pk,
            estrelas=4,
            comentario="Preserve me",
            pergunta_3="Sim",
            pergunta_4="Não sei",
        )
        original_date = review.data_resposta
        MigrationExecutor(connection).migrate(after)
        restored = Local.objects.get(pk=record.pk)
        assert restored.accessibility_information == {}
        assert all(getattr(restored, key) == getattr(record, key) for key in LEGACY_FLAGS)
        restored_user = get_user_model().objects.get(pk=user.pk)
        assert restored_user.accessibility_preferences == [] and restored_user.password == "preserved-hash"
        restored_review = ModalAvaliacao.objects.get(pk=review.pk)
        assert restored_review.comentario == "Preserve me" and restored_review.pergunta_3 == "Sim"
        assert restored_review.data_resposta == original_date and restored_review.user_id == user.pk
        assert (
            APIClient().get(f"{URL}{record.pk}/").data["accessibility"]["mesa_acessivel"]["state"]
            == "unknown"
        )
    finally:
        MigrationExecutor(connection).migrate(after)
