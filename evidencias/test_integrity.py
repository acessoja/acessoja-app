"""Synthetic temporal, operational and moderation regressions for Cards 38–41."""

from datetime import date, timedelta
from io import StringIO
from types import SimpleNamespace
from unittest.mock import patch
import uuid

from django.contrib.auth.models import Group, Permission
from django.core.cache import cache
from django.core.management import call_command
from django.db import connection, transaction
from django.test import Client
from django.test.utils import CaptureQueriesContext
from django.urls import reverse
from django.utils import timezone
import pytest
from rest_framework.exceptions import ValidationError
from rest_framework.test import APIClient

from locais.models import Local
from usuarios.models import Usuario
from . import test_flow
from .admin import DecisionForm
from .capture import sync_remote_places
from .exceptions import RevisionConflict
from .models import (
    ContentReport,
    EvidenceConfirmation,
    EvidenceRevision,
    ModerationDecision,
    ResourceEvidence,
)
from .moderation import publication_changed
from .projection import freshness
from .services import target_status

pytestmark = pytest.mark.django_db
scenario = test_flow.scenario
client_for, report_review, decision = test_flow.client_for, test_flow.report_review, test_flow.decision


def remote(state="yes"):
    return {"external_id": "osm:node:987654", "accessibility_data": {"toilets:wheelchair": state}}


def test_day_granularity_does_not_invent_a_time(settings):
    settings.ACCESSIBILITY_FRESHNESS_DAYS = 180
    now = timezone.now()
    row = SimpleNamespace(observed_at=None, observed_on=now.date() - timedelta(days=180), received_at=None)
    value = freshness(row, now=now)
    assert value["state"] == "recent_observation" and value["reference_kind"] == "observed_on"
    assert value["reference_at"] == row.observed_on.isoformat() and "T" not in value["reference_at"]
    row.observed_on -= timedelta(days=1)
    assert freshness(row, now=now)["state"] == "no_recent_confirmation"
    row.observed_on = date(2999, 1, 1)
    assert freshness(row, now=now)["state"] == "date_unknown"


def test_osm_same_value_and_changed_name_do_not_renew_resource_or_moderation(scenario):
    _, reader, mod, _, _, _ = scenario
    sync_remote_places([remote()])
    root = ResourceEvidence.objects.get(external_id="osm:node:987654")
    before = root.current_revision_id
    body = {
        "target_kind": "evidence",
        "evidence_id": str(root.pk),
        "revision": str(before),
        "reason": "incorrect",
    }
    result = client_for(reader).post("/api/denuncias/", body, format="json")
    case = ContentReport.objects.get(pk=result.data["protocol"])
    decision(mod, case)
    changed_name = {**remote(), "nome": "A new name", "snapshot_at": timezone.now().isoformat()}
    sync_remote_places([changed_name])
    root.refresh_from_db()
    assert root.current_revision_id == before and not root.current_revision.is_valid
    assert root.revisions.count() == 1
    assert APIClient().get(f"/api/evidencias/{root.pk}/").status_code == 404
    assert Local.objects.filter(osm_id="osm:node:987654").count() == 0
    sync_remote_places([remote("no")])
    root.refresh_from_db()
    assert root.current_revision_id != before and root.current_revision.is_valid
    assert root.current_revision.observed_at is None and root.current_revision.observed_on is None
    sync_remote_places([remote()])
    root.refresh_from_db()
    assert (
        not root.current_revision.is_valid
    )  # returning to an invalidated fingerprint cannot bypass restriction


def test_osm_disappearance_withdraws_and_reappearance_does_not_refresh_confirmation(scenario):
    sync_remote_places([remote()])
    root = ResourceEvidence.objects.get(external_id="osm:node:987654")
    reader = scenario[1]
    client_for(reader).post(
        f"/api/evidencias/{root.pk}/confirmar/", {"revision": str(root.current_revision_id)}, format="json"
    )
    confirmed = EvidenceConfirmation.objects.get(revision_id=root.current_revision_id).confirmed_at
    before = root.current_revision_id
    sync_remote_places([{"external_id": root.external_id, "accessibility_data": {}}])
    root.refresh_from_db()
    assert root.withdrawn
    sync_remote_places([remote()])
    root.refresh_from_db()
    assert root.current_revision_id == before and root.revisions.count() == 1
    assert EvidenceConfirmation.objects.get(revision_id=before).confirmed_at == confirmed


def test_changed_resource_gets_new_receipt_without_renewing_unrelated_resource(scenario):
    author, _, _, _, review, root = scenario
    unrelated = ResourceEvidence.objects.get(review=review, resource="banheiro_acessivel")
    old = timezone.now() - timedelta(days=365)
    EvidenceRevision.objects.filter(evidence__review=review).update(received_at=old)
    review.answers = {**review.answers, "rampa_acesso": "no"}
    review.save()
    root.refresh_from_db()
    unrelated.refresh_from_db()
    assert root.current_revision.received_at > old + timedelta(days=300)
    assert unrelated.current_revision.received_at == old
    assert root.owner_id == author.pk


def test_different_reporters_share_measure_with_one_effect_and_each_audit(scenario):
    _, reader, mod, _, review, _ = scenario
    other = Usuario.objects.create_user(
        "synthetic-other", email="other@example.test", password="synthetic-pass"
    )
    first, second = report_review(reader, review), report_review(other, review)
    result = decision(mod, first)
    first.refresh_from_db()
    second.refresh_from_db()
    assert first.state == second.state == "closed"
    assert ModerationDecision.objects.filter(report__in=[first, second]).count() == 2
    assert ModerationDecision.objects.filter(effect_applied=True).count() == 1
    assert second.decisions.get().operation_id == result.operation_id
    with pytest.raises(RevisionConflict):
        decision(mod, second)
    # A closed same-version report is still idempotent, even if the reason changes.
    review.refresh_from_db()
    assert not review.is_valid


def test_report_retry_after_keep_reuses_protocol_and_old_revision_never_gets_new_case(scenario):
    _, reader, mod, _, review, _ = scenario
    case = report_review(reader, review)
    decision(mod, case, action="keep")
    response = client_for(reader).post(
        "/api/denuncias/",
        {
            "target_kind": "review",
            "review_id": review.pk,
            "revision": str(review.content_revision),
            "reason": "outdated",
        },
        format="json",
    )
    assert (
        response.status_code == 200
        and response.data["repeated"]
        and response.data["protocol"] == str(case.pk)
    )
    review.comentario = "Genuinely edited synthetic text"
    review.save()
    assert report_review(reader, review).pk != case.pk


def test_throttling_fail_closed_and_validation_never_create_fake_receipt(scenario, settings):
    _, reader, _, _, review, _ = scenario
    settings.SECURITY_RATES = {**settings.SECURITY_RATES, "report_create": (1, 1, 3600)}
    cache.clear()
    body = {
        "target_kind": "review",
        "review_id": review.pk,
        "revision": str(review.content_revision),
        "reason": "incorrect",
    }
    first = client_for(reader).post("/api/denuncias/", body, format="json")
    second = client_for(reader).post("/api/denuncias/", body, format="json")
    assert first.status_code == 201 and second.status_code == 429 and "protocol" not in second.data
    assert second["Retry-After"]
    cache.clear()
    with patch("usuarios.security_throttles.cache.add", side_effect=RuntimeError("synthetic outage")):
        result = client_for(reader).post("/api/denuncias/", body, format="json")
    assert result.status_code == 503 and ContentReport.objects.count() == 1


def test_permission_grant_and_revoke_is_explicit_and_staff_is_not_authority(scenario):
    author = scenario[0]
    output = StringIO()
    call_command("grant_content_moderator", user=author.nome, grant=True, stdout=output)
    author.refresh_from_db()
    assert author.has_perm("evidencias.moderate_content") and not author.is_staff
    call_command("grant_content_moderator", user=author.nome, revoke=True, stdout=output)
    author = Usuario.objects.get(pk=author.pk)
    assert not author.has_perm("evidencias.moderate_content")
    assert Group.objects.filter(name="Moderadores AcessoJá").exists()
    assert Permission.objects.filter(codename="moderate_content").exists()


def test_admin_uses_same_decision_path_and_rejects_direct_validity_edit(scenario):
    _, reader, mod, _, review, _ = scenario
    case = report_review(reader, review)
    client = Client()
    client.force_login(mod)
    url = reverse("admin:evidence-report-decision", args=[case.pk])
    page = client.get(url)
    assert page.status_code == 200 and reader.email.encode() not in page.content
    response = client.post(
        url,
        {
            "action": "keep",
            "reason": "Synthetic Admin decision",
            "expected_version": case.version,
            "expected_target_revision": str(case.target_revision),
            "operation_id": str(uuid.uuid4()),
        },
    )
    assert response.status_code == 302
    case.refresh_from_db()
    assert case.state == "closed" and case.decisions.count() == 1
    assert client.post(reverse("admin:evidencias_contentreport_delete", args=[case.pk])).status_code == 403
    from modal_avaliacao.admin import ReviewAdmin
    from django.contrib import admin

    request = SimpleNamespace(user=mod)
    configuration = ReviewAdmin(review.__class__, admin.site)
    assert "is_valid" in configuration.get_readonly_fields(request, review)
    assert not configuration.has_delete_permission(request, review)


def test_decision_form_rejects_untrusted_author_message_and_short_reason():
    form = DecisionForm(
        {
            "action": "request_review",
            "reason": "short",
            "author_message": "person@example.test",
            "expected_version": 1,
            "expected_target_revision": uuid.uuid4(),
            "operation_id": uuid.uuid4(),
        }
    )
    assert not form.is_valid() and "reason" in form.errors and "author_message" in form.errors


def test_on_commit_hint_fails_safely_and_rollback_registers_no_effect(
    scenario, django_capture_on_commit_callbacks
):
    _, reader, mod, _, review, _ = scenario
    case = report_review(reader, review)
    with django_capture_on_commit_callbacks(execute=True) as callbacks:
        decision(mod, case, action="keep")
    assert len(callbacks) == 1
    with patch("evidencias.moderation.cache.add", side_effect=RuntimeError("synthetic cache outage")):
        publication_changed()
    with django_capture_on_commit_callbacks(execute=True) as callbacks:
        with pytest.raises(RuntimeError):
            with transaction.atomic():
                transaction.on_commit(publication_changed)
                raise RuntimeError("synthetic rollback")
    assert callbacks == []


def test_closed_report_retention_minimizes_then_removes_audit(scenario):
    _, reader, mod, _, review, _ = scenario
    case = report_review(reader, review)
    decision(mod, case, action="keep")
    ContentReport.objects.filter(pk=case.pk).update(updated_at=timezone.now() - timedelta(days=40))
    call_command("prune_evidence_state", stdout=StringIO())
    case.refresh_from_db()
    assert case.description == "" and "expurgada" in case.decisions.get().reason
    ContentReport.objects.filter(pk=case.pk).update(updated_at=timezone.now() - timedelta(days=181))
    call_command("prune_evidence_state", stdout=StringIO())
    assert not ContentReport.objects.filter(pk=case.pk).exists()
    assert not ModerationDecision.objects.exists()


def test_closed_evidence_case_reports_unavailable_after_invalidation(scenario):
    _, reader, mod, _, _, root = scenario
    result = client_for(reader).post(
        "/api/denuncias/",
        {
            "target_kind": "evidence",
            "evidence_id": str(root.pk),
            "revision": str(root.current_revision_id),
            "reason": "incorrect",
        },
        format="json",
    )
    case = ContentReport.objects.get(pk=result.data["protocol"])
    decision(mod, case)
    case = ContentReport.objects.select_related("evidence__current_revision").get(pk=case.pk)
    assert target_status(case) == "unavailable"


def test_public_pagination_and_query_count_do_not_reveal_private_rows(scenario):
    _, reader, _, local, _, _ = scenario
    with CaptureQueriesContext(connection) as queries:
        result = APIClient().get("/api/evidencias/", {"local_id": local.pk, "resource": "rampa_acesso"})
    assert result.data["count"] == 1 and len(queries) <= 6
    assert client_for(reader).get("/api/denuncias/", {"reporter": scenario[0].pk}).status_code == 400
    with pytest.raises(ValidationError):
        decision(scenario[2], report_review(reader, scenario[4]), action="unavailable")


@pytest.mark.django_db(transaction=True)
def test_backfill_distinguishes_reviews_and_preserves_unknown_observation_dates():
    from django.db.migrations.executor import MigrationExecutor

    executor = MigrationExecutor(connection)
    latest = executor.loader.graph.leaf_nodes()
    before = [
        (
            app,
            (
                "0006_versioned_questionnaire"
                if app == "modal_avaliacao"
                else "0007_usuario_groups_usuario_user_permissions" if app == "usuarios" else name
            ),
        )
        for app, name in latest
        if app not in {"evidencias", "midia"}
    ]
    try:
        executor.migrate(before + [("evidencias", None), ("midia", None)])
        apps = executor.loader.project_state(before).apps
        User = apps.get_model("usuarios", "Usuario")
        Place = apps.get_model("locais", "Local")
        Review = apps.get_model("modal_avaliacao", "ModalAvaliacao")
        author = User.objects.create(
            nome="migration-synthetic",
            email="migration@example.test",
            password="irrelevant",
            data_criacao=timezone.now(),
        )
        first = Place.objects.create(
            nome="Legacy one", endereco="Synthetic street", distancia=0, rampa_acesso=True
        )
        second = Place.objects.create(nome="Legacy two", endereco="Synthetic street", distancia=0)
        known = (timezone.now() - timedelta(days=200)).isoformat()
        one = Review.objects.create(
            user_id=author.pk,
            local_id=first.pk,
            estrelas=4,
            questionnaire_version=2,
            answers={"rampa_acesso": "yes"},
            answer_dates={"rampa_acesso": known},
        )
        two = Review.objects.create(
            user_id=author.pk, local_id=second.pk, estrelas=2, comentario="Preserve original"
        )
        MigrationExecutor(connection).migrate(latest)
        from modal_avaliacao.models import ModalAvaliacao

        migrated = list(ModalAvaliacao.objects.filter(pk__in=[one.pk, two.pk]))
        assert len({row.content_revision for row in migrated}) == 2
        root = ResourceEvidence.objects.get(review_id=one.pk)
        assert root.current_revision.observed_at is None and root.current_revision.observed_on is None
        assert root.current_revision.received_at.isoformat() == known
        assert not EvidenceConfirmation.objects.exists()
        assert not ResourceEvidence.objects.filter(local_id=first.pk, kind="registration").exists()
        assert ModalAvaliacao.objects.get(pk=two.pk).comentario == "Preserve original"
    finally:
        MigrationExecutor(connection).migrate(latest)


def test_osm_suppression_applies_to_equivalent_assertion_in_other_channel(scenario):
    from .capture import capture_batch

    sync_remote_places([remote()])
    original = ResourceEvidence.objects.get(external_id="osm:node:987654")
    specification = {
        "key": "catalog:osm:node:987654:banheiro_acessivel",
        "resource": original.resource,
        "kind": "osm",
        "source": "openstreetmap",
        "external_id": original.external_id,
        "state": original.current_revision.state,
        "received_at": timezone.now(),
    }
    other = capture_batch([specification])[0]
    _, reader, mod, _, _, _ = scenario
    result = client_for(reader).post(
        "/api/denuncias/",
        {
            "target_kind": "evidence",
            "evidence_id": str(original.pk),
            "revision": str(original.current_revision_id),
            "reason": "incorrect",
        },
        format="json",
    )
    decision(mod, ContentReport.objects.get(pk=result.data["protocol"]))
    other.refresh_from_db()
    assert not other.current_revision.is_valid
    newer_channel = capture_batch(
        [{**specification, "key": "new-channel:osm:node:987654:banheiro_acessivel"}]
    )[0]
    assert not newer_channel.current_revision.is_valid


def test_catalog_reimport_does_not_restore_moderation_or_touch_community(scenario, tmp_path):
    from locais.test_catalog import boundary_file, imported, pbf

    source = {
        "path": pbf(tmp_path / "synthetic.pbf"),
        "boundary_path": boundary_file(tmp_path / "bounds.json"),
    }
    imported(source)
    root = ResourceEvidence.objects.get(key="catalog:osm:node:1:banheiro_acessivel")
    _, reader, mod, _, review, _ = scenario
    result = client_for(reader).post(
        "/api/denuncias/",
        {
            "target_kind": "evidence",
            "evidence_id": str(root.pk),
            "revision": str(root.current_revision_id),
            "reason": "incorrect",
        },
        format="json",
    )
    decision(mod, ContentReport.objects.get(pk=result.data["protocol"]))
    old = root.current_revision_id
    assert imported(source)["result"] == "reused"
    newer = {
        **source,
        "path": pbf(
            tmp_path / "new-name.pbf", stamp="2026-01-02T00:00:00Z", names={1: "Renamed", 2: "Farmácia"}
        ),
    }
    imported(newer)
    root.refresh_from_db()
    review.refresh_from_db()
    assert root.current_revision_id == old and not root.current_revision.is_valid and review.is_valid
    response = APIClient().get("/api/locais/catalogo/", {"recursos": "banheiro_acessivel"})
    assert "osm:node:1" not in [row["external_id"] for row in response.data["results"]]


def test_visitor_can_request_login_to_report_supported_osm_fact(scenario):
    sync_remote_places([remote()])
    root = ResourceEvidence.objects.get(external_id="osm:node:987654")
    response = APIClient().get(f"/api/evidencias/{root.pk}/")
    assert response.status_code == 200 and response.data["can_report"]
    assert APIClient().post("/api/denuncias/", {"target_kind": "evidence"}, format="json").status_code == 401


def test_removed_registered_place_closes_without_exposing_or_mutating_missing_target(scenario):
    from .capture import capture_registration
    from .services import reports_related

    _, reader, mod, _, _, _ = scenario
    place = Local.objects.create(
        nome="Synthetic removable place",
        endereco="Synthetic",
        distancia=0,
        accessibility_information={
            "rampa_acesso": {
                "state": "presence_reported",
                "note": "",
                "source": "acessoja_registration",
                "received_at": timezone.now().isoformat(),
            }
        },
    )
    capture_registration(place)
    root = ResourceEvidence.objects.get(local=place, resource="rampa_acesso")
    response = client_for(reader).post(
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
    place.delete()
    assert target_status(reports_related(ContentReport.objects.all()).get(pk=case.pk)) == "unavailable"
    assert APIClient().get(f"/api/evidencias/{root.pk}/").status_code == 404
    decision(mod, case, action="unavailable")
    case.refresh_from_db()
    assert case.outcome == "unavailable" and not case.decisions.get().effect_applied


def test_moderation_reloads_case_after_owner_lock_changes_target_key(scenario):
    """A privacy cleanup may change the case key while moderation waits for owner lock."""
    _, reader, mod, _, review, _ = scenario
    case = report_review(reader, review)
    from .moderation import lock_users as actual_lock_users

    def anonymize_during_lock(*ids):
        locked = actual_lock_users(*ids)
        ContentReport.objects.filter(pk=case.pk).update(target_key=f"removed:{case.target_revision}")
        return locked

    with patch("evidencias.moderation.lock_users", side_effect=anonymize_during_lock):
        result = decision(mod, case, action="keep")

    assert result.report_id == case.pk
    case.refresh_from_db()
    assert case.state == "closed"
    assert case.target_key == f"removed:{case.target_revision}"
