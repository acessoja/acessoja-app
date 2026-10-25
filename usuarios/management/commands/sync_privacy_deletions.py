"""Reconcile filesystem intents against the authoritative LIVE database only."""
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from usuarios.deletion_journal import read_receipts, write_receipt
from usuarios.models import AccountDeletionReceipt, Usuario


class Command(BaseCommand):
    help = "Sincronizar recibos de exclusão; exige o banco ativo, nunca um banco restaurado."

    def add_arguments(self, parser):
        parser.add_argument("--authoritative-live-database", action="store_true")

    def handle(self, *args, **options):
        if not options["authoritative_live_database"]:
            raise CommandError("Confirme o banco ativo com --authoritative-live-database.")
        count = 0
        for record in read_receipts():
            if record["state"] != "pending":
                continue
            with transaction.atomic():
                user = Usuario.objects.select_for_update().filter(privacy_id=record["privacy_id"]).first()
                receipt = AccountDeletionReceipt.objects.filter(pk=record["operation_id"]).first()
                if receipt:
                    write_receipt(receipt, "committed")
                    AccountDeletionReceipt.objects.filter(pk=receipt.pk).update(published=True)
                elif user:
                    receipt = AccountDeletionReceipt(operation_id=record["operation_id"],
                                                     privacy_id=record["privacy_id"], deleted_at=record["deleted_at"])
                    # A completed owner lock proves the original deletion rolled back.
                    # Parse the ISO date for journal serialization.
                    from datetime import datetime
                    receipt.deleted_at = datetime.fromisoformat(record["deleted_at"])
                    write_receipt(receipt, "cancelled")
                else:
                    raise CommandError("Recibo inconclusivo: revisão operacional obrigatória; restauração bloqueada.")
            count += 1
        self.stdout.write(f"Recibos reconciliados: {count}.")
