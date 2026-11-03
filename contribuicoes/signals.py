from django.db.models.signals import post_delete, post_save, pre_delete
from django.dispatch import receiver

from evidencias.models import ModerationDecision
from modal_avaliacao.models import ModalAvaliacao
from .services import process_report_reward_for_decision, sync_evaluation


@receiver(pre_delete, sender=ModalAvaliacao)
def lock_review_author(sender, instance, using, **kwargs):
    from usuarios.models import Usuario

    # QuerySet.delete() is atomic and emits pre_delete before deleting rows.
    Usuario.objects.using(using).select_for_update().filter(pk=instance.user_id).first()


@receiver(post_save, sender=ModalAvaliacao)
def award_review(sender, instance, raw=False, **kwargs):
    if not raw:
        instance._contribution_changes = sync_evaluation(instance)


@receiver(post_save, sender=ModerationDecision)
def award_report_upheld(sender, instance, raw=False, **kwargs):
    if raw or instance.action != "invalidate" or not instance.effect_applied:
        return
    process_report_reward_for_decision(instance)


@receiver(post_delete, sender=ModalAvaliacao)
def revoke_review(sender, instance, **kwargs):
    from usuarios.models import Usuario

    if Usuario.objects.filter(pk=instance.user_id).exists():
        instance._contribution_changes = sync_evaluation(instance, deleted=True)
