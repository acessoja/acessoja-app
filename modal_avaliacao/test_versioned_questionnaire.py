import copy
import pytest
from django.core.cache import cache
from django.contrib.auth import get_user_model
from django.db import connection
from django.db.migrations.executor import MigrationExecutor
from django.test.utils import CaptureQueriesContext
from rest_framework.test import APIClient
from contribuicoes.services import impact
from locais.models import Local
from modal_avaliacao.models import ModalAvaliacao
from modal_avaliacao.questionnaire import QUESTION_IDS

URL = "/api/avaliacoes/modal-avaliacoes/"
pytestmark = pytest.mark.django_db


@pytest.fixture
def records():
    cache.clear()
    user = get_user_model().objects.create_user(nome="survey-v2", email="survey@test.com", password="securepass")
    local = Local.objects.create(nome="Lugar", endereco="Rua", distancia=0, mesa_acessivel=True)
    client = APIClient()
    client.force_authenticate(user)
    yield user, local, client
    cache.clear()


def payload(local, **kwargs):
    return {"local": local.pk, "estrelas": 4, "questionnaire_version": 2,
            "answers": dict.fromkeys(QUESTION_IDS, "unknown"), **kwargs}


def test_catalog_and_four_codes_roundtrip(records):
    user, local, client = records
    response = client.get(URL + "questionario/")
    assert response.status_code == 200 and len(response.data["questions"]) == 8
    body = payload(local)
    for key, value in zip(QUESTION_IDS[:4], ["yes", "no", "unknown", "not_applicable"]):
        body["answers"][key] = value
    response = client.post(URL, body, format="json")
    assert response.status_code == 201 and response.data["answers"] == body["answers"]
    review = ModalAvaliacao.objects.get()
    assert review.user == user and review.survey_completed
    assert review.pergunta_3 == "" and review.pergunta_4 == ""
    assert impact(user)["points"] == 15
    local.refresh_from_db()
    assert local.mesa_acessivel and not local.cao_guia
    assert client.get(f"{URL}{review.pk}/").data["answers"] == body["answers"]


@pytest.mark.parametrize("change", [
    {"answers": []}, {"answers": None}, {"answers": {"other": "yes"}},
    {"answers": {"rampa_acesso": True}}, {"answers": {"rampa_acesso": "Sim"}},
    {"questionnaire_version": "2"}, {"questionnaire_version": True},
    {"questionnaire_version": 9}, {"pergunta_3": "Sim"}, {"user": 99},
    {"answer_dates": {}}, {"other": "data"}, {"answers": {"rampa_acesso": "yes"}},
    {"estrelas": "4"}, {"estrelas": True}, {"comentario": 42},
])
def test_invalid_creation_is_atomic(records, change):
    user, local, client = records
    assert client.post(URL, payload(local, **change), format="json").status_code == 400
    assert not ModalAvaliacao.objects.exists()
    assert impact(user)["points"] == 0


def test_partial_update_clear_and_no_duplicate_points(records):
    user, local, client = records
    created = client.post(URL, payload(local), format="json").data
    detail = f"{URL}{created['id']}/"
    dates = copy.deepcopy(created["answer_dates"])
    updated = client.patch(detail, {"comentario": "Comentário opcional"}, format="json")
    assert updated.status_code == 200 and updated.data["answers"] == created["answers"]
    assert updated.data["answer_dates"] == dates and updated.data["points_delta"] == 0
    updated = client.patch(detail, {"answers": {"mesa_acessivel": "yes"}}, format="json")
    assert updated.data["answers"]["rampa_acesso"] == "unknown" and updated.data["points_delta"] == 0
    cleared = client.patch(detail, {"answers": {"mesa_acessivel": None}}, format="json")
    assert "mesa_acessivel" not in cleared.data["answers"] and not cleared.data["survey_completed"]
    assert cleared.data["points_delta"] == -5
    restored = client.patch(detail, {"answers": {"mesa_acessivel": "not_applicable"}}, format="json")
    assert restored.data["points_delta"] == 5
    replay = client.patch(detail, {"answers": {"mesa_acessivel": "not_applicable"}}, format="json")
    assert replay.data["points_delta"] == 0
    assert impact(user)["points"] == 15
    assert client.post(URL, payload(local), format="json").status_code == 409
    assert client.delete(detail).status_code == 204
    assert impact(user)["points"] == 0
    assert client.get(URL + "recursos/", {"local_id": local.pk}).data["people"] == 0


def test_invalid_patch_cannot_change_review_local_or_points(records):
    user, local, client = records
    created = client.post(URL, payload(local), format="json").data
    detail = f"{URL}{created['id']}/"
    result = client.patch(detail, {"comentario": "must not persist", "answers": {"cao_guia": "maybe"}}, format="json")
    assert result.status_code == 400
    review = ModalAvaliacao.objects.get()
    assert review.comentario == "" and review.answers == created["answers"]
    assert impact(user)["points"] == 15


def test_full_update_and_author_permissions(records):
    _, local, client = records
    created = client.post(URL, payload(local), format="json").data
    detail = f"{URL}{created['id']}/"
    body = payload(local, estrelas=2, comentario="Editada")
    assert client.put(detail, body, format="json").status_code == 200
    other = get_user_model().objects.create_user(nome="other-v2", email="other@test.com", password="securepass")
    client.force_authenticate(other)
    assert client.patch(detail, {"comentario": "Not mine"}, format="json").status_code == 403
    assert client.delete(detail).status_code == 403
    client.force_authenticate(None)
    assert client.post(URL, body, format="json").status_code == 401


def test_legacy_comment_edit_preserves_raw_answers_without_reinterpreting(records):
    _, local, client = records
    body = {"local": local.pk, "estrelas": 4, **{f"pergunta_{i}": "Sim" for i in range(1, 5)}}
    created = client.post(URL, body, format="json").data
    detail = f"{URL}{created['id']}/"
    assert created["questionnaire_version"] == 1 and created["answers"] == {}
    updated = client.patch(detail, {"comentario": "Só texto"}, format="json").data
    assert updated["questionnaire_version"] == 1
    assert all(updated[f"pergunta_{i}"] == "Sim" for i in range(1, 5))
    assert client.patch(detail, {"questionnaire_version": 2}, format="json").status_code == 400
    upgraded = client.patch(detail, payload(local), format="json")
    assert upgraded.status_code == 200 and upgraded.data["questionnaire_version"] == 2
    assert upgraded.data["pergunta_3"] == "Sim"
    assert upgraded.data["data_resposta"] == created["data_resposta"]
    assert upgraded.data["points_delta"] == 0


def test_unconfirmed_legacy_defaults_cannot_earn_survey_points_by_comment_edit(records):
    user, local, client = records
    review = ModalAvaliacao.objects.create(
        user=user, local=local, estrelas=4, verified_author=True, survey_completed=False,
        **{f"pergunta_{i}": "Não sei" for i in range(1, 5)},
    )
    before = impact(user)["points"]
    result = client.patch(f"{URL}{review.pk}/", {"comentario": "Só o comentário"}, format="json")
    assert result.status_code == 200 and result.data["points_delta"] == 0
    assert result.data["survey_completed"] is False
    assert impact(user)["points"] == before == 10


def test_aggregate_privacy_divergence_dates_and_history(records):
    user, local, client = records
    created = client.post(URL, payload(local, answers=dict.fromkeys(QUESTION_IDS, "yes")), format="json").data
    other = get_user_model().objects.create_user(nome="votes-v2", email="votes@test.com", password="securepass")
    other_client = APIClient()
    other_client.force_authenticate(other)
    other_client.post(URL, payload(local, answers=dict.fromkeys(QUESTION_IDS, "no")), format="json")
    result = client.get(URL + "recursos/", {"local_id": local.pk}).data
    assert result["people"] == 2
    assert all(f["state"] == "divergent" and f["counts"]["yes"] == f["counts"]["no"] == 1 for f in result["features"])
    other.mostrar_avaliacoes = False
    other.save()
    result = client.get(URL + "recursos/", {"local_id": local.pk}).data
    assert result["people"] == 1
    assert result["features"][0]["latest_at"] == created["answer_dates"]["rampa_acesso"]
    ModalAvaliacao.objects.create(user=user, local=local, is_current=False, estrelas=3, pergunta_3="Sim")
    assert len(client.get(URL, {"local_id": local.pk}).data) == 1
    assert len(client.get(URL, {"local_id": local.pk, "include_history": "1"}).data) == 2
    assert client.get(URL + "recursos/", {"local_id": local.pk}).data["people"] == 1


@pytest.mark.parametrize("local_id,status", [("bad", 400), ("0", 400), ("999999", 404)])
def test_summary_invalid_local(records, local_id, status):
    assert records[2].get(URL + "recursos/", {"local_id": local_id}).status_code == status


def test_summary_and_review_list_queries_do_not_scale_per_feature_or_row(records):
    _, local, client = records
    for i in range(8):
        user = get_user_model().objects.create_user(nome=f"bulk-{i}", email=f"bulk-{i}@test.com", password="securepass")
        ModalAvaliacao.objects.create(user=user, local=local, estrelas=4, questionnaire_version=2,
                                     answers=dict.fromkeys(QUESTION_IDS, "yes"))
    with CaptureQueriesContext(connection) as queries:
        response = client.get(URL + "recursos/", {"local_id": local.pk})
    assert response.data["people"] == 8 and len(queries) <= 4
    with CaptureQueriesContext(connection) as queries:
        response = client.get(URL, {"local_id": local.pk})
    assert len(response.data) == 8 and len(queries) <= 5


@pytest.mark.django_db(transaction=True)
def test_migration_preserves_raw_history():
    executor = MigrationExecutor(connection)
    before = [("modal_avaliacao", "0005_modalavaliacao_survey_completed")]
    after = [("modal_avaliacao", "0006_versioned_questionnaire")]
    # The migration target only rolls back modal_avaliacao. The usuarios and
    # locais tables keep their latest physical schema, including columns that
    # older historical model classes do not know how to populate.
    user = get_user_model().objects.create_user(
        nome="migration-v2", email="migration@test.com", password="test-password",
    )
    place = Local.objects.create(nome="Antigo", endereco="Rua", distancia=0)
    try:
        executor.migrate(before)
        apps = executor.loader.project_state(before).apps
        Review = apps.get_model("modal_avaliacao", "ModalAvaliacao")
        old = Review.objects.create(
            user_id=user.pk, local_id=place.pk, estrelas=4, comentario="Preservar",
            pergunta_1="Sim", pergunta_2="Não", pergunta_3="Sim", pergunta_4="Não sei",
        )
        original_date = old.data_resposta
        executor = MigrationExecutor(connection)
        executor.migrate(after)
        Review = executor.loader.project_state(after).apps.get_model("modal_avaliacao", "ModalAvaliacao")
        restored = Review.objects.get(pk=old.pk)
        assert restored.questionnaire_version == 1 and restored.answers == {}
        assert restored.pergunta_3 == "Sim" and restored.pergunta_4 == "Não sei"
        assert restored.comentario == "Preservar" and restored.estrelas == 4
        assert restored.user_id == user.pk and restored.data_resposta == original_date
    finally:
        MigrationExecutor(connection).migrate(after)
