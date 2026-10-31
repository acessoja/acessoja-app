"""Batch evidence loading with the same visibility policy as Card 15."""

from collections import defaultdict

from django.db.models import Q, Subquery

from modal_avaliacao.models import ModalAvaliacao


def populate_accessibility_context(locals_, context):
    locals_ = list(locals_)
    request = context.get("request")
    user = getattr(request, "user", None)
    own_id = user.pk if user and user.is_authenticated else None
    visible = Q(is_valid=True, user__mostrar_avaliacoes=True, user__is_active=True)
    grouped = defaultdict(list)
    rows = (
        ModalAvaliacao.objects.filter(local_id__in=[local.pk for local in locals_], is_current=True)
        .filter(visible)
        .order_by("local_id", "user_id", "-data_resposta", "-pk")
        .values(
            "id",
            "local_id",
            "user_id",
            "is_current",
            "is_valid",
            "questionnaire_version",
            "answers",
            "answer_dates",
            "estrelas",
        )
    )
    for row in rows:
        grouped[row["local_id"]].append(row)
    states = context.setdefault("accessibility_states", {})
    stats = context.setdefault("visible_review_stats", {})
    from locais.catalog_models import CatalogEntry, CatalogScope

    ids = [local.pk for local in locals_]
    identities = [local.osm_id for local in locals_ if local.osm_id]
    editions = (
        CatalogEntry.objects.filter(
            batch_id__in=Subquery(CatalogScope.objects.filter(active_batch__isnull=False).values("active_batch_id"))
        )
        .filter(Q(poi__local_id__in=ids) | Q(poi__external_id__in=identities))
        .select_related("poi", "observed_in", "batch")
    )
    by_local, by_identity = {}, {}
    for edition in editions:
        if edition.poi.local_id:
            by_local[edition.poi.local_id] = edition
        by_identity[edition.poi.external_id] = edition
    provenance = context.setdefault("catalog_provenance", {})
    from evidencias.projection import public_evidence, effective, resource_summary, confirmation_stats
    from evidencias.query_projection import unpack_quality

    embedded = all(hasattr(local, "_quality_rows") for local in locals_)
    masks = defaultdict(set)
    confirmation_data = {}
    if embedded:
        all_evidence = []
        for local in locals_:
            records, statistics = unpack_quality(local._quality_rows)
            all_evidence.extend(records)
            confirmation_data.update(statistics)
    else:
        all_evidence = list(public_evidence(ids, identities, include_invalid=True, include_inactive=True))
        valid = [row for row in all_evidence if row.current_revision.is_valid]
        confirmation_data = confirmation_stats(valid) if valid else {}
    for row in all_evidence:
        if row.review_id and (not row.current_revision.is_valid or row.superseded or row.withdrawn):
            masks[row.review_id].add(row.resource)
    context["review_resource_masks"] = masks
    all_evidence = [row for row in all_evidence if row.current_revision.is_valid]
    evidence_by_local, evidence_by_identity = defaultdict(list), defaultdict(list)
    if embedded:
        # Each embedded collection already contains that local plus linked OSM identities.
        for local in locals_:
            records, _ = unpack_quality(local._quality_rows)
            evidence_by_local[local.pk] = [row for row in records if row.current_revision.is_valid]
    else:
        for row in all_evidence:
            if row.local_id:
                evidence_by_local[row.local_id].append(row)
            if row.external_id:
                evidence_by_identity[row.external_id].append(row)
    registered = context.setdefault("public_registration_keys", {})
    for local in locals_:
        local_rows = grouped[local.pk]
        edition = by_local.get(local.pk) or by_identity.get(local.osm_id)
        records = list(
            {row.pk: row for row in [*evidence_by_local[local.pk], *evidence_by_identity[local.osm_id]]}.values()
        )
        legacy = sum(row["questionnaire_version"] != 2 for row in local_rows)
        states[(local.pk, own_id)] = resource_summary(records, legacy, confirmation_data)
        registered[local.pk] = {row.resource for row in effective(records) if row.kind == "registration"}
        if edition:
            provenance[local.pk] = {
                "catalog_id": edition.poi_id,
                "external_id": edition.poi.external_id,
                "source_snapshot_at": edition.observed_in.snapshot_at,
                "source_status": edition.source_status,
                "point_method": edition.point_method,
                "source_observed_in_current_batch": edition.observed_in_id == edition.batch_id,
                "attribution": "© OpenStreetMap contributors",
                "license_url": "https://www.openstreetmap.org/copyright",
            }
        ratings = [row["estrelas"] for row in local_rows if row["is_valid"] and 1 <= row["estrelas"] <= 5]
        stats[(local.pk, own_id)] = {"count": len(ratings), "average": sum(ratings) / len(ratings) if ratings else None}
    return context


def local_accessibility(local, context):
    request = context.get("request")
    user = getattr(request, "user", None)
    own_id = user.pk if user and user.is_authenticated else None
    key = (local.pk, own_id)
    if key not in context.get("accessibility_states", {}):
        populate_accessibility_context([local], context)
    return context["accessibility_states"][key]
