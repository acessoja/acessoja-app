import pytest
from django.contrib.auth import get_user_model
from django.core.cache import cache
from rest_framework.test import APIClient

from acessoja.accessibility_catalog import RESOURCE_IDS, catalog as resource_catalog
from acessoja.questionnaire_v3 import (
    BY_ID,
    DIMENSIONS,
    QUESTIONS,
    applicable,
    evidence_state,
    validate_answers,
)
from evidencias.models import ResourceEvidence
from locais.models import Local
from modal_avaliacao.models import ModalAvaliacao
from modal_avaliacao.questionnaire import complete

pytestmark = pytest.mark.django_db
URL = "/api/avaliacoes/modal-avaliacoes/"


def scene():
    cache.clear()
    user = get_user_model().objects.create_user(
        nome="survey-v3", email="survey-v3@example.test", password="securepass"
    )
    local = Local.objects.create(nome="Lugar", endereco="Rua", distancia=0)
    client = APIClient()
    client.force_authenticate(user)
    return user, local, client


def test_v3_catalog_has_stable_unique_ids_and_all_six_dimensions():
    ids = [question["id"] for question in QUESTIONS]
    assert len(ids) == 47
    assert len(ids) == len(set(ids)) == len(RESOURCE_IDS)
    assert {question["dimension"] for question in QUESTIONS} == set(DIMENSIONS)
    catalog = resource_catalog()
    assert catalog["version"] == 3
    assert len(catalog["resources"]) == len(ids)


@pytest.mark.parametrize(
    ("category", "subcategory", "include", "exclude"),
    [
        ("restaurante", "restaurante", "cardapio_braille", "quarto_adaptado"),
        ("parque", "parque", "caminhos_parque_acessiveis", "cardapio_braille"),
        ("saude", "clinica", "espera_tranquila", "quarto_adaptado"),
        ("outros", "hotel", "quarto_adaptado", "cardapio_braille"),
    ],
)
def test_profiles_include_relevant_features_and_exclude_unrelated(category, subcategory, include, exclude):
    ids = {
        question["id"]
        for question in applicable(category, subcategory, {"menu": True, "waiting": True})
    }
    assert include in ids
    assert exclude not in ids


def test_unknown_category_still_gets_general_questions():
    ids = {question["id"] for question in applicable("categoria_desconhecida")}
    assert "entrada_sem_degraus" in ids
    assert "espaco_tranquilo" in ids
    assert "quarto_adaptado" not in ids


def test_conditional_questions_require_confirmed_characteristics():
    assert "vagas_reservadas" not in {q["id"] for q in applicable("unknown")}
    assert "vagas_reservadas" in {q["id"] for q in applicable("unknown", characteristics={"parking": True})}
    assert "vagas_reservadas" not in {q["id"] for q in applicable("unknown", characteristics={"parking": False})}


def test_v3_partial_completion_does_not_require_all_resources():
    assert complete(3, {"espaco_tranquilo": "yes"})
    assert not complete(3, {})
    assert not complete(3, {"espaco_tranquilo": None})


def test_contextual_scales_are_not_promoted_to_permanent_accessibility():
    assert evidence_state("ruido_ambiente", "low") == "unknown"
    assert evidence_state("ruido_ambiente", "moderate") == "unknown"
    assert evidence_state("ruido_ambiente", "high") == "limited"
    assert evidence_state("espaco_tranquilo", "yes") == "presence_reported"


def test_answer_validation_keeps_partial_responses_and_rejects_unknown_ids():
    assert validate_answers({"espaco_tranquilo": "yes"}) == {"espaco_tranquilo": "yes"}
    assert validate_answers({"ruido_ambiente": "high"}) == {"ruido_ambiente": "high"}
    with pytest.raises(ValueError):
        validate_answers({"recurso_inventado": "yes"})
    with pytest.raises(ValueError):
        validate_answers({"ruido_ambiente": "yes"})


def test_v3_api_accepts_partial_answers_and_captures_sensor_context():
    user, local, client = scene()
    response = client.get(URL + "questionario/", {"category": "restaurante"})
    assert response.status_code == 200
    assert response.data["version"] == 3
    assert "cardapio_braille" not in {
        question["id"] for question in response.data["questions"]
    }
    response = client.get(
        URL + "questionario/",
        {"category": "restaurante", "menu": "true"},
    )
    assert {"cardapio_braille", "espaco_tranquilo"}.issubset(
        {question["id"] for question in response.data["questions"]}
    )
    assert "quarto_adaptado" not in {question["id"] for question in response.data["questions"]}
    assert client.get(URL + "questionario/", {"version": 2}).status_code == 400

    response = client.post(
        URL,
        {
            "local": local.pk,
            "estrelas": 4,
            "answers": {"espaco_tranquilo": "yes", "ruido_ambiente": "high"},
            "answer_details": {"ruido_ambiente": {"period": "night", "note": "Música alta"}},
        },
        format="json",
    )
    assert response.status_code == 201, response.data
    assert response.data["answers"]["ruido_ambiente"] == "high"
    assert response.data["questionnaire_version"] == 3
    review = ModalAvaliacao.objects.get(user=user, local=local)
    evidence = ResourceEvidence.objects.get(review=review, resource="ruido_ambiente")
    assert evidence.current_revision.state == "limited"
    assert evidence.source_metadata["observation"]["value"] == "high"
    assert evidence.source_metadata["observation"]["period"] == "night"
