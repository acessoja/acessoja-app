import json

from django.core.management.base import BaseCommand, CommandError
from usuarios.models import Usuario
from modal_avaliacao.models import ModalAvaliacao
from contribuicoes.models import ContributionPointEvent, UserAchievement
from contribuicoes.services import reconcile_user


class Command(BaseCommand):
    help = "Simula a reconciliação. Use --apply após revisar; autoria histórica nunca é promovida."

    def add_arguments(self, parser):
        modes = parser.add_mutually_exclusive_group()
        modes.add_argument("--dry-run", action="store_true", help="Simular sem gravar (padrão).")
        modes.add_argument("--apply", action="store_true", help="Aplicar os ajustes transacionais revisados.")
        parser.add_argument("--user-id", action="append", type=int, help="Restringir a um usuário; pode repetir.")
        parser.add_argument("--json", action="store_true", help="Emitir relatório JSON para revisão.")

    def handle(self, *args, **options):
        requested = options.get("user_id")
        if requested:
            ids = set(Usuario.objects.filter(pk__in=requested).values_list("pk", flat=True))
            if ids != set(requested):
                raise CommandError("Um dos usuários informados não existe; nenhuma correção foi aplicada.")
        else:
            ids = set(ModalAvaliacao.objects.values_list("user_id", flat=True))
            ids.update(ContributionPointEvent.objects.values_list("user_id", flat=True))
            ids.update(UserAchievement.objects.values_list("user_id", flat=True))
        rows = [reconcile_user(user_id, apply=options["apply"]) for user_id in sorted(ids)]
        report = {
            "mode": "apply" if options["apply"] else "dry_run",
            "users_examined": len(rows),
            "events_changed": sum(row["events_changed"] for row in rows),
            "achievements_changed": sum(row["achievements_changed"] for row in rows),
            "users": rows,
        }
        if options["json"]:
            self.stdout.write(json.dumps(report, ensure_ascii=False))
        else:
            mode = "Aplicação concluída" if options["apply"] else "Simulação; nenhuma alteração gravada"
            self.stdout.write(
                f"{mode}: {report['events_changed']} eventos, {report['achievements_changed']} conquistas."
            )
            for row in rows:
                if row["events_changed"] or row["achievements_changed"] or row["unknown_actions"]:
                    self.stdout.write(
                        f"Usuário {row['user_id']}: saldo {row['points_before']} -> {row['points_after']}; "
                        f"{row['events_changed']} ajustes; ações não reconhecidas: {row['unknown_actions']}."
                    )
            if not options["apply"]:
                self.stdout.write("Revise o relatório e utilize --apply para confirmar os ajustes.")
