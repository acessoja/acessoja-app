"""Writes lock authors first, then source/evidence, then cases and the existing ledger."""

from django.db import transaction
from django.db.models import Exists, OuterRef, Q, Value, DateTimeField
from django.db.models.functions import Coalesce
from django.utils import timezone
from rest_framework.exceptions import NotFound, ValidationError

from usuarios.account_services import locked_request_user
from usuarios.models import Usuario
from .capture import ANSWER_STATES, capture_batch
from .exceptions import RevisionConflict
from .models import ContentReport, EvidenceConfirmation, ResourceEvidence, ReviewRevision
from .projection import public_evidence


def lock_users(*ids):
    return list(
        Usuario.objects.filter(pk__in={value for value in ids if value is not None})
        .order_by("pk")
        .select_for_update()
    )


def current_public_query(local_ids=(), external_ids=()):
    from datetime import datetime, timezone as dt_timezone

    minimum = Value(datetime(1900, 1, 1, tzinfo=dt_timezone.utc), output_field=DateTimeField())
    rows = public_evidence(local_ids, external_ids).annotate(
        _stamp=Coalesce("current_revision__received_at", minimum)
    )
    newer = rows.filter(source="user", owner_id=OuterRef("owner_id"), resource=OuterRef("resource")).filter(
        Q(_stamp__gt=OuterRef("_stamp")) | Q(_stamp=OuterRef("_stamp"), pk__gt=OuterRef("pk"))
    )
    return rows.annotate(_superseded=Exists(newer)).filter(
        ~Q(source="user") | Q(owner__isnull=True) | Q(_superseded=False)
    )


def evidence_scope(row):
    from locais.models import Local

    local_ids = [row.local_id] if row.local_id else []
    external_ids = [row.external_id] if row.external_id else []
    if row.local_id:
        identity = Local.objects.filter(pk=row.local_id).values_list("osm_id", flat=True).first()
        if identity:
            external_ids.append(identity)
    elif row.external_id:
        local_ids.extend(Local.objects.filter(osm_id=row.external_id).values_list("pk", flat=True))
    return local_ids, external_ids


def public_target(evidence_id, expected=None, lock=False):
    root = ResourceEvidence.objects.select_related("current_revision").filter(pk=evidence_id).first()
    if root is None:
        raise NotFound("Informação indisponível.")
    ids, external = evidence_scope(root)
    if not current_public_query(ids, external).filter(pk=root.pk).exists():
        raise NotFound("Informação indisponível.")
    if lock:
        if root.review_id:
            from modal_avaliacao.models import ModalAvaliacao

            ModalAvaliacao.objects.select_for_update().filter(pk=root.review_id).first()
        if root.local_id and root.kind == "registration":
            from locais.models import Local

            Local.objects.select_for_update().filter(pk=root.local_id).first()
        root = (
            ResourceEvidence.objects.select_related("current_revision")
            .select_for_update(of=("self",))
            .get(pk=root.pk)
        )
        if not current_public_query(ids, external).filter(pk=root.pk).exists():
            raise NotFound("Informação indisponível.")
    if expected is not None and root.current_revision_id != expected:
        raise RevisionConflict()
    return root


def _owner(evidence_id):
    return ResourceEvidence.objects.filter(pk=evidence_id).values_list("owner_id", flat=True).first()


@transaction.atomic
def confirm_evidence(request, evidence_id, values):
    lock_users(request.user.pk, _owner(evidence_id))
    user = locked_request_user(request)
    root = public_target(evidence_id, values["revision"], lock=True)
    if root.current_revision.state == "unknown":
        raise ValidationError("Não há afirmação conhecida para confirmar.")
    confirmation, created = EvidenceConfirmation.objects.get_or_create(
        revision=root.current_revision,
        user=user,
        defaults={
            "observed_at": values.get("observed_at"),
            "observed_on": values.get("observed_on"),
            "confirmed_at": timezone.now(),
        },
    )
    if not created and (confirmation.observed_at, confirmation.observed_on) != (
        values.get("observed_at"),
        values.get("observed_on"),
    ):
        raise RevisionConflict(
            "Essa confirmação já foi registrada com outros dados. Atualize sua própria informação."
        )
    return {
        "confirmed": True,
        "repeated": not created,
        "confirmed_at": confirmation.confirmed_at,
        "revision": root.current_revision_id,
    }


@transaction.atomic
def change_evidence(request, evidence_id, values):
    lock_users(request.user.pk, _owner(evidence_id))
    user = locked_request_user(request)
    target = public_target(evidence_id, values["revision"], lock=True)
    place = f"local:{target.local_id}" if target.local_id else target.external_id
    specs = [
        {
            "key": f"observation:{user.pk}:{place}:{target.resource}",
            "kind": "observation",
            "source": "user",
            "resource": target.resource,
            "local_id": target.local_id,
            "external_id": target.external_id,
            "owner_id": user.pk,
            "state": ANSWER_STATES[values["value"]],
            "note": values.get("note", ""),
            "observed_at": values.get("observed_at"),
            "observed_on": values.get("observed_on"),
            "received_at": timezone.now(),
        }
    ]
    return capture_batch(specs)[0]


def review_is_public(review):
    return bool(
        review
        and review.is_current
        and review.is_valid
        and review.user.is_active
        and review.user.mostrar_avaliacoes
    )


@transaction.atomic
def create_report(request, values):
    from modal_avaliacao.models import ModalAvaliacao

    if values["target_kind"] == "review":
        review = ModalAvaliacao.objects.select_related("user").filter(pk=values["review_id"]).first()
        if not review_is_public(review):
            raise NotFound("Conteúdo indisponível.")
        owner_id = review.user_id
    else:
        owner_id = _owner(values["evidence_id"])
    lock_users(request.user.pk, owner_id)
    user = locked_request_user(request)
    if owner_id == user.pk:
        raise ValidationError("Para sua própria informação, use editar ou excluir.")
    defaults = {
        "target_kind": values["target_kind"],
        "reason": values["reason"],
        "description": values.get("description", ""),
    }
    if values["target_kind"] == "review":
        review = (
            ModalAvaliacao.objects.select_related("user")
            .select_for_update(of=("self",))
            .filter(pk=review.pk)
            .first()
        )
        if not review_is_public(review):
            raise NotFound("Conteúdo indisponível.")
        if review.content_revision != values["revision"]:
            raise RevisionConflict()
        revision = ReviewRevision.objects.get(pk=review.content_revision)
        key = f"review:{review.pk}"
        defaults["review_revision"] = revision
    else:
        root = public_target(values["evidence_id"], values["revision"], lock=True)
        if root.current_revision.state == "unknown":
            raise ValidationError("Não há afirmação conhecida para denunciar.")
        key = root.key
        defaults.update(evidence=root, evidence_revision=root.current_revision)
    report, created = ContentReport.objects.get_or_create(
        reporter=user, target_key=key, target_revision=values["revision"], defaults=defaults
    )
    report.repeated = not created
    report.target_status = "current"
    return report, created


def target_status(report):
    if report.target_kind == "review":
        review = report.review_revision.review if report.review_revision else None
        if not review_is_public(review):
            return "unavailable"
        current = review.content_revision
    else:
        root = report.evidence
        if (
            root is None
            or root.withdrawn
            or root.current_revision_id is None
            or not root.current_revision.is_valid
        ):
            return "unavailable"
        if root.local_id is None and not root.external_id:
            return "unavailable"
        if root.kind == "review" and not review_is_public(root.review):
            return "unavailable"
        if root.kind in {"review", "observation"} and (
            root.owner is None or not root.owner.is_active or not root.owner.mostrar_avaliacoes
        ):
            return "unavailable"
        current = root.current_revision_id
    return "current" if current == report.target_revision else "changed"


def reports_related(queryset):
    return queryset.select_related(
        "review_revision__review__user",
        "evidence__owner",
        "evidence__review__user",
        "evidence__current_revision",
    )
