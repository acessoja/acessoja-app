"""Reserve under author lock, decode/store outside transaction, then reauthorize and finalize."""

import base64
from datetime import timedelta
import hashlib
import json
import uuid

from django.conf import settings
from django.db import DatabaseError, transaction
from django.utils import timezone
from rest_framework.exceptions import NotFound, ValidationError
from evidencias.exceptions import RevisionConflict
from usuarios.account_services import locked_request_user
from usuarios.models import Usuario
from .cleanup import retire
from .exceptions import ImageUnavailable
from .models import ImageAsset, ImageOperation, PhotoRevision, ReviewPhoto
from .processing import process_image, read_input
from .storage import store_derivatives


def signature(payload):
    return hashlib.sha256(
        json.dumps(payload, sort_keys=True, default=str, separators=(",", ":")).encode()
    ).hexdigest()


def owned_review(user, identifier):
    from modal_avaliacao.models import ModalAvaliacao

    review = ModalAvaliacao.objects.filter(pk=identifier, user=user).select_for_update().first()
    if review is None:
        raise NotFound("Avaliação indisponível.")
    if not review.is_current or not review.is_valid:
        raise RevisionConflict("A avaliação não está disponível para anexos. Atualize os dados.")
    return review


def owned_photo(user, identifier):
    photo = ReviewPhoto.objects.filter(pk=identifier, owner=user, deleted_at=None).select_for_update().first()
    if photo is None:
        raise NotFound("Foto indisponível.")
    return photo


def check_revision(actual, expected):
    if actual != expected:
        raise RevisionConflict("O conteúdo mudou. Atualize os dados e confirme novamente.")


def operation_document(op):
    return {
        "operation_id": op.operation_id,
        "state": op.state,
        "photo_id": op.photo_id,
        "revision": op.result_revision,
        "can_retry": op.state == "failed",
    }


@transaction.atomic
def reserve(request, values, kind, digest):
    user = locked_request_user(request)
    review, photo = None, None
    if kind == "avatar":
        check_revision(user.avatar_version, values["expected_version"])
    else:
        review = owned_review(user, values["review_id"])
        check_revision(review.content_revision, values["review_revision"])
        if values.get("photo_id"):
            photo = owned_photo(user, values["photo_id"])
            if photo.review_id != review.pk:
                raise ValidationError("A foto não pode mudar de avaliação.")
            check_revision(photo.current_revision_id, values["expected_revision"])
    payload = {key: value for key, value in values.items() if key != "file"}
    fingerprint = signature({"kind": kind, "body": payload, "file_sha256": digest})
    op = (
        ImageOperation.objects.select_for_update()
        .filter(owner=user, operation_id=values["operation_id"])
        .first()
    )
    if op:
        if op.signature != fingerprint:
            raise RevisionConflict("Identidade de operação já usada com outro conteúdo.")
        if op.state == "committed" or op.state == "processing" and op.expires_at > timezone.now():
            return op, False
        retire(op.asset)
    if (
        ImageOperation.objects.filter(owner=user, state="processing", expires_at__gt=timezone.now())
        .exclude(pk=op.pk if op else None)
        .exists()
    ):
        raise RevisionConflict("Há outro envio em andamento. Consulte seu resultado antes de iniciar outro.")
    if review and photo is None:
        count = ReviewPhoto.objects.filter(review=review, deleted_at=None).count()
        if count >= settings.IMAGE_MAX_PHOTOS:
            raise ValidationError("Limite de cinco fotos por avaliação atingido.")
    asset_id = uuid.uuid4()
    prefix = f"{asset_id.hex[:2]}/{asset_id.hex}"
    asset = ImageAsset.objects.create(
        id=asset_id,
        owner=user,
        purpose="avatar" if kind == "avatar" else "photo",
        image_key=f"{prefix}/image.jpg",
        thumb_key=f"{prefix}/thumb.jpg",
    )
    if op is None:
        op = ImageOperation(owner=user, operation_id=values["operation_id"], kind=kind, signature=fingerprint)
    op.asset, op.review, op.photo = asset, review, photo
    op.state, op.lease = "processing", uuid.uuid4()
    op.expires_at, op.updated_at = timezone.now() + timedelta(seconds=120), timezone.now()
    op.save()
    return op, True


@transaction.atomic
def finalize(request, values, identifier, lease, result):
    user = locked_request_user(request)
    op = ImageOperation.objects.select_for_update().select_related("asset").get(pk=identifier, owner=user)
    if (
        op.state != "processing"
        or op.lease != lease
        or op.expires_at <= timezone.now()
        or op.asset.state != "preparing"
    ):
        raise RevisionConflict("A tentativa expirou. Consulte o estado da operação.")
    asset = op.asset
    asset.width, asset.height, asset.size, asset.sha256, asset.state = (
        result["width"],
        result["height"],
        len(result["image"]),
        result["sha256"],
        "ready",
    )
    asset.save(update_fields=["width", "height", "size", "sha256", "state"])
    if op.kind == "avatar":
        check_revision(user.avatar_version, values["expected_version"])
        old = user.avatar_asset
        user.avatar_asset, user.avatar_version = asset, uuid.uuid4()
        # Compatibility contract: this field remains base64, never a URL.
        user.foto_perfil = base64.b64encode(result["thumb"]).decode("ascii")
        user.save(update_fields=["avatar_asset", "avatar_version", "foto_perfil"])
        op.result_revision = user.avatar_version
        retire(old)
    else:
        review = owned_review(user, values["review_id"])
        check_revision(review.content_revision, values["review_revision"])
        if values.get("photo_id"):
            photo = owned_photo(user, values["photo_id"])
            check_revision(photo.current_revision_id, values["expected_revision"])
            old = photo.current_revision.asset
        else:
            if (
                ReviewPhoto.objects.filter(review=review, deleted_at=None).count()
                >= settings.IMAGE_MAX_PHOTOS
            ):
                raise ValidationError("Limite de fotos atingido.")
            photo, old = ReviewPhoto.objects.create(review=review, owner=user), None
        revision = PhotoRevision.objects.create(
            photo=photo, owner=user, asset=asset, description=values["description"]
        )
        photo.current_revision = revision
        photo.save(update_fields=["current_revision"])
        op.photo, op.result_revision = photo, revision.pk
        retire(old)
    op.state, op.updated_at = "committed", timezone.now()
    op.save(update_fields=["state", "updated_at", "photo", "result_revision"])
    return op


def abort(identifier, lease):
    try:
        owner_id = ImageOperation.objects.filter(pk=identifier).values_list("owner_id", flat=True).first()
        with transaction.atomic():
            Usuario.objects.select_for_update().filter(pk=owner_id).first()
            op = (
                ImageOperation.objects.select_for_update()
                .select_related("asset")
                .filter(pk=identifier, lease=lease, state="processing")
                .first()
            )
            if op:
                op.state = "failed"
                op.save(update_fields=["state"])
                retire(op.asset)
    except Exception:
        # The durable preparing asset/expired operation is reconciled by maintenance.
        pass


def upload_image(request, values, kind):
    with transaction.atomic():
        locked_request_user(request)
    content, suffix, mime = read_input(values["file"])
    # Consult completed retries before checking a superseded current avatar/review revision.
    payload = {key: value for key, value in values.items() if key != "file"}
    digest = hashlib.sha256(content).hexdigest()
    expected_signature = signature({"kind": kind, "body": payload, "file_sha256": digest})
    with transaction.atomic():
        user = locked_request_user(request)
        previous = ImageOperation.objects.filter(owner=user, operation_id=values["operation_id"]).first()
        if previous and previous.signature != expected_signature:
            raise RevisionConflict("Identidade de operação já usada com outro conteúdo.")
        if previous and previous.state == "committed":
            return previous
    op, start = reserve(request, values, kind, digest)
    if not start:
        return op
    try:
        result = process_image(content, suffix, mime, op.asset.purpose)
        store_derivatives(op.asset, result)
        return finalize(request, values, op.pk, op.lease, result)
    except (OSError, DatabaseError):
        abort(op.pk, op.lease)
        raise ImageUnavailable() from None
    except Exception:
        abort(op.pk, op.lease)
        raise


@transaction.atomic
def remove_avatar(request, values):
    user = locked_request_user(request)
    fingerprint = signature({"kind": "remove_avatar", **values})
    op = ImageOperation.objects.filter(owner=user, operation_id=values["operation_id"]).first()
    if op:
        if op.signature != fingerprint:
            raise RevisionConflict()
        return op
    check_revision(user.avatar_version, values["expected_version"])
    old = user.avatar_asset
    user.avatar_asset, user.avatar_version, user.foto_perfil = None, uuid.uuid4(), ""
    user.save(update_fields=["avatar_asset", "avatar_version", "foto_perfil"])
    op = ImageOperation.objects.create(
        owner=user,
        operation_id=values["operation_id"],
        kind="remove_avatar",
        signature=fingerprint,
        state="committed",
        expires_at=timezone.now(),
        result_revision=user.avatar_version,
    )
    retire(old)
    return op


@transaction.atomic
def change_description(request, photo_id, values):
    user = locked_request_user(request)
    # Author then review then photograph: same order as upload and moderation.
    target = ReviewPhoto.objects.filter(pk=photo_id, owner=user).first()
    if target is None:
        raise NotFound()
    owned_review(user, target.review_id)
    photo = owned_photo(user, photo_id)
    fingerprint = signature({"kind": "description", "photo": photo_id, **values})
    existing = ImageOperation.objects.filter(owner=user, operation_id=values["operation_id"]).first()
    if existing:
        if existing.signature != fingerprint:
            raise RevisionConflict()
        return existing
    check_revision(photo.current_revision_id, values["expected_revision"])
    current = photo.current_revision
    revision = PhotoRevision.objects.create(
        photo=photo, owner=user, asset=current.asset, description=values["description"]
    )
    photo.current_revision = revision
    photo.save(update_fields=["current_revision"])
    return ImageOperation.objects.create(
        owner=user,
        operation_id=values["operation_id"],
        kind="description",
        signature=fingerprint,
        state="committed",
        expires_at=timezone.now(),
        photo=photo,
        review=photo.review,
        result_revision=revision.pk,
    )


@transaction.atomic
def remove_photo(request, photo_id, values):
    user = locked_request_user(request)
    fingerprint = signature({"kind": "remove_photo", "photo": photo_id, **values})
    existing = ImageOperation.objects.filter(owner=user, operation_id=values["operation_id"]).first()
    if existing:
        if existing.signature != fingerprint:
            raise RevisionConflict()
        return existing
    target = ReviewPhoto.objects.filter(pk=photo_id, owner=user).first()
    if target is None:
        raise NotFound()
    from modal_avaliacao.models import ModalAvaliacao

    ModalAvaliacao.objects.select_for_update().filter(pk=target.review_id).first()
    photo = owned_photo(user, photo_id)
    check_revision(photo.current_revision_id, values["expected_revision"])
    photo.deleted_at = timezone.now()
    photo.save(update_fields=["deleted_at"])
    retire(photo.current_revision.asset)
    return ImageOperation.objects.create(
        owner=user,
        operation_id=values["operation_id"],
        kind="remove_photo",
        signature=fingerprint,
        state="committed",
        expires_at=timezone.now(),
        photo=photo,
        review=photo.review,
        result_revision=photo.current_revision_id,
    )
