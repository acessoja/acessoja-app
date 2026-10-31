from django.db import transaction
from django.utils import timezone
from .models import ImageAsset, ImageCleanup, ImageOperation, ReviewPhoto
from .storage import image_storage


def referenced(asset_id):
    from usuarios.models import Usuario

    return (
        Usuario.objects.filter(avatar_asset_id=asset_id).exists()
        or ReviewPhoto.objects.filter(deleted_at=None, current_revision__asset_id=asset_id).exists()
    )


def retire(asset):
    if asset is None or referenced(asset.pk):
        return
    ImageAsset.objects.filter(pk=asset.pk).update(state="retired")
    ImageCleanup.objects.get_or_create(asset=asset)


def reconcile_images(limit=50):
    now = timezone.now()
    # Owner locks precede operations, matching upload finalization and account deletion.
    from usuarios.models import Usuario

    stale = list(
        ImageOperation.objects.filter(state="processing", expires_at__lt=now).values_list("pk", "owner_id")[
            :limit
        ]
    )
    for identifier, owner_id in stale:
        with transaction.atomic():
            Usuario.objects.filter(pk=owner_id).select_for_update().first()
            op = (
                ImageOperation.objects.select_for_update()
                .filter(pk=identifier, state="processing", expires_at__lt=now)
                .first()
            )
            if op:
                op.state = "failed"
                op.save(update_fields=["state"])
                retire(op.asset)
    completed = 0
    for job in ImageCleanup.objects.filter(state="pending").order_by("updated_at")[:limit]:
        with transaction.atomic():
            asset = ImageAsset.objects.select_for_update().get(pk=job.asset_id)
            if referenced(asset.pk):
                continue
            try:
                storage = image_storage()
                storage.delete(asset.image_key)
                storage.delete(asset.thumb_key)
            except OSError:
                job.attempts += 1
                job.updated_at = now
                job.save(update_fields=["attempts", "updated_at"])
            else:
                job.state = "done"
                job.save(update_fields=["state"])
                completed += 1
    return completed
