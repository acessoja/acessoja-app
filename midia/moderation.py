import uuid
from django.db import transaction
from rest_framework.exceptions import NotFound, PermissionDenied, ValidationError
from evidencias.exceptions import RevisionConflict
from evidencias.moderation import allowed, publication_changed
from evidencias.services import lock_users
from usuarios.models import Usuario
from .models import ImageDecision, PhotoRevision, ReviewPhoto
from .services import signature


def photo_target(identifier, expected=None, lock=False, public=True):
    from .permissions import public_photos

    rows = public_photos() if public else ReviewPhoto.objects.filter(deleted_at=None)
    photo = rows.select_related("current_revision__asset", "review__user").filter(pk=identifier).first()
    if photo is None:
        raise NotFound("Imagem indisponível.")
    if lock:
        from modal_avaliacao.models import ModalAvaliacao

        ModalAvaliacao.objects.select_for_update().filter(pk=photo.review_id).first()
        ReviewPhoto.objects.select_for_update().get(pk=photo.pk)
        photo = rows.select_related("current_revision__asset", "review__user").filter(pk=identifier).first()
        if photo is None:
            raise NotFound("Imagem indisponível.")
    if expected is not None and photo.current_revision_id != expected:
        raise RevisionConflict()
    return photo


def apply_decision_locked(
    actor, revision, action, reason, operation_id, fingerprint, report=None, author_reason="context"
):
    prior = revision.state
    next_state = "approved" if action == "approve" else "rejected"
    PhotoRevision.objects.filter(pk=revision.pk).update(
        state=next_state, moderation_version=revision.moderation_version + 1
    )
    decision = ImageDecision.objects.create(
        revision=revision,
        moderator=actor,
        report=report,
        operation_id=operation_id,
        signature=fingerprint,
        action=action,
        reason=reason,
        author_reason=author_reason,
        previous_state=prior,
        next_state=next_state,
    )
    # The decision and its ledger effects commit together, with author locks held.
    from contribuicoes.services import sync_evaluation

    if revision.photo_id:
        sync_evaluation(revision.photo.review)
    return decision


@transaction.atomic
def decide_photo(
    actor_id, photo_id, *, revision_id, expected_version, operation_id, action, reason, author_reason="context"
):
    actor = Usuario.objects.filter(pk=actor_id, is_active=True).first()
    if not allowed(actor):
        raise PermissionDenied()
    if action not in {"approve", "reject"} or not 10 <= len(reason.strip()) <= 1000:
        raise ValidationError("Escolha aprovar/rejeitar e justifique com 10 a 1000 caracteres.")
    if author_reason not in dict(ImageDecision._meta.get_field("author_reason").choices):
        raise ValidationError("Escolha uma orientação pública válida para o autor.")
    try:
        operation_id, revision_id = uuid.UUID(str(operation_id)), uuid.UUID(str(revision_id))
    except (ValueError, TypeError):
        raise ValidationError("Identificação inválida.") from None
    photo = ReviewPhoto.objects.filter(pk=photo_id).first()
    if photo is None:
        raise NotFound()
    lock_users(actor_id, photo.owner_id)
    actor = Usuario.objects.get(pk=actor_id)
    if not allowed(actor):
        raise PermissionDenied()
    fingerprint = signature(
        {
            "actor": actor_id,
            "photo": photo_id,
            "revision": revision_id,
            "version": expected_version,
            "action": action,
            "reason": reason.strip(),
            "author_reason": author_reason,
        }
    )
    prior = ImageDecision.objects.filter(revision_id=revision_id, operation_id=operation_id).first()
    if prior:
        if prior.signature != fingerprint:
            raise RevisionConflict()
        return prior
    photo = photo_target(photo_id, revision_id, lock=True, public=False)
    revision = photo.current_revision
    if revision.moderation_version != expected_version:
        raise RevisionConflict()
    if action == "approve" and (
        revision.asset.state != "ready"
        or not photo.review.is_current
        or not photo.review.is_valid
        or not photo.review.user.is_active
    ):
        raise RevisionConflict("A avaliação ou arquivo não está disponível para aprovação.")
    result = apply_decision_locked(
        actor, revision, action, reason.strip(), operation_id, fingerprint, author_reason=author_reason
    )
    transaction.on_commit(publication_changed)
    return result


def report_photo_status(report):
    revision = report.photo_revision
    photo = revision.photo if revision else None
    if (
        photo is None
        or photo.deleted_at
        or not photo.review.is_current
        or not photo.review.is_valid
        or not photo.review.user.is_active
        or not photo.review.user.mostrar_avaliacoes
    ):
        return "unavailable"
    if photo.current_revision_id != report.target_revision:
        return "changed"
    return "current" if revision.state == "approved" and revision.asset.state == "ready" else "unavailable"
