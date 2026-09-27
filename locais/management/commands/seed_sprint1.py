from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand
from django.utils import timezone

from locais.models import Local


DEMO_PLACES = [
    {
        'nome': '[Sprint 1] Local Centro',
        'endereco': 'Ponto de demonstração - Centro, Anápolis - GO',
        'distancia': 0,
        'latitude': -16.3267,
        'longitude': -48.9528,
        'aberto': True,
        'imagem': '',
        'cao_guia': True,
        'mesa_acessivel': True,
        'banheiro_acessivel': True,
        'rampa_acesso': True,
        'cardapio_braille': False,
    },
    {
        'nome': '[Sprint 1] Local Jundiaí',
        'endereco': 'Ponto de demonstração - Jundiaí, Anápolis - GO',
        'distancia': 0,
        'latitude': -16.3310,
        'longitude': -48.9440,
        'aberto': True,
        'imagem': '',
        'cao_guia': True,
        'mesa_acessivel': False,
        'banheiro_acessivel': True,
        'rampa_acesso': True,
        'cardapio_braille': False,
    },
    {
        'nome': '[Sprint 1] Local Universitário',
        'endereco': 'Ponto de demonstração - Bairro Universitário, Anápolis - GO',
        'distancia': 0,
        'latitude': -16.3150,
        'longitude': -48.9460,
        'aberto': False,
        'imagem': '',
        'cao_guia': True,
        'mesa_acessivel': True,
        'banheiro_acessivel': False,
        'rampa_acesso': False,
        'cardapio_braille': True,
    },
]


class Command(BaseCommand):
    help = 'Cria locais e, opcionalmente, um usuário de demonstração da Sprint 1.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--with-user',
            action='store_true',
            help='Cria/atualiza o usuário teste_sprint1 com senha Teste123!.',
        )
        parser.add_argument(
            '--clear',
            action='store_true',
            help='Remove os locais de demonstração antes de recriá-los.',
        )

    def handle(self, *args, **options):
        names = [item['nome'] for item in DEMO_PLACES]
        if options['clear']:
            removed, _ = Local.objects.filter(nome__in=names).delete()
            self.stdout.write(f'Registros de demonstração removidos: {removed}')

        created_count = 0
        updated_count = 0
        for data in DEMO_PLACES:
            defaults = dict(data)
            nome = defaults.pop('nome')
            _, created = Local.objects.update_or_create(
                nome=nome,
                defaults=defaults,
            )
            if created:
                created_count += 1
            else:
                updated_count += 1

        self.stdout.write(
            self.style.SUCCESS(
                f'Locais Sprint 1 prontos: {created_count} criados, '
                f'{updated_count} atualizados.'
            )
        )

        if options['with_user']:
            User = get_user_model()
            user = User.objects.filter(nome='teste_sprint1').first()
            if user is None:
                user = User.objects.create_user(
                    nome='teste_sprint1',
                    email='teste_sprint1@acessoja.local',
                    password='Teste123!',
                )
            else:
                user.email = 'teste_sprint1@acessoja.local'
                user.data_criacao = user.data_criacao or timezone.now()
                user.set_password('Teste123!')
                user.save()
            self.stdout.write(
                self.style.SUCCESS(
                    'Usuário de teste pronto: teste_sprint1 / Teste123!'
                )
            )
