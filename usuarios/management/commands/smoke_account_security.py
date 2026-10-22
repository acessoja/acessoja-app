"""Synthetic isolated-restore acceptance path; never targets a real account."""
import os
from pathlib import Path
import tempfile

from django.conf import settings
from django.contrib.auth.tokens import default_token_generator
from django.core import mail
from django.core.cache import cache
from django.core.management.base import BaseCommand, CommandError
from django.test import override_settings
from djoser.utils import encode_uid
from rest_framework.test import APIClient

from usuarios.account_services import process_mail_jobs
from usuarios.deletion_journal import journal_identity
from usuarios.models import Usuario


class Command(BaseCommand):
    help = 'Validar login/exportação/reset/exclusão SOMENTE no PostgreSQL restaurado e com conta sintética.'

    def add_arguments(self, parser):
        parser.add_argument('--synthetic-isolated', action='store_true')
        parser.add_argument('--user', required=True)

    def handle(self, *args, **options):
        db = settings.DATABASES['default']
        if (not options['synthetic_isolated'] or db['ENGINE'] != 'django.db.backends.postgresql'
                or not str(db['NAME']).startswith('acessoja_restore_')):
            raise CommandError('Exige PostgreSQL acessoja_restore_* e --synthetic-isolated.')
        user = Usuario.objects.filter(nome=options['user']).first()
        password = os.environ.get('SYNTHETIC_SMOKE_PASSWORD', '')
        if (not user or not user.nome.startswith('synthetic-') or not user.email.endswith('@example.test')
                or not password or not user.check_password(password)):
            raise CommandError('Forneça conta sintética e SYNTHETIC_SMOKE_PASSWORD apenas no ambiente privado.')
        user_id = user.pk
        replacement = 'Synthetic-restore!87592'

        def require(condition):
            if not condition:
                raise CommandError('Falhou o smoke isolado. Não liberar a restauração.')

        with tempfile.TemporaryDirectory(prefix='acessoja-smoke-') as root, override_settings(
            EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend',
            DELETION_JOURNAL_DIR=Path(root) / 'journal', APP_ENV='local', ALLOWED_HOSTS=['testserver'],
            SECURE_SSL_REDIRECT=False,
        ):
            cache.clear()
            journal_identity(initialize=True)
            client = APIClient()
            login = client.post('/api/login/', {'nome': user.nome, 'password': password}, format='json')
            require(login.status_code == 200)
            client.credentials(HTTP_AUTHORIZATION=f'Token {login.json()["token"]}')
            require(client.post('/api/usuarios/me/data-export/',
                                {'current_password': password}, format='json').status_code == 200)
            public = APIClient()
            require(public.post('/auth/users/reset_password/', {'email': user.email}, format='json').status_code == 204)
            process_mail_jobs()
            require(bool(getattr(mail, 'outbox', [])))
            user.refresh_from_db()
            body = {'uid': encode_uid(user.pk), 'token': default_token_generator.make_token(user),
                    'new_password': replacement, 're_new_password': replacement}
            require(public.post('/auth/users/reset_password_confirm/', body, format='json').status_code == 204)
            require(client.get('/auth/users/me/').status_code == 401)
            require(public.post('/auth/users/reset_password_confirm/', body, format='json').status_code == 400)
            require(public.post('/api/login/', {'nome': user.nome,
                    'password': password}, format='json').status_code == 401)
            login = public.post('/api/login/', {'nome': user.nome, 'password': replacement}, format='json')
            require(login.status_code == 200)
            client.credentials(HTTP_AUTHORIZATION=f'Token {login.json()["token"]}')
            require(client.post('/api/usuarios/me/delete-account/',
                                {'current_password': replacement, 'confirm': True}, format='json').status_code == 204)
            require(not Usuario.objects.filter(pk=user_id).exists())
            require(client.get('/auth/users/me/').status_code == 401)
            cache.clear()
        self.stdout.write('Smoke isolado: login, exportação, reset, revogação e exclusão aprovados '
                          'com conta sintética.')
