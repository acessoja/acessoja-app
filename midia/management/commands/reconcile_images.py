from django.core.management.base import BaseCommand, CommandError
from midia.cleanup import reconcile_images


class Command(BaseCommand):
    help = (
        "Reconciliar operações de imagem interrompidas e limpeza privada persistente."
    )

    def add_arguments(self, parser):
        parser.add_argument("--limit", type=int, default=50)

    def handle(self, *args, **options):
        limit = options["limit"]
        if not 1 <= limit <= 1000:
            raise CommandError("Use --limit entre 1 e 1000.")
        self.stdout.write(f"Limpezas concluídas: {reconcile_images(limit)}.")
