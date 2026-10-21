from django.core.management.base import BaseCommand, CommandError


class Command(BaseCommand):
    help = "Converte a malha municipal IBGE 2024 em GeoJSON WGS84, sem GDAL nem rede."

    def add_arguments(self, parser):
        parser.add_argument("--arquivo", required=True)
        parser.add_argument("--municipio", default="5201108")
        parser.add_argument("--saida", required=True)

    def handle(self, *args, **options):
        try:
            from locais.services.catalog_geometry import prepare_ibge
            result = prepare_ibge(options["arquivo"], options["municipio"], options["saida"])
        except ImportError:
            raise CommandError("Instale backend/requirements-catalog.txt.") from None
        except (ValueError, OSError, KeyError):
            raise CommandError("Malha inválida ou município ausente; confira arquivo e código IBGE.") from None
        self.stdout.write(f"Limite preparado: {result['municipality']}; {result['source_crs']} → EPSG:4326 (x,y).")
