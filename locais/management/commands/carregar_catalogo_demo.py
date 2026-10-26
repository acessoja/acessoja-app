"""Install a public municipal catalog snapshot, safely and idempotently."""
from django.core.management.base import BaseCommand, CommandError

from locais.services.catalog_seed_demo import import_public_catalog, read_seed


class Command(BaseCommand):
    help = "Carrega snapshot publico; recusa sobrescrever lote ativo ou contribuicoes existentes."

    def add_arguments(self, parser):
        parser.add_argument("--arquivo", default="dados_iniciais/catalogo_anapolis.json")
        parser.add_argument("--verificar", action="store_true")

    def handle(self, *args, **options):
        payload = read_seed(options["arquivo"])
        self.stdout.write(f"Arquivo validado: {len(payload['entries'])} registros OSM.")
        if options["verificar"]:
            self.stdout.write("Nenhum dado alterado (--verificar).")
            return
        try:
            result = import_public_catalog(payload)
        except CommandError:
            raise
        except Exception as exc:
            raise CommandError("Erro ao carregar catalogo. A transacao foi revertida.") from exc
        self.stdout.write(self.style.SUCCESS(
            f"Catalogo: {result['status']}; {result['count']} registros."
        ))
