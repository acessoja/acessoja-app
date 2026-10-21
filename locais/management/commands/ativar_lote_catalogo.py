from django.core.management.base import BaseCommand, CommandError

from locais.services.catalog_publication import reactivate_batch


class Command(BaseCommand):
    help = "Ativa edição previamente validada, preservando Local, avaliações, favoritos e vínculos atuais."

    def add_arguments(self, parser):
        parser.add_argument("lote")
        parser.add_argument("--motivo", required=True)

    def handle(self, *args, **options):
        try:
            reactivate_batch(options["lote"], options["motivo"])
        except Exception as exc:
            raise CommandError("Ativação recusada: confira lote, motivo e importação concorrente.") from exc
        self.stdout.write("Edição ativada; dados comunitários preservados.")
