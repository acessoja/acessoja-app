"""Only maintain existing canonical links; no I/O or imports at application startup."""

from django.db.models import F
from django.db.models.signals import pre_delete, post_save
from django.dispatch import receiver

from .catalog_models import CatalogPOI, CatalogScope
from .models import Local
from .services.catalog_rules import MUNICIPALITY


@receiver(post_save, sender=Local, dispatch_uid="catalog_canonical_identity")
def canonical_identity(sender, instance, **kwargs):
    if not instance.osm_id:
        return
    changed = CatalogPOI.objects.filter(external_id=instance.osm_id, local__isnull=True).update(
        local=instance, link_method="explicit_osm_id"
    )
    if changed:
        CatalogScope.objects.filter(pk=MUNICIPALITY).update(revision=F("revision") + 1)


@receiver(pre_delete, sender=Local, dispatch_uid="catalog_canonical_deleted")
def canonical_deleted(sender, instance, **kwargs):
    if CatalogPOI.objects.filter(local_id=instance.pk).exists():
        CatalogScope.objects.filter(pk=MUNICIPALITY).update(revision=F("revision") + 1)
