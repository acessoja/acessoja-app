from django.db.models.signals import post_delete, post_save, pre_delete
from django.dispatch import receiver

from modal_avaliacao.models import ModalAvaliacao
from .services import sync_evaluation


@receiver(pre_delete, sender=ModalAvaliacao)
def lock_review_author(sender, instance, using, **kwargs):
    from usuarios.models import Usuario

    # QuerySet.delete() is atomic and emits pre_delete before deleting rows.
    Usuario.objects.using(using).select_for_update().filter(pk=instance.user_id).first()


@receiver(post_save, sender=ModalAvaliacao)
def award_review(sender, instance, raw=False, **kwargs):
    if not raw:
        instance._contribution_changes = sync_evaluation(instance)


@receiver(post_delete, sender=ModalAvaliacao)
def revoke_review(sender, instance, **kwargs):
    from usuarios.models import Usuario

    if Usuario.objects.filter(pk=instance.user_id).exists():
        instance._contribution_changes = sync_evaluation(instance, deleted=True)
