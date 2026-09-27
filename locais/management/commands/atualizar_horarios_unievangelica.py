import json
from copy import deepcopy
from pathlib import Path
from django.core.management.base import BaseCommand
from django.db import transaction
from locais.models import Local
from locais.serializers import LocalSerializer


class Command(BaseCommand):
    help = 'Atualiza apenas os horários de setores publicados nas páginas oficiais.'

    @transaction.atomic
    def handle(self, *args, **options):
        path = Path(__file__).resolve().parents[2] / 'data' / 'unievangelica_anapolis.json'
        seed = json.loads(path.read_text(encoding='utf-8'))
        local = Local.objects.select_for_update().get(nome='UniEVANGÉLICA')
        guide = deepcopy(local.guia_visita)
        guide['horarios'] = seed['guia_visita']['horarios']
        serializer = LocalSerializer(local, data={'guia_visita': guide}, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        self.stdout.write(f'Horários dos setores atualizados: id={local.pk}')
