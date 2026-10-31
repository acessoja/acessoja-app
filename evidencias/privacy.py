"""Card 36 integration: own exports; erase content while retaining anonymous case metadata."""

from collections import defaultdict

from django.db.models import Q

from .models import (
    ContentReport,
    EvidenceConfirmation,
    EvidenceOperation,
    EvidenceRevision,
    ModerationDecision,
    ResourceEvidence,
    ReviewRevision,
)


def own_export_queries(user):
    return {
        "statement_receipts": EvidenceOperation.objects.filter(owner=user).values(
            "operation_id", "evidence_id", "result_revision", "withdrawn", "created_at"
        ),
        "review_revisions": ReviewRevision.objects.filter(owner=user).values(
            "id", "payload", "recorded_at", "original_submission_at"
        ),
        "resource_revisions": EvidenceRevision.objects.filter(actor=user).values(
            "id",
            "evidence__resource",
            "state",
            "note",
            "observed_at",
            "observed_on",
            "received_at",
            "is_valid",
        ),
        "resource_confirmations": EvidenceConfirmation.objects.filter(user=user).values(
            "revision_id", "revision__evidence__resource", "confirmed_at", "observed_at", "observed_on"
        ),
        "submitted_reports": ContentReport.objects.filter(reporter=user).values(
            "protocol",
            "target_kind",
            "target_revision",
            "reason",
            "description",
            "state",
            "outcome",
            "created_at",
            "updated_at",
        ),
        # Internal rationale and other reporters are deliberately not part of an author's export.
        "moderation_activity": ModerationDecision.objects.filter(moderator=user).values(
            "action", "created_at", "previous_state", "next_state", "effect_applied"
        ),
    }


def erase_user_evidence(user):
    from modal_avaliacao.models import ReviewOperation

    EvidenceOperation.objects.filter(owner=user).delete()
    ReviewOperation.objects.filter(owner=user).delete()
    roots = list(ResourceEvidence.objects.filter(owner=user).select_for_update().order_by("pk"))
    ids = [root.pk for root in roots]
    own_targets = Q(review_revision__owner=user) | Q(evidence__owner=user) | Q(evidence_revision__actor=user)
    cases = list(ContentReport.objects.filter(own_targets).values_list("pk", flat=True))
    ModerationDecision.objects.filter(Q(report_id__in=cases) | Q(report__reporter=user) | Q(moderator=user)).update(
        reason="Dados pessoais removidos pelo procedimento de privacidade.", author_message=""
    )
    ContentReport.objects.filter(Q(pk__in=cases) | Q(reporter=user)).update(description="")
    for report in ContentReport.objects.filter(pk__in=cases):
        report.target_key = f"removed:{report.target_revision}"
        report.save(update_fields=["target_key"])
    EvidenceConfirmation.objects.filter(revision__evidence_id__in=ids).delete()
    EvidenceRevision.objects.filter(Q(evidence_id__in=ids) | Q(actor=user)).update(
        note="", observed_at=None, observed_on=None, source_metadata={}, actor=None
    )
    ReviewRevision.objects.filter(owner=user).update(payload={}, owner=None, original_submission_at=None)
    registered = defaultdict(set)
    for root in roots:
        if root.kind == "registration" and root.local_id:
            registered[root.local_id].add(root.resource)
        root.key = f"erased:{root.pk}"
        root.owner = None
        root.local = None
        root.review = None
        root.external_id = ""
        root.source_metadata = {}
        root.withdrawn = True
    if roots:
        ResourceEvidence.objects.bulk_update(
            roots, ["key", "owner", "local", "review", "external_id", "source_metadata", "withdrawn"]
        )
    from locais.models import Local

    for local in Local.objects.filter(pk__in=registered).order_by("pk").select_for_update():
        local.accessibility_information = {
            key: value for key, value in local.accessibility_information.items() if key not in registered[local.pk]
        }
        local.save(update_fields=["accessibility_information"])
