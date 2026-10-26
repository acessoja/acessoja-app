"""One transactional decision path for Admin and any future supported consumer."""

import hashlib
import json
import logging
import uuid

from django.core.cache import cache
from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import NotFound, PermissionDenied, ValidationError

from usuarios.models import Usuario
from .exceptions import RevisionConflict
from .models import (
    ContentReport,
    EvidenceRevision,
    GUIDANCE,
    ModerationDecision,
    OPEN_STATES,
    ResourceEvidence,
)
from .services import lock_users, reports_related, target_status

logger = logging.getLogger("acessoja.security")


def allowed(user):
    return bool(
        user and user.is_active and (user.is_superuser or user.has_perm("evidencias.moderate_content"))
    )


def publication_changed():
    # Public projections always read current database validity, even if this hint fails.
    try:
        if not cache.add("evidence-publication-revision", 1, timeout=None):
            cache.incr("evidence-publication-revision")
    except Exception:
        logger.warning("publication_hint_failed", extra={"security_event": "application_event"})


@transaction.atomic
def decide(
    actor_id,
    protocol,
    *,
    action,
    reason,
    expected_version,
    expected_target_revision,
    operation_id,
    author_message=""
):
    actor = Usuario.objects.filter(pk=actor_id, is_active=True).first()
    if not allowed(actor):
        raise PermissionDenied("Permissão específica de moderação necessária.")
    if action not in {"start", "keep", "invalidate", "request_review", "unavailable"}:
        raise ValidationError("Decisão inválida.")
    reason, author_message = reason.strip(), author_message.strip()
    if not 10 <= len(reason) <= 1000:
        raise ValidationError("Justifique a decisão com 10 a 1000 caracteres.")
    if (
        author_message
        and author_message not in GUIDANCE
        or action == "request_review"
        and author_message not in GUIDANCE
    ):
        raise ValidationError("Escolha uma orientação padronizada ao autor, sem dados do denunciante.")
    try:
        operation_id, expected_target_revision = uuid.UUID(str(operation_id)), uuid.UUID(
            str(expected_target_revision)
        )
    except (ValueError, TypeError):
        raise ValidationError("Identificação da operação/revisão inválida.") from None
    signature = hashlib.sha256(
        json.dumps(
            {
                "actor": actor_id,
                "protocol": str(protocol),
                "action": action,
                "reason": reason,
                "expected_version": expected_version,
                "expected_target": str(expected_target_revision),
                "author_message": author_message,
            },
            sort_keys=True,
        ).encode()
    ).hexdigest()
    existing = ModerationDecision.objects.filter(report_id=protocol, operation_id=operation_id).first()
    if existing:
        if existing.request_fingerprint != signature or existing.moderator_id != actor_id:
            raise RevisionConflict("Chave de operação já utilizada com outros dados.")
        return existing
    report = reports_related(ContentReport.objects.all()).filter(pk=protocol).first()
    if report is None:
        raise NotFound()
    owner_id = (
        report.review_revision.owner_id
        if report.review_revision
        else report.evidence.owner_id if report.evidence else None
    )
    lock_users(actor_id, owner_id)
    # Account deletion can anonymize a report while this transaction waits
    # for its owner's row lock. Reload the report before using target_key
    # for the ordered case locks; the pre-lock value may now be obsolete.
    report = reports_related(ContentReport.objects.all()).filter(pk=protocol).first()
    if report is None:
        raise RevisionConflict("O processo foi removido durante a análise.")
    actor = Usuario.objects.get(pk=actor_id)
    if not allowed(actor):
        raise PermissionDenied("Permissão de moderação removida.")
    if report.review_revision and report.review_revision.review_id:
        from modal_avaliacao.models import ModalAvaliacao

        ModalAvaliacao.objects.select_for_update().filter(pk=report.review_revision.review_id).first()
    if report.evidence_id:
        root = report.evidence
        if root.kind == "osm":
            from .capture import lock_external_sources

            lock_external_sources([(root.external_id, root.resource)])
            list(
                ResourceEvidence.objects.filter(
                    kind="osm", external_id=root.external_id, resource=root.resource
                )
                .order_by("key")
                .select_for_update()
            )
        if root.review_id:
            from modal_avaliacao.models import ModalAvaliacao

            ModalAvaliacao.objects.select_for_update().filter(pk=root.review_id).first()
        elif root.kind == "registration" and root.local_id:
            from locais.models import Local

            Local.objects.select_for_update().filter(pk=root.local_id).first()
        ResourceEvidence.objects.select_for_update().filter(pk=root.pk).first()
    # Lock the entire same-target case set in a stable order, including removed targets.
    cases = list(
        ContentReport.objects.filter(target_key=report.target_key, target_revision=report.target_revision)
        .order_by("protocol")
        .select_for_update()
    )
    report = next(row for row in cases if row.pk == report.pk)
    existing = ModerationDecision.objects.filter(report=report, operation_id=operation_id).first()
    if existing:
        if existing.request_fingerprint != signature or existing.moderator_id != actor_id:
            raise RevisionConflict()
        return existing
    if (
        report.version != expected_version
        or report.state == "closed"
        or report.target_revision != expected_target_revision
    ):
        raise RevisionConflict(
            "Este processo já foi atualizado. Reabra a análise para conferir o estado atual."
        )
    fresh = reports_related(ContentReport.objects.all()).get(pk=report.pk)
    availability = target_status(fresh)
    if action == "unavailable":
        if availability == "current":
            raise ValidationError(
                "O alvo ainda está disponível nesta revisão. Escolha uma decisão de análise."
            )
    elif availability != "current":
        raise RevisionConflict(
            "O conteúdo foi alterado ou está indisponível. Não aplique a medida à versão nova."
        )
    if action == "start" and report.state != "pending":
        raise RevisionConflict("A análise já foi iniciada.")
    effect = False
    if action == "invalidate":
        if report.target_kind == "review":
            from modal_avaliacao.models import ModalAvaliacao

            review = ModalAvaliacao.objects.get(pk=fresh.review_revision.review_id)
            if review.content_revision != report.target_revision:
                raise RevisionConflict()
            if review.is_valid:
                review.is_valid = False
                review.save(update_fields=["is_valid"])  # Existing sync_evaluation/signals, same transaction.
                effect = True
        else:
            root = ResourceEvidence.objects.select_related("current_revision").get(pk=report.evidence_id)
            if root.current_revision_id != report.target_revision:
                raise RevisionConflict()
            effect = bool(
                EvidenceRevision.objects.filter(pk=root.current_revision_id, is_valid=True).update(
                    is_valid=False
                )
            )
            if root.kind == "osm":
                # Denial follows the external assertion across provider channels, including reimports.
                EvidenceRevision.objects.filter(
                    evidence__kind="osm",
                    evidence__external_id=root.external_id,
                    evidence__resource=root.resource,
                    fingerprint=root.current_revision.fingerprint,
                ).update(is_valid=False)
    next_state = {"start": "reviewing", "request_review": "revision_requested"}.get(action, "closed")
    affected = [row for row in cases if row.state in OPEN_STATES] if action == "invalidate" else [report]
    primary = None
    for case in affected:
        decision = ModerationDecision.objects.create(
            report=case,
            operation_id=operation_id,
            request_fingerprint=signature,
            moderator=actor,
            action=action,
            reason=reason,
            author_message=author_message,
            target_revision=case.target_revision,
            previous_state=case.state,
            next_state=next_state,
            effect_applied=effect and case.pk == report.pk,
        )
        case.state, case.outcome = next_state, action if next_state == "closed" else ""
        case.version += 1
        case.updated_at = timezone.now()
        case.save(update_fields=["state", "outcome", "version", "updated_at"])
        if case.pk == report.pk:
            primary = decision
    transaction.on_commit(publication_changed)
    return primary
