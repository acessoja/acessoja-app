from django.db.models.signals import post_delete, post_save
from django.dispatch import receiver

from modal_avaliacao.models import ModalAvaliacao
from .services import sync_evaluation


@receiver(post_save, sender=ModalAvaliacao)
def award_review(sender, instance, raw=False, **kwargs):
    if not raw:
        sync_evaluation(instance)


@receiver(post_delete, sender=ModalAvaliacao)
def revoke_review(sender, instance, **kwargs):
    from usuarios.models import Usuario

    if Usuario.objects.filter(pk=instance.user_id).exists():
        sync_evaluation(instance, deleted=True)
