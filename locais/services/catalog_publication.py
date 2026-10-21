"""A DB compare-and-set lease serializes administrative publishers across processes."""

import uuid
from datetime import timedelta

from django.db import transaction
from django.db.models import F, Q
from django.utils import timezone

from locais.catalog_models import CatalogBatch, CatalogScope


class CatalogBusy(ValueError):
    def __init__(self, code):
        self.code = code
        super().__init__(code)


class CatalogLease:
    def __init__(self, municipality):
        self.municipality, self.owner = municipality, uuid.uuid4()

    def acquire(self):
        now = timezone.now()
        updated = (
            CatalogScope.objects.filter(pk=self.municipality)
            .filter(Q(lease_owner__isnull=True) | Q(lease_until__lt=now))
            .update(lease_owner=self.owner, lease_until=now + timedelta(minutes=5))
        )
        if updated != 1:
            raise CatalogBusy("catalog_import_busy_or_scope_missing")

    def heartbeat(self):
        updated = CatalogScope.objects.filter(pk=self.municipality, lease_owner=self.owner).update(
            lease_until=timezone.now() + timedelta(minutes=5)
        )
        if updated != 1:
            raise CatalogBusy("catalog_import_lease_lost")

    def release(self):
        CatalogScope.objects.filter(pk=self.municipality, lease_owner=self.owner).update(
            lease_owner=None, lease_until=None
        )

    def activate(self, batch, reason="validated import"):
        with transaction.atomic():
            scope = CatalogScope.objects.select_for_update().get(pk=self.municipality)
            if scope.lease_owner != self.owner or scope.lease_until < timezone.now():
                raise CatalogBusy("catalog_import_lease_lost")
            if batch.state not in ("published", "partial"):
                raise ValueError("catalog_batch_not_publishable")
            manifest = dict(CatalogBatch.objects.get(pk=batch.pk).manifest)
            manifest["activations"] = [
                *manifest.get("activations", []),
                {
                    "previous": str(scope.active_batch_id) if scope.active_batch_id else None,
                    "at": timezone.now().isoformat(),
                    "reason": reason[:500],
                },
            ]
            CatalogBatch.objects.filter(pk=batch.pk).update(manifest=manifest)
            CatalogScope.objects.filter(pk=scope.pk, lease_owner=self.owner).update(
                active_batch=batch, revision=F("revision") + 1
            )


def reactivate_batch(batch_id, reason):
    if len(reason.strip()) < 10:
        raise ValueError("catalog_activation_reason_required")
    batch = CatalogBatch.objects.get(pk=batch_id)
    lease = CatalogLease(batch.scope_id)
    lease.acquire()
    try:
        lease.activate(batch, reason)
        # The source edition remains immutable; no Local/review/favorite is reverted.
    finally:
        lease.release()
