from django.db.models import Q
from django.utils import timezone
from .cleanup import retire
from .models import ImageAsset, ImageDecision, ImageOperation, PhotoRevision, ReviewPhoto


def own_export_queries(user):
    return {
        "review_photos": ReviewPhoto.objects.filter(owner=user).values(
            "id", "review_id", "current_revision_id", "deleted_at", "created_at"
        ),
        "photo_revisions": PhotoRevision.objects.filter(owner=user).values(
            "id", "photo_id", "description", "submitted_at", "state", "asset__width", "asset__height"
        ),
        "image_operations": ImageOperation.objects.filter(owner=user).values(
            "operation_id", "kind", "state", "photo_id", "result_revision", "created_at"
        ),
    }


def erase_user_media(user):
    from evidencias.models import ContentReport, ModerationDecision

    cases = ContentReport.objects.filter(Q(photo_revision__owner=user) | Q(reporter=user))
    ModerationDecision.objects.filter(report__in=cases).update(
        reason="Dados minimizados por exclusão.", author_message=""
    )
    cases.update(description="")
    ImageDecision.objects.filter(Q(revision__owner=user) | Q(moderator=user)).update(
        reason="Dados minimizados por exclusão."
    )
    ReviewPhoto.objects.filter(owner=user).update(deleted_at=timezone.now())
    PhotoRevision.objects.filter(owner=user).update(description="", owner=None)
    # Remove the avatar reference before scheduling the same private cleanup used for photos.
    old_avatar = user.avatar_asset
    user.avatar_asset = None
    user.foto_perfil = ""
    user.save(update_fields=["avatar_asset", "foto_perfil"])
    for asset in ImageAsset.objects.filter(owner=user):
        retire(asset)
    if old_avatar:
        retire(old_avatar)
