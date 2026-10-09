"""Correspondência conservadora. Ambiguidade nunca remove um estabelecimento."""

import math
import re
import unicodedata

from locais.models import Local


def normalize(value):
    text = unicodedata.normalize("NFKD", str(value or "")).casefold()
    text = "".join(c for c in text if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", " ", text).strip()


def distance_m(lat1, lon1, lat2, lon2):
    lat1, lon1, lat2, lon2 = map(math.radians, (lat1, lon1, lat2, lon2))
    a = math.sin((lat2 - lat1) / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin((lon2 - lon1) / 2) ** 2
    return 6371000 * 2 * math.asin(math.sqrt(min(1, a)))


def strong_match(place, local):
    if local.osm_id:
        return local.osm_id == place["external_id"]
    if local.latitude is None or local.longitude is None:
        return False
    if (
        not math.isfinite(local.latitude)
        or not math.isfinite(local.longitude)
        or abs(local.latitude) > 90
        or abs(local.longitude) > 180
    ):
        return False
    if not normalize(place["nome"]) or normalize(place["nome"]) != normalize(local.nome):
        return False
    # Categoria em conflito impede fusão, mesmo no mesmo endereço.
    if local.categoria and local.categoria != place["categoria"]:
        return False
    if not place["endereco"] or normalize(place["endereco"]) != normalize(local.endereco):
        return False
    return distance_m(place["latitude"], place["longitude"], local.latitude, local.longitude) <= 25


def find_internal(place, candidates=None):
    if candidates is None:
        explicit = Local.objects.filter(osm_id=place["external_id"]).first()
        if explicit:
            return explicit
        # Longitude pode variar muito nos polos: não excluímos candidatos por ela.
        candidates = Local.objects.filter(latitude__range=(place["latitude"] - 0.0003, place["latitude"] + 0.0003))
    candidates = list(candidates)
    explicit = next((local for local in candidates if local.osm_id == place["external_id"]), None)
    if explicit:
        return explicit
    matches = [local for local in candidates if strong_match(place, local)]
    return matches[0] if len(matches) == 1 else None
