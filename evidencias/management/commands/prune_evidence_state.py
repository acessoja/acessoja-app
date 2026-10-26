from datetime import timedelta

from django.conf import settings
from django.core.management.base import BaseCommand
from django.db.models import Q, Subquery
from django.utils import timezone

from evidencias.models import (
    ContentReport,
    EvidenceRevision,
    ModerationDecision,
    ResourceEvidence,
    ReviewRevision,
)
from modal_avaliacao.models import ModalAvaliacao


class Command(BaseCommand):
    help = "Minimizar conteúdo de denúncias encerradas; restrições técnicas OSM permanecem independentes."

    def handle(self, *args, **options):
        now = timezone.now()
        stale = ContentReport.objects.filter(
            state="closed", updated_at__lt=now - timedelta(days=settings.REPORT_SNAPSHOT_RETENTION_DAYS)
        )
        count = stale.update(description="")
        ModerationDecision.objects.filter(report__in=stale).update(
            reason="Retenção: justificativa detalhada expurgada."
        )
        current = ModalAvaliacao.objects.values("content_revision")
        open_snapshots = ContentReport.objects.exclude(state="closed").values("review_revision_id")
        ReviewRevision.objects.exclude(pk__in=Subquery(current)).exclude(
            pk__in=Subquery(open_snapshots.filter(review_revision_id__isnull=False))
        ).filter(Q(reports__in=stale) | Q(captured_at__lt=now - timedelta(days=180))).update(payload={})
        current_resources = ResourceEvidence.objects.filter(current_revision__isnull=False).values(
            "current_revision_id"
        )
        open_resources = (
            ContentReport.objects.exclude(state="closed")
            .filter(evidence_revision__isnull=False)
            .values("evidence_revision_id")
        )
        EvidenceRevision.objects.exclude(pk__in=Subquery(current_resources)).exclude(
            pk__in=Subquery(open_resources)
        ).filter(captured_at__lt=now - timedelta(days=180)).update(
            note="", actor=None, observed_at=None, observed_on=None, source_metadata={}
        )
        # Ordinary Admin cannot delete audit rows. This operational retention path can.
        expired = ContentReport.objects.filter(
            state="closed", updated_at__lt=now - timedelta(days=settings.REPORT_AUDIT_RETENTION_DAYS)
        )
        decisions = ModerationDecision.objects.filter(report__in=expired).delete()[0]
        reports = expired.delete()[0]
        self.stdout.write(
            f"Relatos minimizados: {count}; decisões expiradas: {decisions}; protocolos expirados: {reports}."
        )
