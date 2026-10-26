"""Independent PostgreSQL connections; deliberately skipped on SQLite."""

from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
import uuid

from django.db import close_old_connections, connection
import pytest

from contribuicoes.models import ContributionPointEvent, PointActivity
from usuarios.models import Usuario
from . import test_flow
from .exceptions import RevisionConflict
from .models import ContentReport, ModerationDecision
from .moderation import decide

pytestmark = [
    pytest.mark.django_db(transaction=True),
    pytest.mark.skipif(connection.vendor != "postgresql", reason="requires independent PostgreSQL locks"),
]
scenario = test_flow.scenario


def concurrent(function):
    barrier = Barrier(2)

    def worker(index):
        close_old_connections()
        try:
            barrier.wait(timeout=10)
            return function(index)
        finally:
            close_old_connections()

    with ThreadPoolExecutor(max_workers=2) as pool:
        return list(pool.map(worker, range(2)))


def test_postgresql_concurrent_duplicate_reports_have_one_real_protocol(scenario):
    _, reader, _, _, review, _ = scenario
    body = {
        "target_kind": "review",
        "review_id": review.pk,
        "revision": str(review.content_revision),
        "reason": "incorrect",
    }
    # Ensure token creation is not itself the contested operation.
    test_flow.client_for(reader)

    def send(index):
        user = Usuario.objects.get(pk=reader.pk)
        response = test_flow.client_for(user).post(
            "/api/denuncias/", {**body, "reason": "outdated" if index else "incorrect"}, format="json"
        )
        return response.status_code, response.data.get("protocol")

    outcomes = concurrent(send)
    assert sorted(item[0] for item in outcomes) == [200, 201]
    assert outcomes[0][1] == outcomes[1][1] and ContentReport.objects.count() == 1


def test_postgresql_concurrent_moderators_get_one_effect_and_a_conflict(scenario):
    _, reader, mod, _, review, _ = scenario
    second = Usuario.objects.create_superuser(
        "synthetic-second-mod", email="second@example.test", password="synthetic-pass"
    )
    case = test_flow.report_review(reader, review)
    before = PointActivity.objects.count()
    eligible = ContributionPointEvent.objects.filter(user=scenario[0], active=True).count()

    def act(index):
        try:
            decide(
                [mod.pk, second.pk][index],
                case.pk,
                action="invalidate",
                reason="Synthetic concurrent moderation",
                expected_version=case.version,
                expected_target_revision=case.target_revision,
                operation_id=uuid.uuid4(),
            )
            return "applied"
        except RevisionConflict:
            return "conflict"

    assert sorted(concurrent(act)) == ["applied", "conflict"]
    review.refresh_from_db()
    assert not review.is_valid and ModerationDecision.objects.count() == 1
    assert PointActivity.objects.count() == before + eligible
    assert not ContributionPointEvent.objects.filter(user=scenario[0], active=True).exists()


def test_postgresql_concurrent_author_edit_and_decision_keep_revision_binding(scenario):
    author, reader, mod, _, review, _ = scenario
    case = test_flow.report_review(reader, review)
    test_flow.client_for(author)

    def operation(index):
        if index == 0:
            response = test_flow.client_for(Usuario.objects.get(pk=author.pk)).patch(
                f"/api/avaliacoes/modal-avaliacoes/{review.pk}/",
                {
                    "comentario": "New concurrent synthetic content",
                    "expected_revision": str(review.content_revision),
                },
                format="json",
            )
            return response.status_code
        try:
            test_flow.decision(mod, case)
            return "moderated"
        except RevisionConflict:
            return "conflict"

    outcome = concurrent(operation)
    assert outcome[0] in {200, 409} and outcome[1] in {"moderated", "conflict"}
    review.refresh_from_db()
    if outcome[1] == "conflict":
        assert review.is_valid and review.content_revision != case.target_revision
    else:
        assert (
            not review.is_valid and ModerationDecision.objects.get().target_revision == case.target_revision
        )


def test_postgresql_concurrent_account_deletion_does_not_deadlock_moderation(scenario):
    author, reader, mod, _, review, _ = scenario
    case = test_flow.report_review(reader, review)
    test_flow.client_for(author)

    def operation(index):
        if index == 0:
            response = test_flow.client_for(Usuario.objects.get(pk=author.pk)).post(
                "/api/usuarios/me/delete-account/",
                {"current_password": test_flow.PASSWORD, "confirm": True},
                format="json",
            )
            return response.status_code
        try:
            test_flow.decision(mod, case)
            return "moderated"
        except RevisionConflict:
            return "conflict"

    outcome = concurrent(operation)
    assert outcome[0] == 204 and outcome[1] in {"moderated", "conflict"}
    assert not Usuario.objects.filter(pk=author.pk).exists()
    case.refresh_from_db()
    assert case.review_revision.owner_id is None and case.review_revision.payload == {}


def test_postgresql_concurrent_confirmation_is_one_event_without_points(scenario):
    from .models import EvidenceConfirmation

    _, reader, _, _, _, root = scenario
    test_flow.client_for(reader)
    before = list(PointActivity.objects.values_list("pk", "delta"))

    def confirm(index):
        result = test_flow.client_for(Usuario.objects.get(pk=reader.pk)).post(
            f"/api/evidencias/{root.pk}/confirmar/",
            {"revision": str(root.current_revision_id)},
            format="json",
        )
        return result.status_code, result.data.get("confirmed_at")

    results = concurrent(confirm)
    assert [row[0] for row in results] == [200, 200] and results[0][1] == results[1][1]
    assert EvidenceConfirmation.objects.count() == 1 and before == list(
        PointActivity.objects.values_list("pk", "delta")
    )


def test_postgresql_concurrent_same_operation_returns_identical_decision(scenario):
    _, reader, mod, _, review, _ = scenario
    case = test_flow.report_review(reader, review)
    operation = uuid.uuid4()

    def act(index):
        result = test_flow.decision(mod, case, operation_id=operation)
        return result.pk

    results = concurrent(act)
    assert results[0] == results[1] and ModerationDecision.objects.count() == 1


def test_postgresql_concurrent_osm_channels_share_lock_and_denial(scenario):
    from django.utils import timezone
    from .capture import capture_batch

    _, reader, mod, _, _, _ = scenario
    second_mod = Usuario.objects.create_superuser(
        "synthetic-channel-mod", email="channel@example.test", password="synthetic"
    )
    specs = [
        {
            "key": f"{channel}:osm:node:9888:banheiro_acessivel",
            "kind": "osm",
            "source": "openstreetmap",
            "resource": "banheiro_acessivel",
            "external_id": "osm:node:9888",
            "state": "presence_reported",
            "received_at": timezone.now(),
        }
        for channel in ["catalog", "remote"]
    ]
    roots = capture_batch(specs)
    cases = []
    for root in roots:
        response = test_flow.client_for(reader).post(
            "/api/denuncias/",
            {
                "target_kind": "evidence",
                "evidence_id": str(root.pk),
                "revision": str(root.current_revision_id),
                "reason": "incorrect",
            },
            format="json",
        )
        cases.append(ContentReport.objects.get(pk=response.data["protocol"]))

    def act(index):
        try:
            test_flow.decision([mod, second_mod][index], cases[index])
            return "applied"
        except RevisionConflict:
            return "conflict"

    assert sorted(concurrent(act)) == ["applied", "conflict"]
    for root in roots:
        root.refresh_from_db()
        assert not root.current_revision.is_valid
