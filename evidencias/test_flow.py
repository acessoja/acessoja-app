"""C38–C41 contracts with synthetic identities only. Real concurrency is separate."""

from datetime import timedelta
import json
from unittest.mock import patch
import uuid

from django.contrib.auth.models import Permission
from django.core.cache import cache
from django.test import Client
from django.utils import timezone
import pytest
from rest_framework.authtoken.models import Token
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.test import APIClient

from contribuicoes.models import ContributionPointEvent, PointActivity
from locais.models import Local, RouteHistorySession, VisitaRecente
from modal_avaliacao.models import ModalAvaliacao
from modal_avaliacao.questionnaire import QUESTION_IDS
from usuarios.deletion_journal import journal_identity
from usuarios.models import Usuario
from .exceptions import RevisionConflict
from .models import (
    ContentReport,
    EvidenceConfirmation,
    EvidenceRevision,
    ModerationDecision,
    ResourceEvidence,
    ReviewRevision,
)
from .moderation import decide
from .projection import freshness

pytestmark = pytest.mark.django_db
PASSWORD = "Synthetic-quality!53829"


def client_for(user):
    token, _ = Token.objects.get_or_create(user=user)
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")
    return client


@pytest.fixture
def scenario(settings, tmp_path):
    cache.clear()
    settings.DELETION_JOURNAL_DIR = tmp_path / "journal"
    journal_identity(initialize=True)
    a = Usuario.objects.create_user("synthetic-author", email="author@example.test", password=PASSWORD)
    b = Usuario.objects.create_user("synthetic-reader", email="reader@example.test", password=PASSWORD)
    mod = Usuario.objects.create_user(
        "synthetic-mod", email="mod@example.test", password=PASSWORD, is_staff=True
    )
    permission = Permission.objects.get(codename="moderate_content", content_type__app_label="evidencias")
    mod.user_permissions.add(permission)
    local = Local.objects.create(nome="Synthetic shared place", endereco="Synthetic address", distancia=0)
    review = ModalAvaliacao.objects.create(
        user=a,
        local=local,
        verified_author=True,
        estrelas=4,
        comentario="Synthetic experience",
        questionnaire_version=2,
        answers={**dict.fromkeys(QUESTION_IDS, "unknown"), "rampa_acesso": "yes"},
        answer_dates={key: timezone.now().isoformat() for key in QUESTION_IDS},
    )
    root = ResourceEvidence.objects.get(review=review, resource="rampa_acesso")
    yield a, b, mod, local, review, root
    cache.clear()


def report_review(user, review):
    response = client_for(user).post(
        "/api/denuncias/",
        {
            "target_kind": "review",
            "review_id": review.pk,
            "revision": str(review.content_revision),
            "reason": "incorrect",
            "description": "Synthetic context",
        },
        format="json",
    )
    assert response.status_code in {200, 201}, response.data
    return ContentReport.objects.get(pk=response.data["protocol"])


def decision(mod, case, action="invalidate", **overrides):
    return decide(
        mod.pk,
        case.pk,
        **{
            "action": action,
            "reason": "Synthetic moderation justification",
            "expected_version": case.version,
            "expected_target_revision": case.target_revision,
            "operation_id": uuid.uuid4(),
            **overrides,
        },
    )


def test_c38_02_public_metadata_sources_dates_and_no_author_identity(scenario):
    a, b, mod, local, review, root = scenario
    response = client_for(b).get("/api/evidencias/", {"local_id": local.pk, "resource": "rampa_acesso"})
    assert response.status_code == 200, response.data
    item = response.data["results"][0]
    assert item["source"] == "user" and item["observed_at"] is None and item["confirmed_at"] is None
    assert item["received_at"] and item["revision"] == str(root.current_revision_id)
    text = json.dumps(response.data, default=str)
    assert a.email not in text and a.nome not in text and "owner_id" not in text and "reporter" not in text
    payload = APIClient().get(f"/api/locais/{local.pk}/").json()
    assert payload["accessibility"]["rampa_acesso"]["state"] == "presence_reported"


def test_c38_03_editing_one_resource_preserves_other_revisions_and_confirmation(scenario):
    a, b, _, _, review, root = scenario
    toilet = ResourceEvidence.objects.get(review=review, resource="banheiro_acessivel")
    previous_date = toilet.current_revision.received_at
    old_review_revision = review.content_revision
    response = client_for(a).patch(
        f"/api/avaliacoes/modal-avaliacoes/{review.pk}/",
        {"answers": {"rampa_acesso": "no"}, "expected_revision": str(old_review_revision)},
        format="json",
    )
    assert response.status_code == 200, response.data
    review.refresh_from_db()
    root.refresh_from_db()
    toilet.refresh_from_db()
    assert review.content_revision != old_review_revision
    assert ReviewRevision.objects.filter(review=review).count() == 2
    assert root.revisions.count() == 2 and toilet.revisions.count() == 1
    assert toilet.current_revision.received_at == previous_date
    assert root.current_revision.state == "absence_reported"
    assert client_for(b).get(f"/api/evidencias/{root.pk}/historico/").status_code == 404
    assert client_for(a).get(f"/api/evidencias/{root.pk}/historico/").data["count"] == 2


def test_c38_04_confirmation_is_repeatable_and_changes_no_votes_points_or_visits(scenario):
    a, b, _, local, review, root = scenario
    before = list(PointActivity.objects.values_list("pk", "delta"))
    client = client_for(b)
    path = f"/api/evidencias/{root.pk}/confirmar/"
    body = {"revision": str(root.current_revision_id)}
    first, repeated = client.post(path, body, format="json"), client.post(path, body, format="json")
    assert first.status_code == repeated.status_code == 200
    assert first.data["confirmed_at"] == repeated.data["confirmed_at"] and repeated.data["repeated"]
    assert EvidenceConfirmation.objects.count() == 1
    assert before == list(PointActivity.objects.values_list("pk", "delta"))
    assert (
        ModalAvaliacao.objects.count() == 1
        and not VisitaRecente.objects.exists()
        and not RouteHistorySession.objects.exists()
    )
    summary = client.get("/api/avaliacoes/modal-avaliacoes/recursos/", {"local_id": local.pk}).data
    assert next(item for item in summary["features"] if item["id"] == "rampa_acesso")["counts"]["yes"] == 1


def test_c38_05_stale_revision_and_unknown_assertion_are_rejected(scenario):
    a, b, _, _, review, root = scenario
    old = root.current_revision_id
    review.answers = {**review.answers, "rampa_acesso": "no"}
    review.save()
    assert (
        client_for(b)
        .post(f"/api/evidencias/{root.pk}/confirmar/", {"revision": str(old)}, format="json")
        .status_code
        == 409
    )
    unknown = ResourceEvidence.objects.get(review=review, resource="banheiro_acessivel")
    assert (
        client_for(b)
        .post(
            f"/api/evidencias/{unknown.pk}/confirmar/",
            {"revision": str(unknown.current_revision_id)},
            format="json",
        )
        .status_code
        == 400
    )
    assert not EvidenceConfirmation.objects.exists()


@pytest.mark.parametrize("bad", ["2099-01-01T10:00:00Z", "2020-01-01T10:00:00", "not-a-date"])
def test_c38_06_invalid_observation_time_is_not_accepted(scenario, bad):
    _, b, _, _, _, root = scenario
    response = client_for(b).post(
        f"/api/evidencias/{root.pk}/confirmar/",
        {"revision": str(root.current_revision_id), "observed_at": bad},
        format="json",
    )
    assert response.status_code == 400 and not EvidenceConfirmation.objects.exists()


def test_c38_06_temporal_boundary_and_unknown_date_are_explicit(scenario, settings):
    _, _, _, _, _, root = scenario
    now = timezone.now()
    revision = root.current_revision
    settings.ACCESSIBILITY_FRESHNESS_DAYS = 180
    revision.received_at = now - timedelta(days=180)
    assert freshness(revision, now=now)["state"] == "recent_record"
    assert freshness(revision, now=now + timedelta(seconds=1))["state"] == "no_recent_confirmation"
    revision.received_at = None
    assert freshness(revision, now=now)["state"] == "date_unknown"
    assert freshness(revision, confirmed_at=now, now=now)["state"] == "recent_confirmation"


def test_c38_07_change_is_own_assertion_keeps_disagreement_without_touching_stars(scenario):
    a, b, _, local, review, root = scenario
    response = client_for(b).post(
        f"/api/evidencias/{root.pk}/alterar/",
        {
            "revision": str(root.current_revision_id),
            "value": "no",
            "observed_on": timezone.now().date().isoformat(),
        },
        format="json",
    )
    assert response.status_code == 200, response.data
    review.refresh_from_db()
    assert review.estrelas == 4 and review.answers["rampa_acesso"] == "yes"
    assert not ContributionPointEvent.objects.filter(user=b).exists()
    public = APIClient().get(f"/api/locais/{local.pk}/").data
    assert public["accessibility"]["rampa_acesso"]["state"] == "divergent"
    repeated = client_for(b).post(
        f"/api/evidencias/{root.pk}/alterar/",
        {
            "revision": str(root.current_revision_id),
            "value": "no",
            "observed_on": timezone.now().date().isoformat(),
        },
        format="json",
    )
    assert repeated.status_code == 200 and EvidenceRevision.objects.filter(evidence__owner=b).count() == 1


def test_c38_08_private_invalid_and_archived_do_not_influence_public_or_history(scenario):
    a, b, _, local, review, _ = scenario
    a.mostrar_avaliacoes = False
    a.save()
    for client in [APIClient(), client_for(a), client_for(b)]:
        public = client.get(f"/api/locais/{local.pk}/").data
        assert (
            public["quantidade_avaliacoes"] == 0
            and public["accessibility"]["rampa_acesso"]["state"] == "unknown"
        )
    a.mostrar_avaliacoes = True
    a.save()
    review.is_current = False
    review.save(update_fields=["is_current"])
    assert APIClient().get("/api/avaliacoes/modal-avaliacoes/", {"include_history": "1"}).data == []
    assert len(client_for(a).get("/api/avaliacoes/modal-avaliacoes/", {"include_history": "1"}).data) == 1


def test_c40_report_is_private_idempotent_and_has_no_automatic_penalty(scenario):
    a, b, _, local, review, _ = scenario
    points = list(PointActivity.objects.values_list("pk", "delta"))
    case = report_review(b, review)
    again = client_for(b).post(
        "/api/denuncias/",
        {
            "target_kind": "review",
            "review_id": review.pk,
            "revision": str(review.content_revision),
            "reason": "outdated",
        },
        format="json",
    )
    assert again.status_code == 200 and again.data["protocol"] == str(case.pk) and again.data["repeated"]
    assert ContentReport.objects.count() == 1 and case.state == "pending"
    assert client_for(a).get(f"/api/denuncias/{case.pk}/").status_code == 404
    assert APIClient().post("/api/denuncias/", {}, format="json").status_code == 401
    assert client_for(b).get(f"/api/denuncias/{case.pk}/").status_code == 200
    review.refresh_from_db()
    assert review.is_valid and points == list(PointActivity.objects.values_list("pk", "delta"))
    assert "reporter" not in again.data and "snapshot" not in again.data
    assert (
        client_for(a)
        .post(
            "/api/denuncias/",
            {
                "target_kind": "review",
                "review_id": review.pk,
                "revision": str(review.content_revision),
                "reason": "incorrect",
            },
            format="json",
        )
        .status_code
        == 400
    )


def test_c40_resource_report_validates_target_and_protects_authority(scenario):
    _, b, _, _, _, root = scenario
    body = {
        "target_kind": "evidence",
        "evidence_id": str(root.pk),
        "revision": str(root.current_revision_id),
        "reason": "incorrect",
    }
    client = client_for(b)
    assert client.post("/api/denuncias/", body, format="json").status_code == 201
    for extra in [{"reporter": b.pk}, {"state": "closed"}, {"moderator": b.pk}, {"review_id": 999}]:
        assert client.post("/api/denuncias/", {**body, **extra}, format="json").status_code == 400
    assert client.post("/api/denuncias/", {**body, "reason": "other"}, format="json").status_code == 400
    assert (
        client.post("/api/denuncias/", {**body, "description": "x" * 1001}, format="json").status_code == 400
    )


def test_c41_permission_is_specific_and_admin_does_not_expose_queue_to_staff_alone(scenario):
    a, b, mod, _, review, _ = scenario
    case = report_review(b, review)
    b.is_staff = True
    b.save(update_fields=["is_staff"])
    with pytest.raises(PermissionDenied):
        decision(b, case)
    browser = Client()
    browser.force_login(b, backend="django.contrib.auth.backends.ModelBackend")
    assert browser.get("/admin/evidencias/contentreport/").status_code == 403
    browser.force_login(mod, backend="django.contrib.auth.backends.ModelBackend")
    assert browser.get("/admin/evidencias/contentreport/").status_code == 200


def test_c41_03_invalidation_reconciles_points_and_is_idempotent(scenario):
    a, b, mod, local, review, _ = scenario
    case = report_review(b, review)
    operation = uuid.uuid4()
    first = decision(mod, case, operation_id=operation)
    activities = PointActivity.objects.count()
    again = decision(mod, case, operation_id=operation)
    assert first.pk == again.pk and PointActivity.objects.count() == activities
    review.refresh_from_db()
    case.refresh_from_db()
    assert not review.is_valid and case.state == "closed"
    assert not ContributionPointEvent.objects.filter(user=a, active=True).exists()
    assert APIClient().get(f"/api/locais/{local.pk}/").data["quantidade_avaliacoes"] == 0
    with pytest.raises(RevisionConflict):
        decision(mod, case, action="keep", operation_id=operation)


def test_c41_resource_invalidation_does_not_penalize_rating_comment_or_other_resources(scenario):
    a, b, mod, local, review, root = scenario
    response = client_for(b).post(
        "/api/denuncias/",
        {
            "target_kind": "evidence",
            "evidence_id": str(root.pk),
            "revision": str(root.current_revision_id),
            "reason": "incorrect",
        },
        format="json",
    )
    case = ContentReport.objects.get(pk=response.data["protocol"])
    points = list(PointActivity.objects.values_list("pk", "delta"))
    decision(mod, case)
    review.refresh_from_db()
    assert review.is_valid and review.estrelas == 4 and review.comentario == "Synthetic experience"
    assert points == list(PointActivity.objects.values_list("pk", "delta"))
    assert (
        APIClient().get(f"/api/locais/{local.pk}/").data["accessibility"]["rampa_acesso"]["state"]
        == "unknown"
    )
    public_review = client_for(b).get(f"/api/avaliacoes/modal-avaliacoes/{review.pk}/").data
    assert "rampa_acesso" not in public_review["answers"]
    assert (
        "rampa_acesso" in client_for(a).get(f"/api/avaliacoes/modal-avaliacoes/{review.pk}/").data["answers"]
    )


def test_c41_old_revision_and_removed_target_cannot_punish_new_content(scenario):
    _, b, mod, _, review, _ = scenario
    case = report_review(b, review)
    review.comentario = "New synthetic text"
    review.save()
    with pytest.raises(RevisionConflict):
        decision(mod, case)
    decision(mod, case, action="unavailable")
    review.refresh_from_db()
    assert review.is_valid and review.comentario == "New synthetic text"


def test_c41_rollback_never_publishes_an_uncommitted_hint(scenario):
    _, b, mod, _, review, _ = scenario
    case = report_review(b, review)
    points = list(PointActivity.objects.values_list("pk", "delta"))
    with patch(
        "evidencias.moderation.ModerationDecision.objects.create",
        side_effect=RuntimeError("synthetic failure"),
    ):
        with pytest.raises(RuntimeError):
            decision(mod, case)
    review.refresh_from_db()
    case.refresh_from_db()
    assert review.is_valid and case.state == "pending" and not ModerationDecision.objects.exists()
    assert points == list(PointActivity.objects.values_list("pk", "delta"))


def test_c41_request_revision_uses_safe_messages_without_reporter_or_internal_reason(scenario):
    a, b, mod, _, review, _ = scenario
    case = report_review(b, review)
    with pytest.raises(ValidationError):
        decision(mod, case, action="request_review", author_message=b.email)
    decision(
        mod,
        case,
        action="request_review",
        author_message="resource_details",
        reason="PRIVATE_INTERNAL_REASON",
    )
    response = client_for(a).get("/api/revisoes-solicitadas/")
    assert response.status_code == 200 and response.data["count"] == 1
    text = json.dumps(response.data, default=str)
    assert (
        b.email not in text
        and b.nome not in text
        and "PRIVATE_INTERNAL_REASON" not in text
        and str(case.pk) not in text
    )


def test_c40_c41_account_deletion_anonymizes_trail_and_own_export_is_scoped(scenario):
    a, b, mod, _, review, root = scenario
    case = report_review(b, review)
    decision(mod, case, action="request_review", author_message="overall_review")
    exported = client_for(b).post(
        "/api/usuarios/me/data-export/", {"current_password": PASSWORD}, format="json"
    )
    categories = json.loads(exported.content)["categories"]
    assert categories["submitted_reports"][0]["protocol"] == str(case.pk)
    assert (
        a.email not in exported.content.decode() and "Synthetic experience" not in exported.content.decode()
    )
    removed = client_for(a).post(
        "/api/usuarios/me/delete-account/", {"current_password": PASSWORD, "confirm": True}, format="json"
    )
    assert removed.status_code == 204, removed.data
    case.refresh_from_db()
    root.refresh_from_db()
    assert root.withdrawn and root.owner_id is None and root.local_id is None
    assert case.review_revision.payload == {} and case.description == ""
    assert ModerationDecision.objects.filter(report=case).exists()
    assert client_for(b).get(f"/api/denuncias/{case.pk}/").data["target_status"] == "unavailable"
