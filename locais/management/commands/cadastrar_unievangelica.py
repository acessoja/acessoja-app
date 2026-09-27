import json
import unicodedata
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from locais.models import Local
from locais.serializers import LocalSerializer


class Command(BaseCommand):
    help = 'Cadastra o campus Anápolis com fontes oficiais consultadas em 26/09/2026.'

    @transaction.atomic
    def handle(self, *args, **options):
        # Never overwrite later community edits or duplicate an existing campus.
        for local in Local.objects.all():
            name = unicodedata.normalize('NFKD', local.nome).encode('ascii', 'ignore').decode().lower()
            address = unicodedata.normalize('NFKD', local.endereco).encode('ascii', 'ignore').decode().lower()
            matches_campus = (
                abs((local.latitude or 0) + 16.293057) < 0.02
                or 'anapolis' in address
            )
            if 'unievangelica' in name and matches_campus:
                self.stdout.write(f'Cadastro existente preservado: id={local.pk}')
                return
        path = Path(__file__).resolve().parents[2] / 'data' / 'unievangelica_anapolis.json'
        serializer = LocalSerializer(data=json.loads(path.read_text(encoding='utf-8')))
        if not serializer.is_valid():
            raise CommandError(str(serializer.errors))
        local = serializer.save()
        self.stdout.write(self.style.SUCCESS(f'UniEVANGÉLICA cadastrada: id={local.pk}'))
