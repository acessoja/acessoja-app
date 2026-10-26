"""The demo role is reproducible without distributing a reusable password."""
from django.core.management import call_command
from django.test import TestCase, override_settings

from usuarios.models import Usuario


class ModeratorBootstrapTests(TestCase):
    @override_settings(DEBUG=True, APP_ENV="local")
    def test_provisioning_twice_keeps_password_unusable_and_least_privilege(self):
        call_command("preparar_moderador_demo")
        user = Usuario.objects.get(nome="qa_moderador")
        self.assertTrue(user.is_staff)
        self.assertFalse(user.is_superuser)
        self.assertFalse(user.has_usable_password())
        self.assertTrue(user.has_perm("evidencias.moderate_content"))
        call_command("preparar_moderador_demo")
        self.assertEqual(Usuario.objects.filter(nome="qa_moderador").count(), 1)

    @override_settings(DEBUG=False, APP_ENV="staging")
    def test_no_admin_provisioning_in_staging(self):
        from django.core.management.base import CommandError
        with self.assertRaises(CommandError):
            call_command("preparar_moderador_demo")
