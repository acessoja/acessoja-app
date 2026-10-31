from django.db.models.signals import post_delete, post_save, pre_delete
from django.dispatch import receiver
from .models import ReviewPhoto


@receiver(post_save, sender=ReviewPhoto)
@receiver(post_delete, sender=ReviewPhoto)
def sync_photo_points(sender, instance, **kwargs):
    from contribuicoes.services import sync_evaluation
    from modal_avaliacao.models import ModalAvaliacao

    if kwargs.get("signal") is post_delete:
        origin = kwargs.get("origin")
        if getattr(origin, "model", type(origin)) is not ReviewPhoto:
            # A parent's collector already detached ledger FKs. Its own signal
            # reconciles after deletion; never reattach a soon-deleted review.
            return
    review = ModalAvaliacao.objects.filter(pk=instance.review_id).first()
    if review:
        sync_evaluation(review)


@receiver(pre_delete, sender=ReviewPhoto)
def retire_photo_before_delete(sender, instance, **kwargs):
    from usuarios.models import Usuario
    from modal_avaliacao.models import ModalAvaliacao

    Usuario.objects.select_for_update().filter(pk=instance.owner_id).first()
    ModalAvaliacao.objects.select_for_update().filter(pk=instance.review_id).first()
    from .models import ImageAsset, ImageCleanup

    if instance.current_revision_id:
        asset_id = instance.current_revision.asset_id
        ImageAsset.objects.filter(pk=asset_id).update(state="retired")
        ImageCleanup.objects.get_or_create(asset_id=asset_id)
