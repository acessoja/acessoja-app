"""Versioned POI eligibility; category fallback alone is never an eligibility rule."""

import hashlib
import json
import re

from locais.accessibility import osm_information, resolve_information
from .categories import CATEGORIES, category_for
from .matching import normalize

RULES_VERSION = "anapolis-poi-v1.3"
MUNICIPALITY = "5201108"
AMENITIES = frozenset(
    {
        "restaurant",
        "fast_food",
        "cafe",
        "pharmacy",
        "hospital",
        "clinic",
        "doctors",
        "school",
        "university",
        "bank",
        "townhall",
        "library",
        "cinema",
        "theatre",
        "community_centre",
    }
)
ALLOWED_TAGS = frozenset(
    {
        "name",
        "amenity",
        "shop",
        "leisure",
        "office",
        "addr:full",
        "addr:street",
        "addr:housenumber",
        "addr:suburb",
        "addr:city",
        "addr:postcode",
        "wheelchair",
        "toilets:wheelchair",
        "opening_hours",
        "access",
    }
)


def text(value, limit=255):
    return re.sub(r"[\x00-\x1f\x7f]", " ", str(value or "")).strip()[:limit]


def eligibility(tags):
    if (
        tags.get("disused") == "yes"
        or tags.get("abandoned") == "yes"
        or tags.get("demolished") == "yes"
        or tags.get("construction") not in (None, "", "no")
        or tags.get("amenity") in ("construction", "disused")
        or tags.get("shop") in ("vacant", "no", "disused")
        or any(key.startswith(("disused:", "abandoned:", "demolished:", "construction:")) for key in tags)
    ):
        return "inactive"
    if tags.get("access") in ("private", "no"):
        return "restricted_access"
    if (
        tags.get("amenity") in AMENITIES
        or tags.get("shop") not in (None, "", "no")
        or tags.get("leisure") in ("park", "playground")
        or tags.get("office") == "government"
    ):
        return None
    return "not_a_supported_poi"


def source_values(
    tags,
    *,
    latitude,
    longitude,
    geometry_type,
    point_method,
    crosses_boundary=False,
    osm_version=None,
    osm_timestamp=None,
):
    tags = {k: text(v) for k, v in tags.items() if k in ALLOWED_TAGS and isinstance(v, str)}
    category = category_for(tags)
    name = tags.get("name", "")
    fallback = f"{CATEGORIES[category]['label']} — sem nome no OSM"
    address = tags.get("addr:full") or ", ".join(
        filter(
            None,
            [
                " ".join(filter(None, [tags.get("addr:street"), tags.get("addr:housenumber")])),
                tags.get("addr:suburb"),
                tags.get("addr:city"),
                tags.get("addr:postcode"),
            ],
        )
    )
    information = resolve_information(external=osm_information(tags))
    values = {
        "original_name": name,
        "display_name": text(name or fallback),
        "category": category,
        "address": text(address),
        "latitude": latitude,
        "longitude": longitude,
        "geometry_type": geometry_type,
        "point_method": point_method,
        "crosses_boundary": crosses_boundary,
        "access_restriction": tags.get("access") in ("customers", "destination", "permit"),
        "tags": tags,
        "resource_states": {k: v["state"] for k, v in information.items()},
        "search_text": normalize(f"{name or fallback} {address}"),
        "source_status": "available",
        "osm_version": osm_version,
        "osm_timestamp": osm_timestamp,
    }
    stamp = osm_timestamp.isoformat() if hasattr(osm_timestamp, "isoformat") else osm_timestamp
    serial = dict(values, osm_timestamp=stamp)
    values["content_hash"] = hashlib.sha256(json.dumps(serial, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
    return values
