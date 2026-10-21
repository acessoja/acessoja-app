from django.core.management.base import BaseCommand

from locais.services.catalog_geometry import write_json
from locais.services.catalog_metrics import measure_catalog


class Command(BaseCommand):
    help = "Mede tabelas/índices e projeções do catálogo no banco selecionado, sem alterar dados."

    def add_arguments(self, parser):
        parser.add_argument("--relatorio", required=True)

    def handle(self, *args, **options):
        result = measure_catalog()
        write_json(options["relatorio"], result)
        self.stdout.write(f"Medição: {result.get('catalog_bytes', 'indisponível')} bytes de catálogo.")
