"""Real synthetic rasters/storage and HTTP contracts. No personal images or external provider."""

import base64
from io import BytesIO
import json
from pathlib import Path
from unittest.mock import patch
import uuid
import zipfile

from django.contrib.auth.models import Permission
from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import Client
from django.urls import reverse
from PIL import Image
import pytest
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient

from contribuicoes.models import PointActivity
from evidencias.models import ContentReport
from evidencias.moderation import decide
from locais.models import Local, RouteHistorySession, VisitaRecente
from modal_avaliacao.models import ModalAvaliacao
from usuarios.deletion_journal import journal_identity
from usuarios.models import Usuario
from .cleanup import reconcile_images
from .exceptions import ImageRejected
from .models import (
    ImageAsset,
    ImageCleanup,
    ImageDecision,
    ImageOperation,
    PhotoRevision,
    ReviewPhoto,
)
from .moderation import decide_photo
from .processing import process_image
from .storage import image_storage

pytestmark = pytest.mark.django_db
PASSWORD = "Synthetic-photo-password!42"


def raster(fmt="PNG", size=(80, 40), orientation=None):
    stream = BytesIO()
    options = {}
    if orientation:
        exif = Image.Exif()
        exif[274], exif[271], exif[315] = (
            orientation,
            "SYNTHETIC_DEVICE",
            "SYNTHETIC_AUTHOR",
        )
        exif[34853] = {1: "N", 2: (1, 2, 3), 3: "E", 4: (4, 5, 6)}
        options["exif"] = exif
    Image.new("RGB", size, (30, 140, 90)).save(stream, fmt, **options)
    return stream.getvalue()


def upload_file(content=None, name="image.png", mime="image/png"):
    return SimpleUploadedFile(name, content if content is not None else raster(), content_type=mime)


def api(user=None):
    client = APIClient()
    if user:
        token, _ = Token.objects.get_or_create(user=user)
        client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")
    return client


@pytest.fixture
def scene(settings, tmp_path):
    cache.clear()
    settings.PRIVATE_IMAGE_ROOT = tmp_path / "images"
    settings.DELETION_JOURNAL_DIR = tmp_path / "deletions"
    settings.PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]
    journal_identity(initialize=True)
    owner = Usuario.objects.create_user("photo-owner", email="owner@example.test", password=PASSWORD)
    reader = Usuario.objects.create_user("photo-reader", email="reader@example.test", password=PASSWORD)
    moderator = Usuario.objects.create_user(
        "photo-moderator",
        email="moderator@example.test",
        password=PASSWORD,
        is_staff=True,
    )
    moderator.user_permissions.add(
        Permission.objects.get(codename="moderate_content", content_type__app_label="evidencias")
    )
    local = Local.objects.create(nome="Synthetic photographed place", endereco="Synthetic street", distancia=0)
    review = ModalAvaliacao.objects.create(
        user=owner,
        local=local,
        estrelas=4,
        comentario="Synthetic experience",
        verified_author=True,
    )
    yield owner, reader, moderator, local, review
    cache.clear()


def send_photo(scene, operation=None, **extra):
    owner, _, _, _, review = scene
    body = {
        "operation_id": operation or uuid.uuid4(),
        "review_id": review.pk,
        "review_revision": str(review.content_revision),
        "description": "Rampa na entrada principal do local sintético.",
        "file": upload_file(),
        **extra,
    }
    response = api(owner).post("/api/midia/fotos/enviar/", body, format="multipart")
    assert response.status_code == 201, response.data
    return (
        ReviewPhoto.objects.select_related("current_revision__asset").get(pk=response.data["photo_id"]),
        response,
    )


def approve(scene, photo, action="approve", **extra):
    revision = PhotoRevision.objects.get(pk=photo.current_revision_id)
    return decide_photo(
        scene[2].pk,
        photo.pk,
        revision_id=revision.pk,
        expected_version=revision.moderation_version,
        operation_id=uuid.uuid4(),
        action=action,
        reason="Synthetic image moderation justification",
        **extra,
    )


def test_c42_valid_upload_is_pending_private_and_changes_no_points(scene):
    before = list(PointActivity.objects.values_list("pk", "delta"))
    photo, response = send_photo(scene)
    assert response.data["state"] == "committed" and photo.current_revision.state == "pending"
    assert ImageOperation.objects.get(operation_id=response.data["operation_id"]).state == "committed"
    assert image_storage().exists(photo.current_revision.asset.image_key)
    public = api().get("/api/midia/fotos/", {"local_id": scene[3].pk})
    own = api(scene[0]).get("/api/midia/fotos/", {"review_id": scene[4].pk})
    assert public.data["count"] == 0 and own.data["count"] == 1
    assert own.data["results"][0]["can_delete"]
    assert "owner" not in own.data["results"][0] and "storage" not in json.dumps(own.data)
    assert before == list(PointActivity.objects.values_list("pk", "delta"))
    assert not RouteHistorySession.objects.exists() and not VisitaRecente.objects.exists()


@pytest.mark.parametrize("variant", ["image", "thumb"])
def test_c42_publication_requires_approval_and_each_direct_variant_is_authorized(scene, variant):
    photo, _ = send_photo(scene)
    path = f"/api/midia/arquivos/{photo.current_revision.asset_id}/{variant}/"
    assert api().get(path).status_code == api(scene[1]).get(path).status_code == 404
    own = api(scene[0]).get(path)
    assert own.status_code == 200 and own["Cache-Control"] == "private, no-store"
    own.close()
    approve(scene, photo)
    image = api().get(path)
    assert (
        image.status_code == 200
        and image["Content-Type"] == "image/jpeg"
        and image["X-Content-Type-Options"] == "nosniff"
    )
    assert b"".join(image.streaming_content).startswith(b"\xff\xd8")
    assert api().head(path).status_code == 200
    scene[0].mostrar_avaliacoes = False
    scene[0].save(update_fields=["mostrar_avaliacoes"])
    assert api().get(path).status_code == api().head(path).status_code == 404


@pytest.mark.parametrize("change", ["invalid", "archived", "deleted"])
def test_c42_ineligible_review_revokes_public_file_and_list(scene, change):
    photo, _ = send_photo(scene)
    approve(scene, photo)
    path = f"/api/midia/arquivos/{photo.current_revision.asset_id}/image/"
    review = scene[4]
    if change == "deleted":
        review.delete()
    else:
        setattr(review, "is_valid" if change == "invalid" else "is_current", False)
        review.save()
    assert api().get(path).status_code == 404
    assert api().get("/api/midia/fotos/", {"local_id": scene[3].pk}).data["count"] == 0


def test_c42_retry_and_quantity_are_enforced_without_duplicate_files(scene):
    op = uuid.uuid4()
    photo, first = send_photo(scene, operation=op)
    _, second = send_photo(scene, operation=op)
    assert first.data == second.data and ReviewPhoto.objects.count() == ImageAsset.objects.count() == 1
    assert len(list(Path(image_storage().location).rglob("*.jpg"))) == 2
    for _ in range(4):
        send_photo(scene)
    review = scene[4]
    response = api(scene[0]).post(
        "/api/midia/fotos/enviar/",
        {
            "operation_id": str(uuid.uuid4()),
            "review_id": review.pk,
            "review_revision": str(review.content_revision),
            "description": "Another synthetic ramp image",
            "file": upload_file(),
        },
        format="multipart",
    )
    assert response.status_code == 400 and ReviewPhoto.objects.count() == 5


def test_c42_ownership_and_unknown_fields_cannot_be_forged(scene):
    owner, reader, _, _, review = scene
    body = {
        "operation_id": uuid.uuid4(),
        "review_id": review.pk,
        "review_revision": review.content_revision,
        "description": "Synthetic ramp description",
        "file": upload_file(),
    }
    assert api().post("/api/midia/fotos/enviar/", body, format="multipart").status_code == 401
    body["file"] = upload_file()
    assert api(reader).post("/api/midia/fotos/enviar/", body, format="multipart").status_code == 404
    body["file"], body["owner"] = upload_file(), owner.pk
    assert api(owner).post("/api/midia/fotos/enviar/", body, format="multipart").status_code == 400
    assert not ImageAsset.objects.exists()


@pytest.mark.parametrize(
    "content,name,mime",
    [
        (b"<svg/>", "image.svg", "image/svg+xml"),
        (b"not a raster", "image.png", "image/png"),
        (raster(), "image.jpg", "image/jpeg"),
        (raster()[:30], "image.png", "image/png"),
        (b"\x00heic", "image.heic", "image/heic"),
    ],
)
def test_c45_disguised_corrupt_and_unsupported_inputs_are_not_published(scene, content, name, mime):
    owner, _, _, _, review = scene
    result = api(owner).post(
        "/api/midia/fotos/enviar/",
        {
            "operation_id": str(uuid.uuid4()),
            "review_id": review.pk,
            "review_revision": str(review.content_revision),
            "description": "Synthetic invalid image context",
            "file": upload_file(content, name, mime),
        },
        format="multipart",
    )
    assert result.status_code == 422
    assert not ReviewPhoto.objects.exists() and not ImageAsset.objects.filter(state="ready").exists()
    reconcile_images()
    assert not list(Path(image_storage().location).rglob("*.jpg"))


def test_c45_byte_pixel_and_request_limits_are_distinct(scene, settings):
    from .processing import read_input
    from .exceptions import ImageTooLarge

    with pytest.raises(ImageTooLarge):
        read_input(upload_file(b"x" * (settings.IMAGE_MAX_BYTES + 1)))
    with pytest.raises(ImageRejected):
        process_image(raster(size=(12001, 1)), ".png", "image/png", "photo")
    result = api(scene[0]).generic(
        "POST",
        "/api/midia/fotos/enviar/",
        b"",
        content_type="multipart/form-data",
        CONTENT_LENGTH="6000001",
    )
    assert result.status_code == 413


def test_c45_real_decoder_orients_reencodes_and_removes_exif(scene):
    result = process_image(raster("JPEG", (80, 40), orientation=6), ".jpg", "image/jpeg", "photo")
    assert (result["width"], result["height"]) == (40, 80)
    for key in ["image", "thumb"]:
        with Image.open(BytesIO(result[key])) as image:
            assert image.format == "JPEG" and not image.getexif() and not image.info.get("icc_profile")
    assert b"SYNTHETIC_DEVICE" not in result["image"] and b"SYNTHETIC_AUTHOR" not in result["thumb"]


def test_c42_approval_is_separate_from_report_and_staff_alone_cannot_decide(scene):
    photo, _ = send_photo(scene)
    staff = scene[1]
    staff.is_staff = True
    staff.save(update_fields=["is_staff"])
    from rest_framework.exceptions import PermissionDenied

    with pytest.raises(PermissionDenied):
        decide_photo(
            staff.pk,
            photo.pk,
            revision_id=photo.current_revision_id,
            expected_version=1,
            operation_id=uuid.uuid4(),
            action="approve",
            reason="Synthetic moderation without authority",
        )
    result = approve(scene, photo)
    assert result.action == "approve" and ImageDecision.objects.count() == 1 and not ContentReport.objects.exists()


def test_c42_approved_photo_report_uses_existing_queue_and_no_reporter_exposure(scene):
    photo, _ = send_photo(scene)
    approve(scene, photo)
    reader = api(scene[1])
    result = reader.post(
        "/api/denuncias/",
        {
            "target_kind": "photo",
            "photo_id": str(photo.pk),
            "revision": str(photo.current_revision_id),
            "reason": "inappropriate",
        },
        format="json",
    )
    assert result.status_code == 201, result.data
    case = ContentReport.objects.get(pk=result.data["protocol"])
    before = list(PointActivity.objects.values_list("pk", "delta"))
    op = uuid.uuid4()
    decide(
        scene[2].pk,
        case.pk,
        action="invalidate",
        reason="Synthetic report image rejection",
        expected_version=1,
        expected_target_revision=case.target_revision,
        operation_id=op,
    )
    assert PhotoRevision.objects.get(pk=case.target_revision).state == "rejected"
    assert ImageDecision.objects.filter(report=case).count() == 1
    assert api().get(f"/api/midia/arquivos/{photo.current_revision.asset_id}/image/").status_code == 404
    assert api(scene[0]).get(f"/api/denuncias/{case.pk}/").status_code == 404
    assert PointActivity.objects.count() == len(before) + 1
    assert PointActivity.objects.first().delta == -3


def test_c42_replacement_and_description_require_new_review_without_touching_other_fields(
    scene,
):
    photo, _ = send_photo(scene)
    approve(scene, photo)
    original = photo.current_revision
    _, result = send_photo(
        scene,
        photo_id=str(photo.pk),
        expected_revision=str(original.pk),
        file=upload_file(raster("JPEG"), "new.jpg", "image/jpeg"),
    )
    photo.refresh_from_db()
    assert photo.current_revision_id != original.pk and photo.current_revision.state == "pending"
    assert ImageAsset.objects.get(pk=original.asset_id).state == "retired"
    updated = api(scene[0]).patch(
        f"/api/midia/fotos/{photo.pk}/",
        {
            "operation_id": str(uuid.uuid4()),
            "expected_revision": str(photo.current_revision_id),
            "description": "Nova descrição sintética que altera o contexto.",
        },
        format="json",
    )
    assert updated.status_code == 200 and PhotoRevision.objects.get(pk=updated.data["revision"]).state == "pending"
    scene[4].refresh_from_db()
    assert scene[4].estrelas == 4 and scene[4].comentario == "Synthetic experience"


def test_c42_storage_failure_is_recoverable_and_retry_reuses_operation(scene):
    owner, _, _, _, review = scene
    operation = uuid.uuid4()
    body = {
        "operation_id": str(operation),
        "review_id": review.pk,
        "review_revision": str(review.content_revision),
        "description": "Rampa na entrada principal do local sintético.",
        "file": upload_file(),
    }
    with patch(
        "midia.services.store_derivatives",
        side_effect=OSError("synthetic storage failure"),
    ):
        response = api(owner).post("/api/midia/fotos/enviar/", body, format="multipart")
    assert response.status_code == 503
    assert ImageOperation.objects.get(operation_id=operation).state == "failed" and not ReviewPhoto.objects.exists()
    send_photo(scene, operation=operation)
    assert ImageOperation.objects.filter(operation_id=operation).count() == 1
    assert ReviewPhoto.objects.count() == 1 and ImageCleanup.objects.exists()


def test_c44_avatar_is_processed_preserves_base64_contract_and_remove_is_versioned(
    scene,
):
    owner = scene[0]
    original = owner.avatar_version
    operation = str(uuid.uuid4())
    body = {
        "operation_id": operation,
        "expected_version": str(original),
        "file": upload_file(),
    }
    response = api(owner).put("/api/usuarios/me/avatar/", body, format="multipart")
    assert response.status_code == 200, response.data
    owner.refresh_from_db()
    assert owner.avatar_asset_id and owner.avatar_version != original
    with Image.open(BytesIO(base64.b64decode(owner.foto_perfil))) as image:
        assert image.format == "JPEG" and max(image.size) <= 160
    same = {**body, "file": upload_file()}
    assert (
        api(owner).put("/api/usuarios/me/avatar/", same, format="multipart").data["revision"]
        == response.data["revision"]
    )
    assert api(scene[1]).get(f"/api/midia/arquivos/{owner.avatar_asset_id}/thumb/").status_code == 404
    deleted = api(owner).delete(
        "/api/usuarios/me/avatar/",
        {
            "operation_id": str(uuid.uuid4()),
            "expected_version": str(owner.avatar_version),
        },
        format="json",
    )
    assert deleted.status_code == 200
    owner.refresh_from_db()
    assert owner.foto_perfil == "" and owner.avatar_asset_id is None
    assert (
        api(owner)
        .put(
            "/api/usuarios/me/avatar/",
            {**body, "operation_id": str(uuid.uuid4()), "file": upload_file()},
            format="multipart",
        )
        .status_code
        == 409
    )
    assert api(owner).get("/api/usuarios/me/avatar/").data["has_avatar"] is False


def test_c44_bad_replacement_preserves_previous_and_generic_update_cannot_bypass(scene):
    owner = scene[0]
    owner.foto_perfil = base64.b64encode(raster()).decode()
    owner.save(update_fields=["foto_perfil"])
    raw = owner.foto_perfil
    assert api(owner).get("/api/usuarios/me/avatar/").data["foto_perfil"] == raw
    result = api(owner).put(
        "/api/usuarios/me/avatar/",
        {
            "operation_id": str(uuid.uuid4()),
            "expected_version": str(owner.avatar_version),
            "file": upload_file(b"not a picture"),
        },
        format="multipart",
    )
    assert result.status_code == 422
    owner.refresh_from_db()
    assert owner.foto_perfil == raw
    result = api(owner).put(
        "/api/usuarios/perfil/",
        {"foto_perfil": "malicious"},
        QUERY_STRING=f"nome={owner.nome}",
        format="json",
    )
    assert result.status_code == 400
    assert (
        api(owner)
        .post(
            "/api/usuarios/foto/",
            {"nome": owner.nome, "foto_perfil": "arbitrary"},
            format="json",
        )
        .status_code
        == 400
    )
    result = api(owner).post(
        "/api/usuarios/foto/",
        {"nome": owner.nome, "foto_perfil": base64.b64encode(raster()).decode()},
        format="json",
    )
    assert result.status_code == 200, result.data


def test_c45_remove_and_reconcile_are_idempotent_and_do_not_delete_live_assets(scene):
    photo, _ = send_photo(scene)
    asset = photo.current_revision.asset
    ImageCleanup.objects.create(asset=asset)
    assert reconcile_images() == 0 and image_storage().exists(asset.image_key)
    body = {
        "operation_id": str(uuid.uuid4()),
        "expected_revision": str(photo.current_revision_id),
    }
    result = api(scene[0]).delete(f"/api/midia/fotos/{photo.pk}/", body, format="json")
    assert result.status_code == 200
    assert api(scene[0]).delete(f"/api/midia/fotos/{photo.pk}/", body, format="json").status_code == 200
    assert reconcile_images() == 1 and reconcile_images() == 0 and not image_storage().exists(asset.image_key)


def test_c45_export_images_is_own_and_private_and_account_erasure_removes_availability(
    scene,
):
    photo, _ = send_photo(scene)
    result = api(scene[0]).post("/api/usuarios/me/images-export/", {"current_password": PASSWORD}, format="json")
    assert result.status_code == 200, getattr(result, "data", None)
    content = b"".join(result.streaming_content)
    with zipfile.ZipFile(BytesIO(content)) as archive:
        assert any(name.endswith("/image.jpg") for name in archive.namelist())
        assert len(json.loads(archive.read("manifest.json"))["images"]) == 1
    assert result["Cache-Control"] == "private, no-store"
    result = api(scene[1]).post("/api/usuarios/me/images-export/", {"current_password": PASSWORD}, format="json")
    with zipfile.ZipFile(BytesIO(b"".join(result.streaming_content))) as archive:
        assert json.loads(archive.read("manifest.json"))["images"] == []
    removed = api(scene[0]).post(
        "/api/usuarios/me/delete-account/",
        {"current_password": PASSWORD, "confirm": True},
        format="json",
    )
    assert removed.status_code == 204, removed.data
    assert api().get(f"/api/midia/arquivos/{photo.current_revision.asset_id}/thumb/").status_code == 404
    assert not PhotoRevision.objects.exclude(description="").exists()
    reconcile_images()
    assert not list(Path(image_storage().location).rglob("*.jpg"))


def test_admin_session_can_read_pending_file_and_has_initial_review_surface(scene):
    photo, _ = send_photo(scene)
    client = Client()
    client.force_login(scene[2])
    page = client.get(reverse("admin:image-photo-decision", args=[photo.pk]))
    assert page.status_code == 200 and scene[1].email.encode() not in page.content
    # Session authentication is explicit on protected GET files even in token-only deployments.
    response = client.get(f"/api/midia/arquivos/{photo.current_revision.asset_id}/image/")
    assert response.status_code == 200
    response.close()


def test_c42_live_session_is_rechecked_after_actual_processing(scene):
    from .processing import process_image as real_process

    def revoke(*args):
        result = real_process(*args)
        Token.objects.filter(user=scene[0]).delete()
        return result

    review = scene[4]
    client = api(scene[0])
    with patch("midia.services.process_image", side_effect=revoke):
        result = client.post(
            "/api/midia/fotos/enviar/",
            {
                "operation_id": str(uuid.uuid4()),
                "review_id": review.pk,
                "review_revision": str(review.content_revision),
                "description": "Synthetic credential revocation image",
                "file": upload_file(),
            },
            format="multipart",
        )
    assert result.status_code == 401 and not ReviewPhoto.objects.exists()
    assert ImageOperation.objects.get().state == "failed" and ImageAsset.objects.get().state == "retired"


def test_c42_database_failure_rolls_back_and_keeps_durable_cleanup(scene):
    from django.db import DatabaseError

    with patch(
        "midia.services.PhotoRevision.objects.create",
        side_effect=DatabaseError("synthetic database failure"),
    ):
        review = scene[4]
        result = api(scene[0]).post(
            "/api/midia/fotos/enviar/",
            {
                "operation_id": str(uuid.uuid4()),
                "review_id": review.pk,
                "review_revision": str(review.content_revision),
                "description": "Synthetic database failure image",
                "file": upload_file(),
            },
            format="multipart",
        )
    assert result.status_code == 503
    assert not ReviewPhoto.objects.exists() and not PhotoRevision.objects.exists()
    assert ImageOperation.objects.get().state == "failed" and ImageCleanup.objects.get().state == "pending"
    assert reconcile_images() == 1


def test_c42_duplicate_operation_with_changed_content_and_stale_moderation_are_conflicts(
    scene,
):
    photo, first = send_photo(scene)
    review = scene[4]
    changed = api(scene[0]).post(
        "/api/midia/fotos/enviar/",
        {
            "operation_id": first.data["operation_id"],
            "review_id": review.pk,
            "review_revision": str(review.content_revision),
            "description": "Changed context for same identity",
            "file": upload_file(),
        },
        format="multipart",
    )
    assert changed.status_code == 409 and ReviewPhoto.objects.count() == 1
    old = photo.current_revision_id
    send_photo(
        scene,
        photo_id=str(photo.pk),
        expected_revision=str(old),
        file=upload_file(raster("JPEG"), "new.jpg", "image/jpeg"),
    )
    from evidencias.exceptions import RevisionConflict

    with pytest.raises(RevisionConflict):
        decide_photo(
            scene[2].pk,
            photo.pk,
            revision_id=old,
            expected_version=1,
            operation_id=uuid.uuid4(),
            action="approve",
            reason="Stale synthetic moderator form",
        )
    photo.refresh_from_db()
    assert photo.current_revision.state == "pending"


def test_c42_moderation_is_idempotent_and_comment_edit_keeps_approved_photo(scene):
    photo, _ = send_photo(scene)
    op = uuid.uuid4()
    body = {
        "revision_id": photo.current_revision_id,
        "expected_version": 1,
        "operation_id": op,
        "action": "approve",
        "reason": "Synthetic approval repeated safely",
    }
    first = decide_photo(scene[2].pk, photo.pk, **body)
    assert decide_photo(scene[2].pk, photo.pk, **body).pk == first.pk and ImageDecision.objects.count() == 1
    scene[4].comentario = "Another synthetic review comment"
    scene[4].save()
    photo.refresh_from_db()
    assert photo.current_revision.state == "approved"
    assert api().get("/api/midia/fotos/", {"local_id": scene[3].pk}).data["count"] == 1


def test_c45_cleanup_failure_retries_and_expired_processing_is_reconciled(scene):
    from datetime import timedelta
    from django.utils import timezone

    photo, _ = send_photo(scene)
    api(scene[0]).delete(
        f"/api/midia/fotos/{photo.pk}/",
        {
            "operation_id": str(uuid.uuid4()),
            "expected_revision": str(photo.current_revision_id),
        },
        format="json",
    )
    with patch(
        "midia.cleanup.image_storage",
        side_effect=OSError("synthetic unavailable volume"),
    ):
        assert reconcile_images() == 0
    assert ImageCleanup.objects.get().attempts == 1
    assert reconcile_images() == 1
    op = ImageOperation.objects.filter(kind="photo").get()
    ImageOperation.objects.filter(pk=op.pk).update(state="processing", expires_at=timezone.now() - timedelta(seconds=1))
    reconcile_images()
    op.refresh_from_db()
    assert op.state == "failed"


def test_c45_streamed_limit_and_unknown_variants_are_refused(scene, settings):
    settings.IMAGE_MAX_BYTES = 30
    review = scene[4]
    result = api(scene[0]).post(
        "/api/midia/fotos/enviar/",
        {
            "operation_id": str(uuid.uuid4()),
            "review_id": review.pk,
            "review_revision": str(review.content_revision),
            "description": "Synthetic oversized streaming upload",
            "file": upload_file(),
        },
        format="multipart",
    )
    assert result.status_code == 413
    assert api().get(f"/api/midia/arquivos/{uuid.uuid4()}/original/").status_code == 404


def test_c42_old_photo_report_never_rejects_replacement(scene):
    photo, _ = send_photo(scene)
    approve(scene, photo)
    response = api(scene[1]).post(
        "/api/denuncias/",
        {
            "target_kind": "photo",
            "photo_id": str(photo.pk),
            "revision": str(photo.current_revision_id),
            "reason": "incorrect",
        },
        format="json",
    )
    case = ContentReport.objects.get(pk=response.data["protocol"])
    send_photo(
        scene,
        photo_id=str(photo.pk),
        expected_revision=str(photo.current_revision_id),
        file=upload_file(raster("JPEG"), "next.jpg", "image/jpeg"),
    )
    from evidencias.exceptions import RevisionConflict

    with pytest.raises(RevisionConflict):
        decide(
            scene[2].pk,
            case.pk,
            action="invalidate",
            reason="Synthetic old revision rejection",
            expected_version=1,
            expected_target_revision=case.target_revision,
            operation_id=uuid.uuid4(),
        )
    assert api(scene[1]).get(f"/api/denuncias/{case.pk}/").data["target_status"] == "changed"
    photo.refresh_from_db()
    assert photo.current_revision.state == "pending"


def test_c45_cleanup_command_has_bounded_batch_and_durable_effect(scene):
    from io import StringIO
    from django.core.management import call_command, CommandError

    photo, _ = send_photo(scene)
    asset = photo.current_revision.asset
    response = api(scene[0]).delete(
        f"/api/midia/fotos/{photo.pk}/",
        {
            "operation_id": uuid.uuid4(),
            "expected_revision": str(photo.current_revision_id),
        },
        format="json",
    )
    assert response.status_code == 200
    with pytest.raises(CommandError):
        call_command("reconcile_images", limit=0, stdout=StringIO())
    call_command("reconcile_images", limit=1, stdout=StringIO())
    assert ImageCleanup.objects.get(asset=asset).state == "done"
    assert not image_storage().exists(asset.image_key)
    call_command("reconcile_images", limit=1, stdout=StringIO())
    assert not image_storage().exists(asset.thumb_key)
