"""Único catálogo de categorias da API e dos seletores do mapa.

Os filtros Overpass são constantes; valores do cliente nunca viram código QL.
"""

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
