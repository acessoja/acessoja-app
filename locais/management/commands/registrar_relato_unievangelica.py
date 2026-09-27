from copy import deepcopy

from django.core.management.base import BaseCommand
from django.db import transaction
from locais.models import Local
from locais.serializers import LocalSerializer


class Command(BaseCommand):
    help = 'Registra o relato do responsável pelo cadastro sobre rampas e banheiros.'

    @transaction.atomic
    def handle(self, *args, **options):
        local = Local.objects.select_for_update().get(nome='UniEVANGÉLICA')
        guide = deepcopy(local.guia_visita)
        resources = guide.setdefault('recursos', {})
        for key, statement in {
            'rampa_acesso': 'O responsável pelo cadastro relata rampas de acesso em todos os blocos.',
            'banheiro_acessivel': (
                'O responsável pelo cadastro relata banheiros destinados a pessoas em cadeira de rodas'
                ' nos conjuntos de banheiros.'
            ),
        }.items():
            resources[key] = {
                'estado': 'disponivel',
                'observacao': (
                    statement + ' Data da observação não informada. Relato ainda sem verificação '
                    'presencial ou técnica pelo aplicativo.'
                ),
                'fonte': 'Relato do responsável pelo cadastro, fornecido na conversa do projeto',
                'atualizado_em': None,
            }
        serializer = LocalSerializer(local, data={'guia_visita': guide}, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        local.refresh_from_db()
        assert local.rampa_acesso and local.banheiro_acessivel
        self.stdout.write(f'Relato registrado e filtros sincronizados: id={local.pk}')
