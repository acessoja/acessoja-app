from io import StringIO
import json
from unittest.mock import patch

import pytest
from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.core.management.base import CommandError
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction
from django.db.models import Sum

from locais.models import Local
from modal_avaliacao.models import ModalAvaliacao
from rest_framework.test import APIClient
from .models import ContributionPointEvent, PointActivity, UserAchievement
from .services import impact, reconcile_user, sync_evaluation

pytestmark = pytest.mark.django_db


@pytest.fixture
def records():
    user = get_user_model().objects.create_user(nome="integridade", email="integridade@test.com", password="test-pass")
    place = Local.objects.create(nome="Biblioteca", endereco="Centro", distancia=0, categoria="library")
    return user, place


def create_review(records):
    user, place = records
    return ModalAvaliacao.objects.create(
        user=user,
        local=place,
        estrelas=4,
        verified_author=True,
        survey_completed=True,
        **{f"pergunta_{i}": "Não sei" for i in range(1, 5)},
    )


def ledger_total(user):
    return PointActivity.objects.filter(event__user=user).aggregate(total=Sum("delta"))["total"] or 0


def test_direct_orm_save_rolls_back_review_when_point_activity_fails(records):
    with patch("contribuicoes.services.PointActivity.objects.create", side_effect=RuntimeError("audit failure")):
        with pytest.raises(RuntimeError, match="audit failure"):
            create_review(records)
    assert not ModalAvaliacao.objects.exists()
    assert not ContributionPointEvent.objects.exists()
    assert not PointActivity.objects.exists()


def test_stale_signal_cannot_restore_points_of_invalid_review(records):
    review = create_review(records)
    stale = ModalAvaliacao.objects.get(pk=review.pk)
    review.is_valid = False
    review.save()
    assert impact(records[0])["points"] == 0
    sync_evaluation(stale)
    assert impact(records[0])["points"] == 0
    assert ledger_total(records[0]) == 0


def test_stale_signal_cannot_award_a_deleted_review(records):
    review = create_review(records)
    stale = ModalAvaliacao.objects.get(pk=review.pk)
    review.delete()
    sync_evaluation(stale)
    assert impact(records[0])["points"] == 0
    assert ledger_total(records[0]) == 0


def test_existing_event_value_is_reconciled_with_confirmed_rule(records):
    review = create_review(records)
    ContributionPointEvent.objects.filter(action="review").update(points=900)
    sync_evaluation(review)
    assert impact(records[0])["points"] == 15
    assert ledger_total(records[0]) == 15


def test_orm_cannot_move_an_existing_review_to_a_different_origin(records):
    review = create_review(records)
    other = Local.objects.create(nome="Outro local", endereco="Centro", distancia=0)
    review.local = other
    with pytest.raises(ValidationError):
        review.save()
    review.refresh_from_db()
    assert review.local == records[1]
    assert impact(records[0])["points"] == ledger_total(records[0]) == 15


def test_missing_ledger_entry_is_repaired_once(records):
    review = create_review(records)
    PointActivity.objects.filter(event__action="review").delete()
    sync_evaluation(review)
    assert ledger_total(records[0]) == impact(records[0])["points"] == 15
    size = PointActivity.objects.count()
    sync_evaluation(review)
    assert PointActivity.objects.count() == size


def command_report(*args):
    output = StringIO()
    call_command("reconcile_contributions", *args, "--json", stdout=output)
    return json.loads(output.getvalue())


def test_reconciliation_is_read_only_by_default_then_applies_idempotently(records):
    review = create_review(records)
    first_date = UserAchievement.objects.get(code="first").unlocked_at
    ModalAvaliacao.objects.filter(pk=review.pk).update(is_valid=False)
    with patch("contribuicoes.services.PointActivity.objects.create", side_effect=AssertionError("dry run wrote")):
        preview = command_report("--user-id", str(records[0].pk))
    assert preview["mode"] == "dry_run"
    assert preview["events_changed"] == 2
    assert preview["users"][0]["points_after"] == 0
    assert impact(records[0])["points"] == 15
    assert PointActivity.objects.count() == 2
    applied = command_report("--apply", "--user-id", str(records[0].pk))
    assert applied["events_changed"] == 2
    assert ledger_total(records[0]) == impact(records[0])["points"] == 0
    assert not UserAchievement.objects.get(code="first").active
    assert UserAchievement.objects.get(code="first").unlocked_at == first_date
    count = PointActivity.objects.count()
    assert command_report("--apply")["events_changed"] == 0
    assert PointActivity.objects.count() == count


def test_reconciliation_restores_only_existing_eligible_balance(records):
    review = create_review(records)
    first_date = UserAchievement.objects.get(code="first").unlocked_at
    for _ in range(3):
        ModalAvaliacao.objects.filter(pk=review.pk).update(is_valid=False)
        reconcile_user(records[0].pk, apply=True)
        assert ledger_total(records[0]) == impact(records[0])["points"] == 0
        ModalAvaliacao.objects.filter(pk=review.pk).update(is_valid=True)
        reconcile_user(records[0].pk, apply=True)
        assert ledger_total(records[0]) == impact(records[0])["points"] == 15
    assert ContributionPointEvent.objects.count() == 2
    assert UserAchievement.objects.get(code="first").unlocked_at == first_date


def test_reconciliation_covers_unverified_sources_and_orphan_events(records):
    review = create_review(records)
    ModalAvaliacao.objects.filter(pk=review.pk).update(verified_author=False)
    assert command_report("--apply")["events_changed"] == 2
    assert impact(records[0])["points"] == ledger_total(records[0]) == 0
    review.delete()
    ContributionPointEvent.objects.update(active=True)
    report = command_report("--apply")
    assert report["events_changed"] == 2
    assert impact(records[0])["points"] == ledger_total(records[0]) == 0
    assert not ContributionPointEvent.objects.filter(active=True).exists()
    assert command_report("--apply")["events_changed"] == 0


def test_reconciliation_preserves_unknown_actions_and_rejects_unknown_users(records):
    create_review(records)
    ContributionPointEvent.objects.create(
        user=records[0], local=records[1], action="future_action", points=2, idempotency_key="future-action"
    )
    report = command_report("--apply")
    assert report["users"][0]["unknown_actions"] == ["future_action"]
    assert ContributionPointEvent.objects.get(action="future_action").active
    with pytest.raises(CommandError):
        command_report("--apply", "--user-id", str(records[0].pk), "--user-id", "999999")


def test_orm_comment_edit_revokes_approval_and_preserves_history_source(records):
    review = create_review(records)
    original_id = review.pk
    review.comentario = "A entrada possui rampa."
    review.comment_verified = True
    review.save()
    assert impact(records[0])["points"] == 20
    review.comentario = "O acesso mudou."
    review.save(update_fields=["comentario"])
    review.refresh_from_db()
    assert not review.comment_verified
    assert impact(records[0])["points"] == 15
    activity = PointActivity.objects.filter(event__action="useful_comment").first()
    assert activity.delta == -5 and activity.reason == "comment_changed"
    assert activity.source_evaluation_id == original_id
    review.delete()
    create_review(records)
    assert ledger_total(records[0]) == impact(records[0])["points"] == 15
    assert PointActivity.objects.filter(operation="granted", source_evaluation_id=original_id).count() == 3
    assert PointActivity.objects.filter(operation="restored").count() == 2


def test_archived_source_handoff_and_repeated_deletion_do_not_revoke_current_award(records):
    archived = create_review(records)
    archived.is_current = False
    archived.save()
    current = create_review(records)
    assert impact(records[0])["points"] == 15
    original = PointActivity.objects.count()
    for _ in range(2):
        sync_evaluation(archived, deleted=True)
        sync_evaluation(current)
    archived.delete()
    assert impact(records[0])["points"] == ledger_total(records[0]) == 15
    assert PointActivity.objects.count() == original


def test_survey_badge_uses_the_same_answer_eligibility_as_points(records):
    user, _ = records
    reviews = [create_review(records)]
    for index in range(4):
        place = Local.objects.create(nome=f"Local {index}", endereco="Centro", distancia=0)
        reviews.append(create_review((user, place)))
    assert UserAchievement.objects.get(code="attentive").active
    reviews[-1].pergunta_1 = ""
    reviews[-1].save()
    assert impact(user)["points"] == ledger_total(user) == 70
    assert not UserAchievement.objects.get(code="attentive").active


def test_database_constraints_guard_event_identity_and_history_replays(records):
    create_review(records)
    event = ContributionPointEvent.objects.get(action="review")
    with pytest.raises(IntegrityError), transaction.atomic():
        ContributionPointEvent.objects.create(
            user=records[0],
            local=records[1],
            action="review",
            points=10,
            idempotency_key="different-text-same-domain-action",
        )
    activity = PointActivity.objects.filter(event=event).first()
    with pytest.raises(IntegrityError), transaction.atomic():
        PointActivity.objects.create(event=event, delta=10, idempotency_key=activity.idempotency_key)
    assert impact(records[0])["points"] == ledger_total(records[0]) == 15


def test_repair_appends_adjustment_and_handles_an_outdated_revision(records):
    review = create_review(records)
    review.is_valid = False
    review.save()
    review.is_valid = True
    review.save()
    original_keys = list(PointActivity.objects.values_list("idempotency_key", flat=True))
    ContributionPointEvent.objects.filter(action="review").update(revision=1, points=99)
    sync_evaluation(review)
    assert ledger_total(records[0]) == impact(records[0])["points"] == 15
    assert all(PointActivity.objects.filter(idempotency_key=key).exists() for key in original_keys)
    latest = PointActivity.objects.filter(event__action="review").first()
    assert latest.delta == 0 and latest.reason == "points_reconciled"
    assert latest.idempotency_key.endswith(":4")


def test_create_edit_adjustment_and_opt_in_delete_return_confirmed_feedback(records):
    from django.core.cache import cache

    cache.clear()
    client = APIClient()
    client.force_authenticate(records[0])
    url = "/api/avaliacoes/modal-avaliacoes/"
    created = client.post(url, {"local": records[1].pk, "estrelas": 4, "comentario": "Observação"}, format="json")
    assert created.status_code == 201
    assert created.data["contribution_result"] == {
        "operation": "created",
        "outcome": "points_granted",
        "points_delta": 10,
        "points": 10,
    }
    detail = f"{url}{created.data['id']}/"
    changed = client.patch(detail, {"estrelas": 3}, format="json")
    assert changed.data["contribution_result"]["outcome"] == "no_new_points"
    completed = client.patch(detail, {f"pergunta_{i}": "Não sei" for i in range(1, 5)}, format="json")
    assert completed.data["contribution_result"]["points_delta"] == 5
    review = ModalAvaliacao.objects.get()
    review.comment_verified = True
    review.save()
    edited = client.patch(detail, {"comentario": "Nova observação"}, format="json")
    assert edited.data["contribution_result"]["outcome"] == "points_adjusted"
    assert edited.data["contribution_result"]["points_delta"] == -5
    deleted = client.delete(f"{detail}?feedback=1")
    assert deleted.status_code == 200
    assert deleted.data["contribution_result"]["operation"] == "deleted"
    assert deleted.data["points_delta"] == -15
    assert client.delete(f"{detail}?feedback=1").status_code == 404
    assert impact(records[0])["points"] == ledger_total(records[0]) == 0
    cache.clear()


def test_activity_is_private_paginated_and_keeps_deleted_source_metadata(records):
    review = create_review(records)
    original_id = review.pk
    review.delete()
    client = APIClient()
    client.force_authenticate(records[0])
    response = client.get("/api/contribuicoes/atividade/?page_size=1")
    assert response.status_code == 200 and response.data["count"] == 4
    assert response.data["next"] is not None
    row = response.data["results"][0]
    assert row["evaluation_id"] is None
    assert row["source_evaluation_id"] == original_id
    assert row["status"] == "removed" and row["operation"] == "revoked"
    assert row["reason"] == "review_removed"
    outsider = get_user_model().objects.create_user(nome="privado", email="privado@test.com", password="test-pass")
    client.force_authenticate(outsider)
    assert client.get(f"/api/contribuicoes/atividade/?user={records[0].pk}").data["count"] == 0
    assert client.get(f"/api/contribuicoes/meu-impacto/?user={records[0].pk}").data["points"] == 0


def test_impact_distinguishes_actions_reviews_and_operations_and_maximum_level(records):
    review = create_review(records)
    value = impact(records[0])
    assert value["reviews"] == 1 and value["contributions_count"] == 2 and value["history_count"] == 2
    review.is_valid = False
    review.save()
    value = impact(records[0])
    assert value["reviews"] == value["contributions_count"] == 0 and value["history_count"] == 4
    review.is_valid = True
    review.save()
    for index in range(49):
        place = Local.objects.create(nome=f"Lugar {index}", endereco="Centro", distancia=0)
        create_review((records[0], place))
    maximum = impact(records[0])
    assert maximum["points"] == 750 and maximum["level"] == 5
    assert maximum["next_level_points"] is None
    assert maximum["remaining_points"] == 0 and maximum["progress"] == 1
