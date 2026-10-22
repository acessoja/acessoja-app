"""Bound account operational metadata without deleting the current consent decision."""
from datetime import timedelta

from django.core.management.base import BaseCommand
from django.contrib.admin.models import LogEntry
from django.db.models import OuterRef, Subquery
from django.utils import timezone

from usuarios.models import AccountMailJob, PrivacyConsent


class Command(BaseCommand):
    help = "Remover jobs antigos e histórico de consentimento acima de 180 dias, mantendo a decisão vigente."

    def handle(self, *args, **options):
        now = timezone.now()
        jobs = AccountMailJob.objects.filter(created_at__lt=now - timedelta(days=1)).delete()[0]
        latest = PrivacyConsent.objects.filter(user_id=OuterRef("user_id"), purpose=OuterRef("purpose")).order_by(
            "-recorded_at", "-pk").values("pk")[:1]
        stale = PrivacyConsent.objects.filter(recorded_at__lt=now - timedelta(days=180)).exclude(pk=Subquery(latest))
        consents = stale.delete()[0]
        logs = LogEntry.objects.filter(action_time__lt=now - timedelta(days=14)).delete()[0]
        # Deletion receipts are pruned by the backup operator only after checking
        # the oldest restorable backup. A blind age-based delete can resurrect users.
        self.stdout.write(f"Jobs removidos: {jobs}; decisões antigas removidas: {consents}; logs removidos: {logs}.")
