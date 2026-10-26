"""Export one public active municipal OSM snapshot for a reproducible demo."""
from django.core.management.base import BaseCommand

from locais.services.catalog_seed_demo import save_seed


class Command(BaseCommand):
    help = "Exporta somente o catalogo OSM publico do lote ativo, sem dados de usuarios."

    def add_arguments(self, parser):
        parser.add_argument("--saida", default="dados_iniciais/catalogo_anapolis.json")

    def handle(self, *args, **options):
        count, sha = save_seed(options["saida"])
        self.stdout.write(self.style.SUCCESS(
            f"Exportados {count} estabelecimentos OSM. SHA-256 do conteudo: {sha}"
        ))
        self.stdout.write("Revise o arquivo e adicione APENAS o JSON ao Git; nunca o banco sqlite3.")
