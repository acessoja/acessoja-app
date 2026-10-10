from django.core.management.base import BaseCommand
from modal_avaliacao.models import ModalAvaliacao
from contribuicoes.services import sync_evaluation


class Command(BaseCommand):
    help = "Reconcilia eventos idempotentes sem validar autoria histórica nem apagar avaliações."

    def handle(self, *args, **options):
        for review in ModalAvaliacao.objects.filter(verified_author=True).iterator():
            sync_evaluation(review)
        self.stdout.write(self.style.SUCCESS("Contribuições reconciliadas."))
