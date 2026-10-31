"""Independent connections: never claim SQLite proves author/version/quota locks."""

from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
import uuid

from django.db import close_old_connections, connection
import pytest
from rest_framework.exceptions import APIException

from usuarios.models import Usuario
from . import test_images
from .models import ImageAsset, ImageDecision, ReviewPhoto
from .moderation import decide_photo

pytestmark = [
    pytest.mark.django_db(transaction=True),
    pytest.mark.skipif(
        connection.vendor != "postgresql", reason="requires independent PostgreSQL image transactions"
    ),
]
scene = test_images.scene


def race(function):
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


def test_postgresql_concurrent_media_quota_is_enforced_under_upload_reservations(scene):
    for _ in range(4):
        test_images.send_photo(scene)
    test_images.api(scene[0])

    def post(index):
        owner = Usuario.objects.get(pk=scene[0].pk)
        result = test_images.api(owner).post(
            "/api/midia/fotos/enviar/",
            {
                "operation_id": str(uuid.uuid4()),
                "review_id": scene[4].pk,
                "review_revision": str(scene[4].content_revision),
                "description": "Synthetic simultaneous image",
                "file": test_images.upload_file(),
            },
            format="multipart",
        )
        return result.status_code

    outcomes = race(post)
    assert outcomes.count(201) == 1 and all(code in {201, 400, 409} for code in outcomes)
    assert ReviewPhoto.objects.filter(deleted_at=None).count() == 5


def test_postgresql_concurrent_avatar_versions_never_overwrite_newer_state(scene):
    owner = scene[0]
    test_images.api(owner)

    def put(index):
        user = Usuario.objects.get(pk=owner.pk)
        return (
            test_images.api(user)
            .put(
                "/api/usuarios/me/avatar/",
                {
                    "operation_id": str(uuid.uuid4()),
                    "expected_version": str(owner.avatar_version),
                    "file": test_images.upload_file(),
                },
                format="multipart",
            )
            .status_code
        )

    outcomes = race(put)
    assert sorted(outcomes) == [200, 409]
    owner.refresh_from_db()
    assert owner.avatar_asset_id and ImageAsset.objects.filter(state="ready", purpose="avatar").count() == 1


def test_postgresql_concurrent_photo_moderation_is_versioned_and_idempotent(scene):
    photo, _ = test_images.send_photo(scene)
    second = Usuario.objects.create_superuser(
        "synthetic-image-mod-2", email="image-mod-2@example.test", password="synthetic"
    )

    def decide(index):
        try:
            decide_photo(
                [scene[2].pk, second.pk][index],
                photo.pk,
                revision_id=photo.current_revision_id,
                expected_version=1,
                operation_id=uuid.uuid4(),
                action=["approve", "reject"][index],
                reason="Synthetic simultaneous moderation",
            )
            return "applied"
        except APIException as error:
            return error.status_code

    outcomes = race(decide)
    assert outcomes.count("applied") == 1 and outcomes.count(409) == 1
    assert ImageDecision.objects.count() == 1
