"""SQL filters precede count, sorting and pagination. No geometry engine on the HTTP path."""

import math

from django.db.models import Case, Exists, F, IntegerField, OuterRef, Q, Value, When
from django.db.models.functions import ASin, Cos, Greatest, Least, Radians, Sin, Sqrt

from locais.accessibility import osm_information, resolve_information
from locais.catalog_models import CatalogEntry
from locais.models import Local
from evidencias.models import ResourceEvidence
from evidencias.projection import visible_query
from .categories import CATEGORIES, SUBCATEGORIES, subcategory_for
from .matching import normalize


def catalog_queryset(batch, options, filters, *, unlinked=True):
    rows = CatalogEntry.objects.filter(batch=batch, source_status="available")
    if unlinked:
        rows = (
            rows.filter(poi__local__isnull=True)
            .annotate(has_canonical=Exists(Local.objects.filter(osm_id=OuterRef("poi__external_id"))))
            .filter(has_canonical=False)
        )
    if filters["sources"] and "openstreetmap" not in filters["sources"]:
        rows = rows.none()
    if options.bbox:
        south, west, north, east = options.bbox
        rows = rows.filter(latitude__range=(south, north))
        rows = (
            rows.filter(longitude__range=(west, east))
            if west <= east
            else rows.filter(Q(longitude__gte=west) | Q(longitude__lte=east))
        )
    if filters["categories"]:
        rows = rows.filter(category__in=filters["categories"])
    for word in normalize(filters["search"]).split():
        rows = rows.filter(search_text__contains=word)
    predicates, scores = [], []
    for resource in filters["resources"]:
        states = ["presence_reported", "unknown"] if filters["include_unknown"] else ["presence_reported"]
        fallback = Q(**{f"resource_states__{resource}__in": states})
        if filters["include_unknown"]:
            fallback |= Q(**{f"resource_states__{resource}__isnull": True})
        base = ResourceEvidence.objects.filter(
            external_id=OuterRef("poi__external_id"), resource=resource, withdrawn=False
        )
        public = base.filter(visible_query(), current_revision__is_valid=True)
        aliases = {}
        prefix = "_evidence_" + resource + "_"
        aliases[prefix + "exists"] = Exists(base)
        for short, state in [
            ("yes", "presence_reported"),
            ("no", "absence_reported"),
            ("limited", "limited"),
            ("unknown", "unknown"),
            ("na", "not_applicable"),
        ]:
            aliases[prefix + short] = Exists(public.filter(current_revision__state=state))
        rows = rows.annotate(**aliases)
        known = Q(**{prefix + "yes": True, prefix + "no": False})
        if filters["include_unknown"]:
            unknown = Q(**{prefix + "yes": False, prefix + "no": False, prefix + "limited": False})
            unknown &= Q(**{prefix + "unknown": True}) | Q(**{prefix + "na": False})
            known |= unknown
        predicates.append((Q(**{prefix + "exists": True}) & known) | (Q(**{prefix + "exists": False}) & fallback))
        present = Q(**{prefix + "exists": True, prefix + "yes": True, prefix + "no": False}) | (
            Q(**{prefix + "exists": False}) & Q(**{f"resource_states__{resource}": "presence_reported"})
        )
        scores.append(Case(When(present, then=Value(1)), default=Value(0), output_field=IntegerField()))
    if predicates and filters.get("mode") != "priorizar":
        predicate = predicates[0]
        for item in predicates[1:]:
            predicate = predicate | item if filters.get("combination") == "qualquer" else predicate & item
        rows = rows.filter(predicate)
    leading = []
    if scores and filters.get("mode") == "priorizar":
        total = scores[0]
        for item in scores[1:]:
            total += item
        rows = rows.annotate(_resource_score=total)
        leading = ["-_resource_score"]
    if filters.get("subcategories"):
        candidates = [
            Case(
                When(**{f"tags__{key}": value for key, value in item["tags"].items()}, then=Value(1)),
                default=Value(0),
                output_field=IntegerField(),
            )
            for item in SUBCATEGORIES.values()
        ]
        total = candidates[0]
        for item in candidates[1:]:
            total += item
        rows = rows.annotate(_category_candidates=total)
        category_match = Q(pk__in=[])
        for parent in filters["categories"]:
            children = [
                SUBCATEGORIES[key] for key in filters["subcategories"] if SUBCATEGORIES[key]["parent"] == parent
            ]
            if not children:
                category_match |= Q(category=parent)
            for child in children:
                category_match |= Q(
                    category=parent,
                    _category_candidates=1,
                    **{f"tags__{key}": value for key, value in child["tags"].items()},
                )
        rows = rows.filter(category_match)
    if options.ordering == "proximity":
        lat, lon = options.origin
        a = Sin((Radians(F("latitude")) - Value(math.radians(lat))) / 2.0) ** 2.0 + (
            Value(math.cos(math.radians(lat)))
            * Cos(Radians(F("latitude")))
            * Sin((Radians(F("longitude")) - Value(math.radians(lon))) / 2.0) ** 2.0
        )
        rows = rows.annotate(distance_m=Value(12742000.0) * ASin(Sqrt(Least(Value(1.0), Greatest(Value(0.0), a)))))
        return rows.order_by(*leading, "distance_m", "display_name", "poi_id")
    # All unlinked catalog POIs are unreviewed. Rating therefore ties, then orders by name and stable ID.
    return rows.order_by(*leading, "display_name", "poi_id")


def catalog_place(entry, filters=None, linked_local=None):
    filters = filters or {"resources": []}
    return {
        "catalog_id": entry.poi_id,
        "external_id": entry.poi.external_id,
        "source": "openstreetmap",
        "storage": "municipal_catalog",
        "origins": ["acessoja", "openstreetmap"] if linked_local else ["openstreetmap"],
        "nome": entry.display_name,
        "name_is_fallback": not bool(entry.original_name),
        "endereco": entry.address,
        "categoria": entry.category,
        "subcategoria": subcategory_for(entry.tags, entry.category),
        "categoria_label": CATEGORIES[entry.category]["label"],
        "latitude": entry.latitude,
        "longitude": entry.longitude,
        "internal_id": linked_local["id_local"] if linked_local else None,
        "linked_local": linked_local,
        "geometry_type": entry.geometry_type,
        "point_method": entry.point_method,
        "crosses_boundary": entry.crosses_boundary,
        "access_restriction": entry.access_restriction,
        "source_status": entry.source_status,
        "source_snapshot_at": entry.observed_in.snapshot_at,
        "catalog_snapshot_at": entry.batch.snapshot_at,
        "source_observed_in_current_batch": entry.observed_in_id == entry.batch_id,
        "attribution": "© OpenStreetMap contributors",
        "license_url": "https://www.openstreetmap.org/copyright",
        "opening_status": "unknown",
        "quantidade_avaliacoes": 0,
        "media_estrelas": None,
        "accessibility_data": entry.tags,
        "accessibility": resolve_information(external=osm_information(entry.tags)),
        "missing_resources": [key for key in filters["resources"] if entry.resource_states.get(key) == "unknown"],
    }
