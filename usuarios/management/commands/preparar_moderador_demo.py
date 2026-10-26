"""Provision a least-privilege demo moderator without storing passwords in Git."""
from django.conf import settings
from django.contrib.auth.models import Group, Permission
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from usuarios.models import Usuario


class Command(BaseCommand):
    help = (
        "Prepara qa_moderador em ambiente local com senha inutilizavel caso seja novo. "
        "Defina a senha localmente com changepassword qa_moderador."
    )

    def add_arguments(self, parser):
        parser.add_argument("--nome", default="qa_moderador")
        parser.add_argument("--email-demo", default="qa_moderador@example.invalid")

    @transaction.atomic
    def handle(self, *args, **options):
        if not settings.DEBUG or getattr(settings, "APP_ENV", "local") != "local":
            raise CommandError("Criacao de moderador de teste permitida apenas em ambiente local DEBUG=True.")
        name = options["nome"]
        if name != "qa_moderador":
            raise CommandError("Apenas qa_moderador e suportado neste bootstrap de teste.")
        permission = Permission.objects.filter(
            content_type__app_label="evidencias", codename="moderate_content"
        ).first()
        if permission is None:
            raise CommandError("Permissao inexistente: aplique as migrations dos Cards 38-41 primeiro.")
        user = Usuario.objects.select_for_update().filter(nome=name).first()
        created = user is None
        if created:
            # The reserved .invalid address is never routed to a real mailbox.
            if Usuario.objects.filter(email=options["email_demo"]).exists():
                raise CommandError("E-mail de demonstracao ja pertence a outra conta.")
            user = Usuario.objects.create_user(nome=name, email=options["email_demo"], password=None)
        if not user.is_active:
            raise CommandError("Conta qa_moderador esta desativada; nao sera reativada silenciosamente.")
        if not user.is_staff:
            user.is_staff = True
            user.save(update_fields=["is_staff"])
        group, _ = Group.objects.get_or_create(name="Moderadores AcessoJá")
        group.permissions.add(permission)
        user.groups.add(group)
        if not user.has_perm("evidencias.moderate_content"):
            # Permission caches on existing objects may be stale. Requery fresh.
            user = Usuario.objects.get(pk=user.pk)
            if not user.has_perm("evidencias.moderate_content"):
                raise CommandError("Permissao de moderacao nao foi concedida.")
        self.stdout.write(self.style.SUCCESS(
            "qa_moderador preparado (" + ("novo" if created else "existente") + "). "
            "Nao foi gerada nem alterada qualquer senha."
        ))
        if not user.has_usable_password():
            self.stdout.write(
                "Para entrar no Admin, execute em ambiente local: python manage.py changepassword qa_moderador"
            )
