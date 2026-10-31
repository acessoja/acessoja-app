from django.db.models import Q
from evidencias.moderation import allowed
from .models import ReviewPhoto


def public_photos():
    return ReviewPhoto.objects.filter(
        deleted_at=None,
        current_revision__state="approved",
        current_revision__asset__state="ready",
        review__is_current=True,
        review__is_valid=True,
        review__verified_author=True,
        review__estrelas__range=(1, 5),
        review__user__is_active=True,
        review__user__mostrar_avaliacoes=True,
    )


def can_read_asset(asset, user):
    if asset.state != "ready":
        return False
    if asset.purpose == "avatar":
        from usuarios.models import Usuario

        return bool(
            user.is_authenticated and Usuario.objects.filter(pk=user.pk, is_active=True, avatar_asset=asset).exists()
        )
    current = ReviewPhoto.objects.filter(current_revision__asset=asset, deleted_at=None, review__user__is_active=True)
    if user.is_authenticated and (allowed(user) or current.filter(owner=user).exists()):
        return current.exists()
    return public_photos().filter(current_revision__asset=asset).exists()


def visible_photos(user):
    public = Q(pk__in=public_photos().values("pk"))
    if user.is_authenticated:
        public |= Q(owner=user, deleted_at=None)
        if allowed(user):
            public |= Q(deleted_at=None)
    return ReviewPhoto.objects.filter(public).select_related("review__user", "current_revision__asset")
