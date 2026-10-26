from django.db.models.signals import post_save
from django.dispatch import receiver

from locais.models import Local
from modal_avaliacao.models import ModalAvaliacao
from .capture import capture_registration, capture_review


@receiver(post_save, sender=ModalAvaliacao)
def capture_review_write(sender, instance, raw=False, **kwargs):
    if not raw:
        capture_review(instance)


@receiver(post_save, sender=Local)
def capture_registration_write(sender, instance, raw=False, created=False, update_fields=None, **kwargs):
    if not raw and (update_fields is None or "accessibility_information" in update_fields):
        if instance.accessibility_information or not created:
            capture_registration(instance)
