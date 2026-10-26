from django.contrib.auth.models import Group, Permission
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from usuarios.models import Usuario


class Command(BaseCommand):
    help = "Conceder/revogar explicitamente a permissão de moderação; nenhuma senha é recebida ou emitida."

    def add_arguments(self, parser):
        parser.add_argument("--user", required=True)
        mode = parser.add_mutually_exclusive_group(required=True)
        mode.add_argument("--grant", action="store_true")
        mode.add_argument("--revoke", action="store_true")
        parser.add_argument("--enable-admin", action="store_true")

    @transaction.atomic
    def handle(self, *args, **options):
        user = Usuario.objects.select_for_update().filter(nome=options["user"], is_active=True).first()
        if user is None:
            raise CommandError("Conta ativa não encontrada.")
        permission = Permission.objects.filter(
            content_type__app_label="evidencias", codename="moderate_content"
        ).first()
        if permission is None:
            raise CommandError("Aplique as migrations antes de conceder a permissão.")
        group, _ = Group.objects.get_or_create(name="Moderadores AcessoJá")
        group.permissions.add(permission)
        if options["grant"]:
            user.groups.add(group)
            if options["enable_admin"]:
                user.is_staff = True
                user.save(update_fields=["is_staff"])
        else:
            user.groups.remove(group)
            user.user_permissions.remove(permission)
        self.stdout.write("Permissão atualizada. Staff isoladamente não concede moderação.")
