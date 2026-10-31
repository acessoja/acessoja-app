"""True independent PostgreSQL transactions, synchronized at the starting gate."""

from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
import uuid

from django.db import close_old_connections, connection
import pytest

from contribuicoes.models import ContributionPointEvent, PointActivity
from contribuicoes.services import impact
from evidencias.exceptions import RevisionConflict
from rest_framework.exceptions import NotFound
from . import test_images
from .moderation import decide_photo

scene = test_images.scene
pytestmark = [
    pytest.mark.django_db(transaction=True),
    pytest.mark.skipif(connection.vendor != "postgresql", reason="requires real independent PostgreSQL transactions"),
]


def race(action):
    gate = Barrier(2)

    def worker(index):
        close_old_connections()
        try:
            gate.wait(timeout=15)
            return action(index)
        finally:
            close_old_connections()

    with ThreadPoolExecutor(max_workers=2) as pool:
        return list(pool.map(worker, [0, 1]))


def approve(scene, photo):
    return decide_photo(
        scene[2].pk,
        photo.pk,
        revision_id=photo.current_revision_id,
        expected_version=1,
        operation_id=uuid.uuid4(),
        action="approve",
        reason="Synthetic concurrent photograph decision",
    )


def test_postgresql_concurrent_two_photo_approvals_grant_one_right(scene):
    photos = [test_images.send_photo(scene)[0] for _ in range(2)]
    race(lambda index: approve(scene, photos[index]))
    event = ContributionPointEvent.objects.get(user=scene[0], action="photo_evidence")
    assert event.active and PointActivity.objects.filter(event=event, delta=3).count() == 1
    assert impact(scene[0])["points"] == 13


def test_postgresql_concurrent_approval_and_last_photo_delete_stabilize_ledger(scene):
    photo = test_images.send_photo(scene)[0]
    test_images.api(scene[0])  # Create the token before the two transactions.

    def action(index):
        if index:
            return test_images.api(scene[0]).delete(
                f"/api/midia/fotos/{photo.pk}/",
                {"operation_id": str(uuid.uuid4()), "expected_revision": str(photo.current_revision_id)},
                format="json",
            )
        try:
            return approve(scene, photo)
        except (NotFound, RevisionConflict):
            return "content_removed"

    race(action)
    photo.refresh_from_db()
    assert photo.deleted_at and impact(scene[0])["points"] == 10
    assert not ContributionPointEvent.objects.filter(user=scene[0], action="photo_evidence", active=True).exists()


def test_postgresql_concurrent_review_edits_use_one_expected_revision(scene):
    review = scene[4]
    test_images.api(scene[0])

    def action(index):
        return (
            test_images.api(scene[0])
            .patch(
                f"/api/avaliacoes/modal-avaliacoes/{review.pk}/",
                {"expected_revision": str(review.content_revision), "comentario": f"Concurrent draft {index}"},
                format="json",
            )
            .status_code
        )

    assert sorted(race(action)) == [200, 409]


def test_postgresql_concurrent_independent_statements_begin_without_evidence_once(scene):
    from evidencias.models import ResourceEvidence

    test_images.api(scene[0])

    def action(index):
        return (
            test_images.api(scene[0])
            .post(
                "/api/evidencias/relatos/",
                {
                    "operation_id": str(uuid.uuid4()),
                    "local_id": scene[3].pk,
                    "resource": "piso_tatil",
                    "value": "yes" if index else "no",
                },
                format="json",
            )
            .status_code
        )

    assert sorted(race(action)) == [200, 409]
    rows = ResourceEvidence.objects.filter(owner=scene[0], local=scene[3], resource="piso_tatil")
    assert rows.count() == 1 and rows.get().revisions.count() == 1
