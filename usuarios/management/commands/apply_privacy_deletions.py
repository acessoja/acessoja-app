"""Apply independently retained deletion receipts BEFORE exposing a restored DB."""
from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from usuarios.deletion_journal import read_receipts
from usuarios.models import AccountDeletionReceipt, Usuario
from usuarios.privacy_services import erase_relations


class Command(BaseCommand):
    help = "Aplicar exclusões no banco de restauração ISOLADO antes de permitir acesso."

    def add_arguments(self, parser):
        parser.add_argument("--isolated-restore", action="store_true")

    def handle(self, *args, **options):
        if not options["isolated_restore"]:
            raise CommandError("Exige --isolated-restore e banco de recuperação isolado.")
        db = settings.DATABASES["default"]
        name = str(db["NAME"])
        if db["ENGINE"] != "django.db.backends.postgresql" or not name.startswith("acessoja_restore_"):
            raise CommandError("O banco PostgreSQL deve começar com acessoja_restore_.")
        records = read_receipts()
        if any(record["state"] == "pending" for record in records):
            raise CommandError("Há recibos pendentes. Reconcilie no banco ativo antes de restaurar.")
        ids = {record["privacy_id"] for record in records if record["state"] == "committed"}
        ids.update(str(value) for value in AccountDeletionReceipt.objects.values_list("privacy_id", flat=True))
        count = 0
        with transaction.atomic():
            for user in Usuario.objects.select_for_update().filter(privacy_id__in=ids):
                erase_relations(user)
                count += 1
            # Restored credentials and queued resets must never reactivate old sessions.
            from rest_framework.authtoken.models import Token
            from django.contrib.sessions.models import Session
            from usuarios.models import AccountMailJob
            Token.objects.all().delete()
            Session.objects.all().delete()
            AccountMailJob.objects.all().delete()
        self.stdout.write(f"Contas suprimidas na restauração: {count}; instante: {timezone.now().isoformat()}.")
