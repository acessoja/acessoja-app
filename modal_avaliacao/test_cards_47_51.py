"""Cards 47–51: real API, database, synthetic raster and private filesystem."""

import uuid
from unittest.mock import patch

from django.db import transaction
from django.db.models import Sum
import pytest

from contribuicoes.models import ContributionPointEvent, PointActivity
from contribuicoes.services import impact, reconcile_user
from evidencias.models import EvidenceOperation, EvidenceRevision, ResourceEvidence
from midia.models import ImageDecision
from midia.test_images import api, approve, send_photo
from midia import test_images
from midia.moderation import decide_photo
from .models import ModalAvaliacao, ReviewOperation
from .questionnaire import QUESTION_IDS

pytestmark = pytest.mark.django_db
scene = test_images.scene
URL = "/api/avaliacoes/modal-avaliacoes/"
OBS = "/api/evidencias/relatos/"


def review_body(local, **extra):
    return {"operation_id": str(uuid.uuid4()), "local": local.pk, "estrelas": 4, "questionnaire_version": 2, **extra}


def statement(local, resource="piso_tatil", **extra):
    return {"operation_id": str(uuid.uuid4()), "local_id": local.pk, "resource": resource, "value": "yes", **extra}


def delete_existing(scene):
    scene[4].delete()


@pytest.mark.parametrize(
    "answers", [{}, {"rampa_acesso": "yes"}, {"rampa_acesso": "unknown", "banheiro_acessivel": "not_applicable"}]
)
def test_t01_t04_partial_creation_never_invents_answers_or_survey_points(scene, answers):
    owner, _, _, local, _ = scene
    delete_existing(scene)
    response = api(owner).post(URL, review_body(local, answers=answers), format="json")
    assert response.status_code == 201, response.data
    assert response.data["answers"] == answers and not response.data["survey_completed"]
    assert impact(owner)["points"] == 10
    assert not ContributionPointEvent.objects.filter(user=owner, action="survey").exists()


def test_t02_stars_are_required_and_independent_does_not_create_fake_review(scene):
    owner, _, _, local, _ = scene
    delete_existing(scene)
    body = review_body(local)
    body.pop("estrelas")
    assert api(owner).post(URL, body, format="json").status_code == 400
    response = api(owner).post(OBS, statement(local), format="json")
    assert response.status_code == 200, response.data
    assert ModalAvaliacao.objects.count() == 0 and impact(owner)["points"] == 0
    assert ResourceEvidence.objects.get(pk=response.data["evidence_id"]).resource == "piso_tatil"


def test_t06_t08_survey_complete_partial_complete_reuses_one_auditable_right(scene):
    owner, _, _, local, _ = scene
    delete_existing(scene)
    client = api(owner)
    complete = dict.fromkeys(QUESTION_IDS, "unknown")
    result = client.post(URL, review_body(local, answers=complete), format="json").data
    endpoint = f"{URL}{result['id']}/"
    assert result["survey_completed"] and impact(owner)["points"] == 15
    for answers, total in [({"rampa_acesso": None}, 10), ({"rampa_acesso": "not_applicable"}, 15)]:
        response = client.patch(
            endpoint, {"expected_revision": result["content_revision"], "answers": answers}, format="json"
        )
        assert response.status_code == 200, response.data
        result = response.data
        assert impact(owner)["points"] == total
    event = ContributionPointEvent.objects.get(user=owner, action="survey")
    assert list(PointActivity.objects.filter(event=event).order_by("pk").values_list("delta", flat=True)) == [5, -5, 5]
    assert reconcile_user(owner.pk, apply=True)["events_changed"] == 0


def test_t07_patch_omission_empty_map_and_null_have_distinct_meanings(scene):
    owner, _, _, local, _ = scene
    delete_existing(scene)
    client = api(owner)
    result = client.post(
        URL, review_body(local, answers={"rampa_acesso": "yes", "cao_guia": "unknown"}), format="json"
    ).data
    endpoint = f"{URL}{result['id']}/"
    for patch_body, expected in [
        ({}, {"rampa_acesso": "yes", "cao_guia": "unknown"}),
        ({"answers": {}}, {"rampa_acesso": "yes", "cao_guia": "unknown"}),
        ({"answers": {"rampa_acesso": None}}, {"cao_guia": "unknown"}),
    ]:
        response = client.patch(endpoint, patch_body, format="json")
        assert response.status_code == 200 and response.data["answers"] == expected
    assert client.patch(endpoint, {"answers": None}, format="json").status_code == 400


def test_t09_legacy_comment_and_photographs_never_convert_v1(scene):
    review = scene[4]
    review.pergunta_1 = "Sim"
    review.save()
    before = review.content_revision
    response = api(scene[0]).patch(
        f"{URL}{review.pk}/", {"expected_revision": str(before), "comentario": "Updated experience"}, format="json"
    )
    assert response.status_code == 200 and response.data["questionnaire_version"] == 1
    assert response.data["pergunta_1"] == "Sim" and response.data["answers"] == {}
    review.refresh_from_db()
    send_photo(scene)
    review.refresh_from_db()
    assert review.questionnaire_version == 1


def test_t10_t12_t13_single_effective_author_across_survey_and_independent_paths(scene):
    owner, _, _, local, review = scene
    review.questionnaire_version, review.answers = 2, {"rampa_acesso": "yes"}
    review.save()
    first = ResourceEvidence.objects.get(review=review, resource="rampa_acesso")
    body = statement(local, "rampa_acesso", value="no", note="Observed entrance")
    response = api(owner).post(OBS, body, format="json")
    assert response.status_code == 200, response.data
    root = ResourceEvidence.objects.get(pk=response.data["evidence_id"])
    first.refresh_from_db()
    assert first.superseded and not root.superseded
    public = api().get("/api/evidencias/", {"local_id": local.pk, "resource": "rampa_acesso"})
    assert public.data["count"] == 1 and public.data["results"][0]["state"] == "absence_reported"
    # A text-only review update cannot reclaim the latest resource assertion.
    review.comentario = "Changed text only"
    review.save()
    first.refresh_from_db()
    assert first.superseded
    remove = {"operation_id": str(uuid.uuid4()), "expected_revision": str(root.current_revision_id)}
    endpoint = f"{OBS}{root.pk}/"
    assert api(owner).delete(endpoint, remove, format="json").status_code == 200
    assert api(owner).delete(endpoint, remove, format="json").status_code == 200
    assert api().get("/api/evidencias/", {"local_id": local.pk, "resource": "rampa_acesso"}).data["count"] == 0
    assert first.revisions.count() == 1  # No silent historical resurrection.


def test_t13_invalidating_latest_statement_does_not_reveal_older_survey(scene):
    owner, _, _, local, review = scene
    review.questionnaire_version, review.answers = 2, {"rampa_acesso": "yes"}
    review.save()
    response = api(owner).post(OBS, statement(local, "rampa_acesso", value="no"), format="json")
    root = ResourceEvidence.objects.get(pk=response.data["evidence_id"])
    EvidenceRevision.objects.filter(pk=root.current_revision_id).update(is_valid=False)
    assert api().get("/api/evidencias/", {"local_id": local.pk, "resource": "rampa_acesso"}).data["count"] == 0
    assert (
        api(owner)
        .post(
            OBS,
            statement(local, "rampa_acesso", value="no", expected_revision=str(root.current_revision_id)),
            format="json",
        )
        .status_code
        == 400
    )


@pytest.mark.parametrize("resource", ["piso_tatil", "sinalizacao_visual", *QUESTION_IDS])
def test_t03_t10_independent_can_start_each_of_the_ten_resources(scene, resource):
    owner, _, _, local, _ = scene
    delete_existing(scene)
    response = api(owner).post(OBS, statement(local, resource, value="unknown"), format="json")
    assert response.status_code == 200, response.data
    assert ModalAvaliacao.objects.count() == 0 and response.data["state"] == "committed"


def test_t19_t27_review_lost_response_replay_and_owner_only_receipt(scene):
    owner, reader, _, local, _ = scene
    delete_existing(scene)
    body = review_body(local, answers={"rampa_acesso": "unknown"})
    first = api(owner).post(URL, body, format="json")
    second = api(owner).post(URL, body, format="json")
    assert first.status_code == 201 and second.status_code == 200
    assert first.data["id"] == second.data["id"] and ModalAvaliacao.objects.count() == 1
    assert ReviewOperation.objects.count() == 1
    assert api(owner).post(URL, {**body, "estrelas": 1}, format="json").status_code == 409
    receipt = f"{URL}operacoes/{body['operation_id']}/"
    assert api(owner).get(receipt).data["review_id"] == first.data["id"]
    assert api(reader).get(receipt).status_code == 404
    count = PointActivity.objects.count()
    api(owner).delete(f"{URL}{first.data['id']}/")
    assert api(owner).post(URL, body, format="json").status_code == 410
    assert ModalAvaliacao.objects.count() == 0 and PointActivity.objects.count() == count + 1


def test_t19_t30_t31_statement_replay_conflict_and_authorization(scene):
    owner, reader, _, local, _ = scene
    body = statement(local)
    first = api(owner).post(OBS, body, format="json")
    assert first.status_code == 200, first.data
    assert api(owner).post(OBS, body, format="json").data == first.data
    assert EvidenceOperation.objects.count() == 1
    assert api(owner).post(OBS, {**body, "value": "no"}, format="json").status_code == 409
    assert api(owner).post(OBS, statement(local), format="json").status_code == 409
    assert api(reader).get(f"/api/evidencias/operacoes/{body['operation_id']}/").status_code == 404
    assert (
        api(reader)
        .delete(
            f"{OBS}{first.data['evidence_id']}/",
            {"operation_id": str(uuid.uuid4()), "expected_revision": first.data["revision"]},
            format="json",
        )
        .status_code
        == 404
    )


def test_t21_t24_t25_t34_photo_points_grant_revoke_restore_stabilize_one_right(scene):
    owner = scene[0]
    a, _ = send_photo(scene)
    b, _ = send_photo(scene)
    assert impact(owner)["points"] == 10
    approve(scene, a)
    approve(scene, b)
    assert impact(owner)["points"] == 13
    for photo in [a, b]:
        response = api(owner).patch(
            f"/api/midia/fotos/{photo.pk}/",
            {
                "operation_id": str(uuid.uuid4()),
                "expected_revision": str(photo.current_revision_id),
                "description": "Updated synthetic resource description",
            },
            format="json",
        )
        assert response.status_code == 200, response.data
        photo.refresh_from_db()
        assert impact(owner)["points"] == (13 if photo.pk == a.pk else 10)
    approve(scene, a)
    event = ContributionPointEvent.objects.get(user=owner, action="photo_evidence")
    assert list(PointActivity.objects.filter(event=event).order_by("pk").values_list("delta", flat=True)) == [3, -3, 3]
    for _ in range(3):
        assert reconcile_user(owner.pk, apply=True)["events_changed"] == 0
    assert PointActivity.objects.filter(event=event).aggregate(n=Sum("delta"))["n"] == 3
    owner.mostrar_avaliacoes = False
    owner.save(update_fields=["mostrar_avaliacoes"])
    assert impact(owner)["points"] == 10
    owner.mostrar_avaliacoes = True
    owner.save(update_fields=["mostrar_avaliacoes"])
    assert impact(owner)["points"] == 13


def test_t22_rejection_exports_safe_author_guidance_not_internal_notes_or_reporter(scene):
    photo, _ = send_photo(scene)
    decide_photo(
        scene[2].pk,
        photo.pk,
        action="reject",
        reason="INTERNAL_CANARY reporter confidential",
        author_reason="privacy",
        revision_id=photo.current_revision_id,
        expected_version=1,
        operation_id=uuid.uuid4(),
    )
    result = api(scene[0]).get(f"/api/midia/fotos/{photo.pk}/")
    assert result.data["rejection_reason"] == "privacy"
    assert "INTERNAL_CANARY" not in str(result.data)
    assert api(scene[1]).get(f"/api/midia/fotos/{photo.pk}/").status_code == 404


def test_t26_t33_photo_decision_and_points_are_one_database_transaction(scene):
    photo, _ = send_photo(scene)
    with patch("contribuicoes.services._apply_plan", side_effect=RuntimeError("synthetic ledger failure")):
        with pytest.raises(RuntimeError), transaction.atomic():
            approve(scene, photo)
    photo.refresh_from_db()
    assert photo.current_revision.state == "pending" and ImageDecision.objects.count() == 0
    assert impact(scene[0])["points"] == 10


def test_t30_expected_revision_prevents_silent_overwrite(scene):
    review = scene[4]
    body = {"expected_revision": str(review.content_revision), "comentario": "First edit"}
    assert api(scene[0]).patch(f"{URL}{review.pk}/", body, format="json").status_code == 200
    assert (
        api(scene[0]).patch(f"{URL}{review.pk}/", {**body, "comentario": "Stale edit"}, format="json").status_code
        == 409
    )
    review.refresh_from_db()
    assert review.comentario == "First edit"


def test_optional_observation_details_stay_with_partial_answer_and_its_revision(scene):
    owner, _, _, local, _ = scene
    delete_existing(scene)
    body = review_body(
        local,
        answers={"rampa_acesso": "yes"},
        answer_details={"rampa_acesso": {"note": "Entrance I observed", "observed_on": "2026-10-01"}},
    )
    response = api(owner).post(URL, body, format="json")
    assert response.status_code == 201, response.data
    root = ResourceEvidence.objects.get(review_id=response.data["id"])
    assert root.current_revision.note == "Entrance I observed"
    assert root.current_revision.observed_on.isoformat() == "2026-10-01"
    assert (
        api(owner)
        .patch(f"{URL}{response.data['id']}/", {"answers": {"rampa_acesso": None}}, format="json")
        .data["answer_details"]
        == {}
    )


def test_t13_old_report_is_unavailable_after_new_statement_without_punishing_new_content(scene):
    from evidencias.models import ContentReport
    from evidencias.moderation import decide
    from evidencias.exceptions import RevisionConflict

    owner, reader, moderator, local, review = scene
    review.questionnaire_version, review.answers = 2, {"rampa_acesso": "yes"}
    review.save()
    root = ResourceEvidence.objects.get(review=review, resource="rampa_acesso")
    report = api(reader).post(
        "/api/denuncias/",
        {
            "target_kind": "evidence",
            "evidence_id": str(root.pk),
            "revision": str(root.current_revision_id),
            "reason": "incorrect",
        },
        format="json",
    )
    assert report.status_code == 201
    case = ContentReport.objects.get(pk=report.data["protocol"])
    result = api(owner).post(OBS, statement(local, "rampa_acesso", value="no"), format="json")
    args = dict(
        expected_version=case.version,
        expected_target_revision=case.target_revision,
        operation_id=uuid.uuid4(),
        reason="Synthetic decision for superseded statement",
    )
    with pytest.raises(RevisionConflict):
        decide(moderator.pk, case.pk, action="invalidate", **args)
    decide(moderator.pk, case.pk, action="unavailable", **args)
    newest = ResourceEvidence.objects.get(pk=result.data["evidence_id"])
    assert newest.current_revision.is_valid and not newest.superseded


@pytest.mark.parametrize("length,status", [(9, 400), (10, 201), (500, 201), (501, 400)])
def test_t17_photo_description_normalizes_whitespace_then_checks_code_points(scene, length, status):
    from midia.test_images import upload_file
    from midia.models import ReviewPhoto

    response = api(scene[0]).post(
        "/api/midia/fotos/enviar/",
        {
            "operation_id": str(uuid.uuid4()),
            "review_id": scene[4].pk,
            "review_revision": str(scene[4].content_revision),
            "description": "  " + "a" * length + "  ",
            "file": upload_file(),
        },
        format="multipart",
    )
    assert response.status_code == status, response.data
    assert ReviewPhoto.objects.count() == (1 if status == 201 else 0)
    if status == 201:
        assert ReviewPhoto.objects.get().current_revision.description == "a" * length
