"""Stable identities, immutable source editions, and one atomically published municipal view."""

import uuid

from django.db import models


class CatalogScope(models.Model):
    municipality = models.CharField(max_length=7, primary_key=True)
    active_batch = models.ForeignKey("CatalogBatch", null=True, blank=True, on_delete=models.SET_NULL, related_name="+")
    revision = models.PositiveBigIntegerField(default=0)
    lease_owner = models.UUIDField(null=True, editable=False)
    lease_until = models.DateTimeField(null=True, editable=False)

    def __str__(self):
        return self.municipality


class CatalogBatch(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    scope = models.ForeignKey(CatalogScope, on_delete=models.PROTECT, related_name="batches")
    state = models.CharField(
        max_length=16,
        default="building",
        choices=[
            ("building", "Em preparação"),
            ("published", "Publicado"),
            ("partial", "Publicado com cobertura parcial"),
            ("failed", "Falhou"),
        ],
    )
    fingerprint = models.CharField(max_length=64, db_index=True)
    snapshot_at = models.DateTimeField(null=True)
    rules_version = models.CharField(max_length=40)
    boundary_hash = models.CharField(max_length=64)
    complete = models.BooleanField(default=False)
    manifest = models.JSONField(default=dict)
    statistics = models.JSONField(default=dict)
    error_code = models.CharField(max_length=64, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    finished_at = models.DateTimeField(null=True)

    def __str__(self):
        return f"{self.scope_id}: {self.id} ({self.state})"


class CatalogPOI(models.Model):
    source = models.CharField(max_length=32, default="openstreetmap")
    osm_type = models.CharField(max_length=8, choices=[("node", "node"), ("way", "way"), ("relation", "relation")])
    osm_number = models.PositiveBigIntegerField()
    external_id = models.CharField(max_length=64, unique=True)
    local = models.ForeignKey("Local", null=True, blank=True, on_delete=models.SET_NULL, related_name="catalog_items")
    link_method = models.CharField(max_length=40, blank=True)
    first_seen = models.DateTimeField(null=True)
    last_seen = models.DateTimeField(null=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["source", "osm_type", "osm_number"], name="catalog_source_identity_unique")
        ]

    def __str__(self):
        return self.external_id


class CatalogEntry(models.Model):
    batch = models.ForeignKey(CatalogBatch, on_delete=models.CASCADE, related_name="entries")
    poi = models.ForeignKey(CatalogPOI, on_delete=models.PROTECT, related_name="editions")
    observed_in = models.ForeignKey(CatalogBatch, on_delete=models.PROTECT, related_name="observations")
    original_name = models.CharField(max_length=255, blank=True)
    display_name = models.CharField(max_length=255)
    category = models.CharField(max_length=32)
    address = models.CharField(max_length=255, blank=True)
    latitude = models.FloatField()
    longitude = models.FloatField()
    geometry_type = models.CharField(max_length=20)
    point_method = models.CharField(max_length=32)
    crosses_boundary = models.BooleanField(default=False)
    access_restriction = models.BooleanField(default=False)
    tags = models.JSONField(default=dict)
    resource_states = models.JSONField(default=dict)
    search_text = models.TextField()
    source_status = models.CharField(
        max_length=16,
        default="available",
        choices=[("available", "Observado e elegível"), ("not_seen", "Não observado no snapshot comparável")],
    )
    osm_version = models.PositiveIntegerField(null=True)
    osm_timestamp = models.DateTimeField(null=True)
    content_hash = models.CharField(max_length=64)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["batch", "poi"], name="catalog_edition_identity_unique"),
            models.CheckConstraint(
                condition=models.Q(latitude__gte=-90, latitude__lte=90, longitude__gte=-180, longitude__lte=180),
                name="catalog_valid_point",
            ),
        ]
        indexes = [
            models.Index(fields=["batch", "source_status", "latitude", "longitude"], name="catalog_edition_point"),
            models.Index(fields=["batch", "source_status", "category"], name="catalog_edition_category"),
            models.Index(fields=["batch", "display_name", "poi"], name="catalog_edition_name"),
        ]

    def __str__(self):
        return self.display_name
