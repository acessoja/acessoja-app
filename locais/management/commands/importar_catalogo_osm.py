from django.core.management.base import BaseCommand, CommandError

from locais.services.catalog_import import import_catalog


class Command(BaseCommand):
    help = "Importa PBF local para o catálogo municipal; nunca baixa dados ou cria contribuições."

    def add_arguments(self, parser):
        parser.add_argument("--arquivo", required=True)
        parser.add_argument("--limite", required=True)
        parser.add_argument("--municipio", default="5201108")
        parser.add_argument("--relatorio", required=True)
        parser.add_argument("--dry-run", action="store_true")
        parser.add_argument("--cobertura", help="Polígono .poly/GeoJSON do extrato completo, não o limite desejado.")
        parser.add_argument("--snapshot-completo", action="store_true")
        parser.add_argument(
            "--data-snapshot", help="ISO-8601 com fuso; deve coincidir com o cabeçalho quando presente."
        )
        parser.add_argument(
            "--decisao-data", default="", help="Justificativa para data ausente ou snapshot mais antigo."
        )
        parser.add_argument("--url-fonte", default="")
        parser.add_argument("--provedor", default="operator")
        parser.add_argument("--diretorio-temporario")
        parser.add_argument("--data-obtencao", help="Data ISO-8601 real de obtenção; não é inferida do mtime.")

    def handle(self, *args, **options):
        try:
            report = import_catalog(
                path=options["arquivo"],
                boundary_path=options["limite"],
                municipality=options["municipio"],
                report_path=options["relatorio"],
                dry_run=options["dry_run"],
                coverage_path=options["cobertura"],
                full_snapshot=options["snapshot_completo"],
                supplied_date=options["data_snapshot"],
                date_decision=options["decisao_data"],
                source_url=options["url_fonte"],
                provider=options["provedor"],
                work_directory=options["diretorio_temporario"],
                obtained_at=options["data_obtencao"],
            )
        except ImportError as exc:
            raise CommandError("Instale backend/requirements-catalog.txt no ambiente de importação.") from exc
        except Exception as exc:
            code = getattr(exc, "code", None) or "catalog_import_failed; confira o relatório"
            raise CommandError(code) from exc
        self.stdout.write(f"Catálogo: {report['result']}; {report['selection']['accepted']} POIs aceitos.")
