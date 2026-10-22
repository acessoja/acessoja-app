from django.core.management.base import BaseCommand, CommandError

from usuarios.deletion_journal import journal_identity


class Command(BaseCommand):
    help = "Inicializar diário SOMENTE de um piloto novo; nunca substituir um diário perdido."

    def add_arguments(self, parser):
        parser.add_argument("--new-pilot", action="store_true")

    def handle(self, *args, **options):
        if not options["new_pilot"]:
            raise CommandError("Exige --new-pilot. Para recuperação, use o diário independente original e atual.")
        self.stdout.write(f"Diário de exclusões: {journal_identity(initialize=True)}")
