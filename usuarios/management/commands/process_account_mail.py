"""Run once (cron) or as the Compose worker. Never prints recipients or tokens."""
import time

from django.core.management.base import BaseCommand, CommandError

from usuarios.account_services import process_mail_jobs


class Command(BaseCommand):
    help = "Processar a fila privada de e-mails da conta (sem expor conteúdo)."

    def add_arguments(self, parser):
        parser.add_argument("--watch", action="store_true")
        parser.add_argument("--limit", type=int, default=100)

    def handle(self, *args, **options):
        if not 1 <= options["limit"] <= 1000:
            raise CommandError("Use --limit entre 1 e 1000.")
        while True:
            count = process_mail_jobs(options["limit"])
            if not options["watch"]:
                self.stdout.write(f"Jobs processados: {count}.")
                return
            time.sleep(2)
