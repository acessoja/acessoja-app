"""Fetch current evidence with the place SQL query, without one query per resource.

JSON is an internal transfer shape, not a public serializer. Eligibility is
applied before aggregation; historical revisions never enter this projection.
"""

from datetime import date, datetime, timezone
import json
from types import SimpleNamespace
import uuid

from django.db.models import Aggregate, Count, F, JSONField, Max, OuterRef, Q, Subquery, Value
from django.db.models.functions import JSONObject

from .models import EvidenceConfirmation, ResourceEvidence
from .projection import visible_query


class CurrentEvidenceArray(Aggregate):
    function = "JSONB_AGG"
    output_field = JSONField()

    def as_sqlite(self, compiler, connection, **extra_context):
        return super().as_sql(compiler, connection, function="JSON_GROUP_ARRAY", **extra_context)


def annotate_quality(rows, *, catalog=False):
    if catalog:
        scope = Q(external_id=OuterRef("poi__external_id"))
    else:
        scope = Q(local_id=OuterRef("pk")) | (Q(external_id=OuterRef("osm_id")) & ~Q(external_id=""))
    confirmations = EvidenceConfirmation.objects.filter(revision_id=OuterRef("current_revision_id")).values(
        "revision_id"
    )
    roots = ResourceEvidence.objects.filter(
        scope, visible_query(), withdrawn=False, current_revision__isnull=False
    ).order_by()
    roots = (
        roots.annotate(_group=Value(1))
        .values("_group")
        .annotate(
            _rows=CurrentEvidenceArray(
                JSONObject(
                    id=F("id"),
                    resource=F("resource"),
                    source=F("source"),
                    kind=F("kind"),
                    owner_id=F("owner_id"),
                    review_id=F("review_id"),
                    external_id=F("external_id"),
                    metadata=F("source_metadata"),
                    revision_id=F("current_revision_id"),
                    state=F("current_revision__state"),
                    note=F("current_revision__note"),
                    observed_at=F("current_revision__observed_at"),
                    observed_on=F("current_revision__observed_on"),
                    received_at=F("current_revision__received_at"),
                    valid=F("current_revision__is_valid"),
                    confirmation_count=Subquery(
                        confirmations.annotate(total=Count("pk")).values("total")[:1]
                    ),
                    confirmed_at=Subquery(
                        confirmations.annotate(latest=Max("confirmed_at")).values("latest")[:1]
                    ),
                )
            )
        )
        .values("_rows")[:1]
    )
    return rows.annotate(_quality_rows=Subquery(roots, output_field=JSONField()))


def database_timestamp(value):
    if not value:
        return None
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00")) if isinstance(value, str) else value
    # SQLite stores Django DateTimeFields as UTC without the offset. This is
    # conversion of known database fields, not acceptance of naive user input.
    return parsed.replace(tzinfo=timezone.utc) if parsed.tzinfo is None else parsed


def unpack_quality(data):
    records, statistics = [], {}
    for item in data or []:
        identifier, revision_id = uuid.UUID(item["id"]), uuid.UUID(item["revision_id"])
        metadata = item["metadata"]
        if isinstance(metadata, str):
            metadata = json.loads(metadata)
        revision = SimpleNamespace(
            pk=revision_id,
            state=item["state"],
            note=item["note"],
            observed_at=database_timestamp(item["observed_at"]),
            observed_on=date.fromisoformat(item["observed_on"]) if item["observed_on"] else None,
            received_at=database_timestamp(item["received_at"]),
            is_valid=bool(item["valid"]),
        )
        records.append(
            SimpleNamespace(
                pk=identifier,
                resource=item["resource"],
                source=item["source"],
                kind=item["kind"],
                owner_id=item["owner_id"],
                review_id=item["review_id"],
                external_id=item["external_id"],
                source_metadata=metadata,
                current_revision_id=revision_id,
                current_revision=revision,
            )
        )
        if item["confirmation_count"]:
            statistics[revision_id] = {
                "count": item["confirmation_count"],
                "latest": database_timestamp(item["confirmed_at"]),
            }
    return records, statistics
