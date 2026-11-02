"""Único catálogo de categorias da API e dos seletores do mapa.

Os filtros Overpass são constantes; valores do cliente nunca viram código QL.
"""

import json
from pathlib import Path

CATEGORIES = {
    "restaurante": {"label": "Restaurantes", "filters": ["[amenity=restaurant]", "[amenity=fast_food]"]},
    "cafeteria": {"label": "Cafeterias", "filters": ["[amenity=cafe]"]},
    "supermercado": {"label": "Supermercados", "filters": ["[shop=supermarket]", "[shop=convenience]"]},
    "farmacia": {"label": "Farmácias", "filters": ["[amenity=pharmacy]"]},
    "saude": {
        "label": "Hospitais e clínicas",
        "filters": ["[amenity=hospital]", "[amenity=clinic]", "[amenity=doctors]"],
    },
    "educacao": {"label": "Escolas e universidades", "filters": ["[amenity=school]", "[amenity=university]"]},
    "loja": {"label": "Lojas e centros comerciais", "filters": ['[shop][shop!~"^(supermarket|convenience)$"]']},
    "parque": {"label": "Parques e espaços públicos", "filters": ["[leisure=park]", "[leisure=playground]"]},
    "banco": {"label": "Bancos", "filters": ["[amenity=bank]"]},
    "publico": {"label": "Órgãos públicos", "filters": ["[office=government]", "[amenity=townhall]"]},
    "outros": {
        "label": "Outros estabelecimentos",
        "filters": ['[amenity~"^(library|cinema|theatre|community_centre)$"]'],
    },
}


def category_for(tags):
    amenity = tags.get("amenity")
    for key, values in (
        ("restaurante", ("restaurant", "fast_food")),
        ("cafeteria", ("cafe",)),
        ("farmacia", ("pharmacy",)),
        ("saude", ("hospital", "clinic", "doctors")),
        ("educacao", ("school", "university")),
        ("banco", ("bank",)),
        ("publico", ("townhall",)),
    ):
        if amenity in values:
            return key
    if tags.get("shop") in ("supermarket", "convenience"):
        return "supermercado"
    if tags.get("shop"):
        return "loja"
    if tags.get("leisure") in ("park", "playground"):
        return "parque"
    if tags.get("office") == "government":
        return "publico"
    return "outros"


# Stable versioned contract; Flutter's generated catalog is checked byte-for-byte in tests.

CATEGORY_CATALOG = json.loads((Path(__file__).parent.parent / "data/place_categories.json").read_text(encoding="utf-8"))
CATEGORY_VERSION = CATEGORY_CATALOG["version"]
SUBCATEGORIES = {item["id"]: item for item in CATEGORY_CATALOG["children"]}


def subcategory_for(tags, parent=None):
    """Never infer from names. Multiple exact candidates have no precedence."""
    tags = tags if isinstance(tags, dict) else {}
    candidates = [
        item for item in SUBCATEGORIES.values() if all(tags.get(key) == value for key, value in item["tags"].items())
    ]
    if len(candidates) != 1:
        return ""
    item = candidates[0]
    return item["id"] if parent is None or parent == item["parent"] else ""


def validate_category_pair(parent, child):
    if child and (child not in SUBCATEGORIES or SUBCATEGORIES[child]["parent"] != parent):
        raise ValueError("Subcategoria incompatível com a categoria.")


def normalize_categories(parents, children):
    parents, children = list(dict.fromkeys(parents)), list(dict.fromkeys(children))
    derived = list(dict.fromkeys(SUBCATEGORIES[key]["parent"] for key in children))
    if parents and any(parent not in parents for parent in derived):
        raise ValueError("Subcategoria incompatível com as categorias selecionadas.")
    return parents or derived, children


def matches_category(parent, child, parents, children):
    if not parents:
        return True
    if parent not in parents:
        return False
    selected = [key for key in children if SUBCATEGORIES[key]["parent"] == parent]
    return not selected or child in selected


def canonical_subcategory(parent, internal, tags=None):
    """Use explicit current assertions only; conflicting classifications are unknown."""
    observations = [tags] if isinstance(tags, dict) else tags or []
    candidates = {
        item["id"]: item
        for item in SUBCATEGORIES.values()
        for observation in observations
        if isinstance(observation, dict) and all(observation.get(key) == value for key, value in item["tags"].items())
    }
    if len(candidates) > 1 or any(item["parent"] != parent for item in candidates.values()):
        return ""
    values = {key for key in [internal, next(iter(candidates), "")] if key}
    return next(iter(values)) if len(values) == 1 else ""
