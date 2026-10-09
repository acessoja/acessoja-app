"""Consultas geográficas limitadas, cacheadas e sem dependência das views."""

import hashlib
import json
import math
import time

import requests
from django.conf import settings
from django.core import signing
from django.core.cache import cache

from .categories import CATEGORIES, category_for
from .matching import distance_m

ATTRIBUTION = "© OpenStreetMap contributors · ODbL"
TOKEN_SALT = "acessoja.external-place.v1"
MAX_BYTES = 2 * 1024 * 1024
RAW_LIMIT = 500


class ExternalServiceError(Exception):
    def __init__(self, detail, status=503, retry_after=15):
        self.detail = detail
        self.status = status
        self.retry_after = retry_after
        super().__init__(detail)


def _key(prefix, data):
    digest = hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()
    return f"geo:{prefix}:{digest}"


def request_json(kind, url, *, data=None, params=None):
    """No retry loop: backoff is explicit so public instances cannot be flooded.

    cache.add provides a single in-flight slot and a cooldown per provider.
    Use a shared cache for multiple workers (documented in README).
    """
    gate = f"geo:gate:{kind}"
    cooldown = 2 if kind == "nominatim" else 15
    if not cache.add(gate, True, timeout=60):
        raise ExternalServiceError("Fonte ocupada. Aguarde e tente novamente.", 429, cooldown)
    try:
        started = time.monotonic()
        headers = {"User-Agent": settings.GEO_USER_AGENT, "Accept": "application/json"}
        kwargs = dict(headers=headers, timeout=(3, 12), stream=True, allow_redirects=False)
        response = requests.post(url, data=data, **kwargs) if data else requests.get(url, params=params, **kwargs)
        with response:
            if response.status_code == 429:
                cooldown = 60
                raise ExternalServiceError("Fonte externa limitou as consultas. Tente novamente mais tarde.", 429, 60)
            if response.status_code != 200:
                raise ExternalServiceError("Fonte externa indisponível.")
            body = bytearray()
            for chunk in response.iter_content(chunk_size=65536):
                if time.monotonic() - started > 18:
                    raise ExternalServiceError("Tempo de transferência externa esgotado.", 504)
                body.extend(chunk)
                if len(body) > MAX_BYTES:
                    raise ExternalServiceError("Resposta externa excedeu o limite seguro.", 502)
            try:
                return json.loads(body)
            except (ValueError, UnicodeError) as exc:
                raise ExternalServiceError("Resposta inválida da fonte externa.", 502) from exc
    except requests.Timeout as exc:
        raise ExternalServiceError("Tempo de espera da fonte externa esgotado.", 504) from exc
    except requests.RequestException as exc:
        raise ExternalServiceError("Não foi possível conectar à fonte externa.") from exc
    finally:
        # Remains held during the HTTP call, then enforces provider cooldown.
        cache.set(gate, True, timeout=cooldown)


def normalize_element(element):
    if not isinstance(element, dict) or element.get("type") not in ("node", "way", "relation"):
        return None
    osm_number = element.get("id")
    if not isinstance(osm_number, int) or isinstance(osm_number, bool) or osm_number <= 0:
        return None
    tags = element.get("tags")
    if not isinstance(tags, dict) or not isinstance(tags.get("name"), str) or not tags["name"].strip():
        return None
    coords = element if element["type"] == "node" else element.get("center")
    if not isinstance(coords, dict):
        return None
    if isinstance(coords.get("lat"), bool) or isinstance(coords.get("lon"), bool):
        return None
    try:
        lat, lon = float(coords["lat"]), float(coords["lon"])
    except (KeyError, ValueError, TypeError):
        return None
    if not math.isfinite(lat) or not math.isfinite(lon) or abs(lat) > 90 or abs(lon) > 180:
        return None
    # Only strings from a small allowlist reach the UI/signature.
    tags = {key: value[:255] for key, value in tags.items() if isinstance(value, str)}
    parts = [tags.get("addr:street"), tags.get("addr:housenumber"), tags.get("addr:suburb"), tags.get("addr:city")]
    address = tags.get("addr:full") or ", ".join(part for part in parts if part)
    external_id = f"osm:{element['type']}:{osm_number}"
    category = category_for(tags)
    return {
        "id": external_id,
        "external_id": external_id,
        "source": "openstreetmap",
        "nome": tags["name"].strip(),
        "categoria": category,
        "categoria_label": CATEGORIES[category]["label"],
        "endereco": address[:255],
        "latitude": lat,
        "longitude": lon,
        "internal_id": None,
        "has_community_reviews": False,
        "media_estrelas": None,
        # OSM tags are observations from OSM, not AcessoJá confirmations.
        "accessibility_data": {key: tags[key] for key in ("wheelchair", "toilets:wheelchair") if key in tags},
        "additional_data": {key: tags[key] for key in ("opening_hours", "addr:suburb", "addr:city") if key in tags},
    }


class ExternalPlacesService:
    def search(self, *, latitude, longitude, raio=1500, categoria=None, limite=50):
        # Validate also at the service boundary, including calls outside HTTP views.
        if (
            not math.isfinite(latitude)
            or not math.isfinite(longitude)
            or abs(latitude) > 90
            or abs(longitude) > 180
            or not 100 <= raio <= 3000
            or not 1 <= limite <= 100
            or (categoria is not None and categoria not in CATEGORIES)
        ):
            raise ValueError("Parâmetros geográficos inválidos.")
        key = _key("overpass", [latitude, longitude, raio, categoria, limite, settings.OVERPASS_URL])
        result = cache.get(key)
        if result is None:
            filters = (
                CATEGORIES[categoria]["filters"]
                if categoria
                else [item for category in CATEGORIES.values() for item in category["filters"]]
            )
            area = f"(around:{raio},{latitude:.6f},{longitude:.6f})"
            query = (
                "[out:json][timeout:10][maxsize:16777216];("
                + "".join(f"nwr{item}[name]{area};" for item in filters)
                + f");out center {RAW_LIMIT};"
            )
            payload = request_json("overpass", settings.OVERPASS_URL, data={"data": query})
            if not isinstance(payload, dict) or not isinstance(payload.get("elements"), list) or payload.get("remark"):
                raise ExternalServiceError("Dados incompletos ou inválidos da fonte externa.", 502)
            places = {}
            for element in payload["elements"][:RAW_LIMIT]:
                place = normalize_element(element)
                if place and distance_m(latitude, longitude, place["latitude"], place["longitude"]) <= raio:
                    if categoria is None or place["categoria"] == categoria:
                        places[place["id"]] = place
            ordered = sorted(
                places.values(), key=lambda p: distance_m(latitude, longitude, p["latitude"], p["longitude"])
            )
            result = {
                "results": ordered[:limite],
                "attribution": ATTRIBUTION,
                "truncated": len(ordered) > limite or len(payload["elements"]) >= RAW_LIMIT,
            }
            cache.set(key, result, timeout=settings.EXTERNAL_PLACES_CACHE_SECONDS)
        # Fresh tokens even on cache hits. No token or database matching is cached.
        output = dict(result)
        output["results"] = [
            dict(place, registration_token=signing.dumps(place, salt=TOKEN_SALT, compress=True))
            for place in result["results"]
        ]
        return output


def geocode(params):
    if not settings.NOMINATIM_URL:
        raise ExternalServiceError("Pesquisa de endereços não configurada. Selecione um local no mapa.")
    key = _key("geocode", [params, settings.NOMINATIM_URL])
    result = cache.get(key)
    if result is not None:
        return result
    query = {"format": "jsonv2", "limit": 5, **params}
    if "q" in params:
        url = settings.NOMINATIM_URL.rstrip("/") + "/search"
    else:
        url = settings.NOMINATIM_URL.rstrip("/") + "/reverse"
        query["lat"] = query.pop("latitude")
        query["lon"] = query.pop("longitude")
    payload = request_json("nominatim", url, params=query)
    items = payload if isinstance(payload, list) else [payload]
    result = []
    for item in items[:5]:
        if not isinstance(item, dict):
            raise ExternalServiceError("Resposta geográfica inválida.", 502)
        try:
            lat, lon = float(item["lat"]), float(item["lon"])
            name = str(item["display_name"])[:500]
        except (KeyError, TypeError, ValueError) as exc:
            raise ExternalServiceError("Resposta geográfica inválida.", 502) from exc
        if not math.isfinite(lat) or not math.isfinite(lon) or abs(lat) > 90 or abs(lon) > 180:
            raise ExternalServiceError("Coordenadas geográficas inválidas.", 502)
        result.append({"nome": name, "latitude": lat, "longitude": lon})
    cache.set(key, result, timeout=86400)
    return result
