"""Batch evidence loading with the same visibility policy as Card 15."""
from collections import defaultdict

from django.db.models import Q, Subquery

from modal_avaliacao.models import ModalAvaliacao
from locais.accessibility import osm_information, resolve_information


def populate_accessibility_context(locals_, context):
    locals_ = list(locals_)
    request = context.get("request")
    user = getattr(request, "user", None)
    own_id = user.pk if user and user.is_authenticated else None
    visible = Q(is_valid=True, user__mostrar_avaliacoes=True)
    if own_id is not None:
        visible |= Q(user_id=own_id)
    grouped = defaultdict(list)
    rows = ModalAvaliacao.objects.filter(local_id__in=[local.pk for local in locals_], is_current=True).filter(
        visible
    ).order_by("local_id", "user_id", "-data_resposta", "-pk").values(
        "local_id", "user_id", "is_current", "is_valid", "questionnaire_version", "answers", "answer_dates", "estrelas",
    )
    for row in rows:
        grouped[row["local_id"]].append(row)
    states = context.setdefault("accessibility_states", {})
    stats = context.setdefault("visible_review_stats", {})
    from locais.catalog_models import CatalogEntry, CatalogScope
    ids = [local.pk for local in locals_]
    identities = [local.osm_id for local in locals_ if local.osm_id]
    editions = CatalogEntry.objects.filter(batch_id__in=Subquery(
        CatalogScope.objects.filter(active_batch__isnull=False).values("active_batch_id"))).filter(
            Q(poi__local_id__in=ids) | Q(poi__external_id__in=identities)).select_related("poi", "observed_in", "batch")
    by_local, by_identity = {}, {}
    for edition in editions:
        if edition.poi.local_id:
            by_local[edition.poi.local_id] = edition
        by_identity[edition.poi.external_id] = edition
    provenance = context.setdefault("catalog_provenance", {})
    for local in locals_:
        local_rows = grouped[local.pk]
        edition = by_local.get(local.pk) or by_identity.get(local.osm_id)
        external = osm_information(edition.tags) if edition else {}
        states[(local.pk, own_id)] = resolve_information(local.accessibility_information, local_rows, external)
        if edition:
            provenance[local.pk] = {
                "catalog_id": edition.poi_id, "external_id": edition.poi.external_id,
                "source_snapshot_at": edition.observed_in.snapshot_at,
                "source_status": edition.source_status, "point_method": edition.point_method,
                "source_observed_in_current_batch": edition.observed_in_id == edition.batch_id,
                "attribution": "© OpenStreetMap contributors",
                "license_url": "https://www.openstreetmap.org/copyright"}
        ratings = [row["estrelas"] for row in local_rows if row["is_valid"] and 1 <= row["estrelas"] <= 5]
        stats[(local.pk, own_id)] = {"count": len(ratings),
                                     "average": sum(ratings) / len(ratings) if ratings else None}
    return context


def local_accessibility(local, context):
    request = context.get("request")
    user = getattr(request, "user", None)
    own_id = user.pk if user and user.is_authenticated else None
    key = (local.pk, own_id)
    if key not in context.get("accessibility_states", {}):
        populate_accessibility_context([local], context)
    return context["accessibility_states"][key]
