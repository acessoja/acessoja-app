"""Consultas geográficas limitadas, cacheadas e sem dependência das views."""

import hashlib
import json
import math
import time
import uuid
from urllib.parse import urlparse

import requests
from django.conf import settings
from django.core import signing
from .geographic_runtime import (
    ExternalServiceError,
    ProviderGate,
    cached_get,
    cached_set,
    coordination_mode,
    event,
    retry_after,
    validate_budgets,
)

from .categories import CATEGORIES, category_for
from .matching import distance_m

ATTRIBUTION = "© OpenStreetMap contributors · ODbL"
TOKEN_SALT = "acessoja.external-place.v1"
MAX_BYTES = 2 * 1024 * 1024
RAW_LIMIT = 500


def _key(prefix, data):
    digest = hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()
    return f"geo:{prefix}:{digest}"


def request_json(kind, url, *, data=None, params=None, correlation_id=None):
    """One bounded attempt. Leases/cooldown are owner-checked; no worker sleeps or retry loop."""
    correlation_id = correlation_id or uuid.uuid4().hex
    gate = ProviderGate(kind, url, correlation_id)
    gate.acquire()
    cooldown = settings.GEO_NOMINATIM_COOLDOWN if kind == "nominatim" else settings.GEO_OVERPASS_COOLDOWN
    source = "application"
    measured = time.perf_counter()
    try:
        started = time.monotonic()
        headers = {"User-Agent": settings.GEO_USER_AGENT, "Accept": "application/json"}
        if kind == "nominatim" and settings.NOMINATIM_API_KEY:
            headers[settings.NOMINATIM_API_KEY_HEADER] = settings.NOMINATIM_API_KEY
        kwargs = dict(
            headers=headers,
            timeout=(settings.GEO_CONNECT_TIMEOUT, settings.GEO_READ_TIMEOUT),
            stream=True,
            allow_redirects=False,
        )
        response = requests.post(url, data=data, **kwargs) if data else requests.get(url, params=params, **kwargs)
        with response:
            if response.status_code != 200:
                cooldown, source = retry_after(
                    response.headers.get("Retry-After"),
                    settings.GEO_RATE_LIMIT_COOLDOWN if response.status_code == 429 else cooldown,
                )
                status = response.status_code if response.status_code in (429, 502, 503, 504) else 503
                event(
                    "upstream_error",
                    correlation_id,
                    provider=kind,
                    status=status,
                    upstream_status=response.status_code,
                    stage="upstream",
                    retry_source=source,
                )
                raise ExternalServiceError(
                    "Fonte externa indisponível. Aguarde antes de tentar novamente.",
                    status,
                    cooldown,
                    code="upstream_rate_limited" if status == 429 else "upstream_http",
                    stage="upstream",
                    upstream_status=response.status_code,
                    retry_source=source,
                    correlation_id=correlation_id,
                )
            body = bytearray()
            for chunk in response.iter_content(chunk_size=65536):
                if time.monotonic() - started > settings.GEO_TOTAL_TIMEOUT:
                    raise ExternalServiceError(
                        "Tempo total de transferência externa esgotado.",
                        504,
                        code="transfer_deadline",
                        stage="transfer",
                        upstream_status=200,
                        correlation_id=correlation_id,
                    )
                body.extend(chunk)
                if len(body) > MAX_BYTES:
                    raise ExternalServiceError(
                        "Resposta externa excedeu o limite seguro.",
                        502,
                        code="response_too_large",
                        stage="transfer",
                        upstream_status=200,
                        correlation_id=correlation_id,
                    )
            try:
                return json.loads(body)
            except (ValueError, UnicodeError) as exc:
                raise ExternalServiceError(
                    "Resposta inválida da fonte externa.",
                    502,
                    code="invalid_json",
                    stage="decode",
                    upstream_status=200,
                    correlation_id=correlation_id,
                ) from exc
    except requests.ConnectTimeout as exc:
        raise ExternalServiceError(
            "Tempo de conexão com a fonte externa esgotado.",
            504,
            code="connect_timeout",
            stage="connect",
            correlation_id=correlation_id,
        ) from exc
    except requests.ReadTimeout as exc:
        raise ExternalServiceError(
            "Tempo de leitura da fonte externa esgotado.",
            504,
            code="read_timeout",
            stage="read",
            correlation_id=correlation_id,
        ) from exc
    except requests.Timeout as exc:
        raise ExternalServiceError(
            "Tempo de espera da fonte externa esgotado.",
            504,
            code="request_timeout",
            stage="transport",
            correlation_id=correlation_id,
        ) from exc
    except requests.exceptions.SSLError as exc:
        raise ExternalServiceError(
            "Não foi possível validar a conexão segura com a fonte externa.",
            code="tls_failed",
            stage="connect",
            correlation_id=correlation_id,
        ) from exc
    except requests.ConnectionError as exc:
        # requests/urllib3 may wrap a read timeout while streaming as ConnectionError.
        import urllib3

        causes, pending = [], [exc]
        while pending and len(causes) < 12:
            cause = pending.pop()
            if any(cause is item for item in causes):
                continue
            causes.append(cause)
            pending.extend(
                item
                for item in (
                    getattr(cause, "__cause__", None),
                    getattr(cause, "__context__", None),
                    *getattr(cause, "args", ()),
                )
                if isinstance(item, BaseException)
            )
        import socket

        code = "dns_failed" if any(isinstance(item, socket.gaierror) for item in causes) else "connection_failed"
        if any(isinstance(item, urllib3.exceptions.ReadTimeoutError) for item in causes):
            code = "read_timeout"
        raise ExternalServiceError(
            "Não foi possível conectar à fonte externa.",
            504 if code == "read_timeout" else 503,
            code=code,
            stage="read" if code == "read_timeout" else "connect",
            correlation_id=correlation_id,
        ) from exc
    except requests.RequestException as exc:
        raise ExternalServiceError(
            "Não foi possível consultar a fonte externa.",
            code="transport_failed",
            stage="transport",
            correlation_id=correlation_id,
        ) from exc
    finally:
        gate.release(cooldown, source)
        event(
            "finished",
            correlation_id,
            provider=kind,
            milliseconds=round((time.perf_counter() - measured) * 1000),
            retry_source=source,
        )


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
        "additional_data": {
            key: tags[key] for key in ("opening_hours", "addr:suburb", "addr:city") if key in tags
        },
    }


class ExternalPlacesService:
    def search(self, *, latitude, longitude, raio=1500, categoria=None, limite=50):
        validate_budgets()
        # Validate also at the service boundary, including calls outside HTTP views.
        if (
            isinstance(latitude, bool)
            or isinstance(longitude, bool)
            or not isinstance(latitude, (float, int))
            or not isinstance(longitude, (float, int))
            or not math.isfinite(latitude)
            or not math.isfinite(longitude)
            or abs(latitude) > 90
            or abs(longitude) > 180
            or not isinstance(raio, int)
            or isinstance(raio, bool)
            or not 100 <= raio <= 3000
            or not isinstance(limite, int)
            or isinstance(limite, bool)
            or not 1 <= limite <= 100
            or (categoria is not None and (not isinstance(categoria, str) or categoria not in CATEGORIES))
        ):
            raise ValueError("Parâmetros geográficos inválidos.")
        correlation_id = uuid.uuid4().hex
        key = _key(
            "overpass-v3",
            [
                latitude,
                longitude,
                raio,
                categoria,
                limite,
                settings.OVERPASS_URL,
                CATEGORIES,
                "combined-selectors-v1",
            ],
        )
        result = cached_get(key, correlation_id)
        event("cache", correlation_id, provider="overpass", cache="hit" if result is not None else "miss")
        if result is None:
            filters = overpass_selectors(categoria)
            # repr(float) preserves the requested center; no rounded-area cache aliasing.
            area = f"(around:{raio},{latitude!r},{longitude!r})"
            query = (
                "[out:json][timeout:10][maxsize:16777216];("
                + "".join(f"nwr{item}[name]{area};" for item in filters)
                + f");out center {RAW_LIMIT};"
            )
            event("query", correlation_id, provider="overpass", selectors=len(filters))
            payload = request_json(
                "overpass", settings.OVERPASS_URL, data={"data": query}, correlation_id=correlation_id
            )
            if (
                not isinstance(payload, dict)
                or not isinstance(payload.get("elements"), list)
                or payload.get("remark")
            ):
                raise ExternalServiceError(
                    "Dados incompletos ou inválidos da fonte externa.",
                    502,
                    code="incomplete_response",
                    stage="validate",
                    upstream_status=200,
                    correlation_id=correlation_id,
                )
            places = {}
            for element in payload["elements"][:RAW_LIMIT]:
                place = normalize_element(element)
                if place and distance_m(latitude, longitude, place["latitude"], place["longitude"]) <= raio:
                    if categoria is None or place["categoria"] == categoria:
                        places[place["id"]] = place
            ordered = sorted(
                places.values(), key=lambda p: distance_m(latitude, longitude, p["latitude"], p["longitude"])
            )
            if not ordered and len(payload["elements"]) >= RAW_LIMIT:
                # A capped response without eligible centres cannot prove an empty area.
                raise ExternalServiceError(
                    "O lote externo foi limitado sem resultados elegíveis. Aproxime o mapa.",
                    502,
                    code="incomplete_response",
                    stage="validate",
                    upstream_status=200,
                    correlation_id=correlation_id,
                )
            result = {
                "results": ordered[:limite],
                "complete": True,
                "fetched_at": time.time(),
                "fresh_for_seconds": settings.EXTERNAL_PLACES_CACHE_SECONDS,
                "valid_for_seconds": settings.EXTERNAL_PLACES_MAX_AGE_SECONDS,
                "attribution": ATTRIBUTION,
                "truncated": len(ordered) > limite or len(payload["elements"]) >= RAW_LIMIT,
            }
            cached_set(key, result, settings.EXTERNAL_PLACES_CACHE_SECONDS, correlation_id)
            event(
                "result",
                correlation_id,
                provider="overpass",
                raw_count=len(payload["elements"]),
                count=len(result["results"]),
                status=200,
            )
        # Fresh tokens even on cache hits. No token or database matching is cached.
        output = dict(result, correlation_id=correlation_id)
        output["results"] = [
            dict(place, registration_token=signing.dumps(place, salt=TOKEN_SALT, compress=True))
            for place in result["results"]
        ]
        return output


def geocode(params):
    from copy import deepcopy

    validate_geocoder_configuration()
    correlation_id = uuid.uuid4().hex
    key = _key("geocode-v3", [params, settings.NOMINATIM_URL])
    result = cached_get(key, correlation_id)
    event("cache", correlation_id, provider="nominatim", cache="hit" if result is not None else "miss")
    if result is None:
        query = {"format": "jsonv2", "limit": 5, "addressdetails": 1, "extratags": 1, **params}
        if "q" in params:
            url = settings.NOMINATIM_URL.rstrip("/") + "/search"
        else:
            url = settings.NOMINATIM_URL.rstrip("/") + "/reverse"
            query["lat"] = query.pop("latitude")
            query["lon"] = query.pop("longitude")
        payload = request_json("nominatim", url, params=query, correlation_id=correlation_id)
        items = payload if isinstance(payload, list) else [payload]
        result = []
        for item in items[:5]:
            if not isinstance(item, dict):
                raise ExternalServiceError("Resposta geográfica inválida.", 502)
            try:
                if isinstance(item.get("lat"), bool) or isinstance(item.get("lon"), bool):
                    raise ValueError
                lat, lon = float(item["lat"]), float(item["lon"])
                name = str(item["display_name"])[:500]
            except (KeyError, TypeError, ValueError) as exc:
                raise ExternalServiceError("Resposta geográfica inválida.", 502) from exc
            if not math.isfinite(lat) or not math.isfinite(lon) or abs(lat) > 90 or abs(lon) > 180:
                raise ExternalServiceError("Coordenadas geográficas inválidas.", 502)
            cls = item.get("class", item.get("category"))
            region = cls == "boundary" or (
                cls == "place"
                and item.get("type")
                in ("city", "town", "village", "state", "country", "municipality", "county", "suburb")
            )
            poi = cls in ("amenity", "shop", "tourism", "leisure", "office", "healthcare") and bool(
                item.get("name")
            )
            osm_type = item.get("osm_type")
            osm_id = item.get("osm_id")
            valid_osm = (
                osm_type in ("node", "way", "relation")
                and isinstance(osm_id, int)
                and not isinstance(osm_id, bool)
                and osm_id > 0
            )
            bbox = None
            try:
                bounds = [float(v) for v in item["boundingbox"]]
                south, north, west, east = bounds
                if (
                    all(math.isfinite(v) for v in bounds)
                    and -90 <= south <= north <= 90
                    and (-180 <= west <= east <= 180)
                ):
                    bbox = [south, west, north, east]
            except (KeyError, ValueError, TypeError):
                pass
            place = None
            if poi and valid_osm:
                tags = {"name": str(item["name"]), cls: str(item.get("type", "")), "addr:full": name}
                if isinstance(item.get("extratags"), dict):
                    tags.update(
                        {
                            k: v
                            for k, v in item["extratags"].items()
                            if k in ("wheelchair", "toilets:wheelchair", "opening_hours")
                        }
                    )
                element = {
                    "type": osm_type,
                    "id": osm_id,
                    "tags": tags,
                    "lat": lat,
                    "lon": lon,
                    "center": {"lat": lat, "lon": lon},
                }
                place = normalize_element(element)
            result.append(
                {
                    "nome": name,
                    "latitude": lat,
                    "longitude": lon,
                    "kind": "region" if region else "place" if place else "address",
                    "provider_id": f"osm:{osm_type}:{osm_id}" if valid_osm else None,
                    "bounding_box": bbox,
                    "place": place,
                }
            )
        cached_set(key, result, 86400, correlation_id)
    result = deepcopy(result)
    for row in result:
        place = row.get("place")
        if place:
            place["registration_token"] = signing.dumps(place, salt=TOKEN_SALT, compress=True)
    return result


def overpass_selectors(category=None):
    if category is not None:
        return list(dict.fromkeys(CATEGORIES[category]["filters"]))
    # The all-category union needs four spatial selectors instead of repeating nwr
    # for every amenity value. The shop selector already covers supermarket/convenience.
    return [
        '[amenity~"^(restaurant|fast_food|cafe|pharmacy|hospital|clinic|doctors|school|university|'
        'bank|townhall|library|cinema|theatre|community_centre)$"]',
        "[shop]",
        '[leisure~"^(park|playground)$"]',
        "[office=government]",
    ]


def validate_geocoder_configuration():
    import re

    if not settings.NOMINATIM_URL:
        raise ExternalServiceError(
            "Pesquisa de endereços não configurada. Selecione um local ou ponto no mapa.",
            code="geocoder_not_configured",
            stage="configuration",
            retryable=False,
        )
    validate_budgets()
    parsed = urlparse(settings.NOMINATIM_URL)
    if (
        parsed.scheme not in ("https", "http")
        or not parsed.hostname
        or parsed.username
        or parsed.password
        or (parsed.query or parsed.fragment)
    ):
        raise ExternalServiceError(
            "URL base do geocodificador inválida.",
            code="geocoder_configuration",
            stage="configuration",
            retryable=False,
        )
    if settings.NOMINATIM_API_KEY and ("\n" in settings.NOMINATIM_API_KEY or "\r" in settings.NOMINATIM_API_KEY):
        raise ExternalServiceError(
            "Chave do geocodificador inválida.",
            code="geocoder_configuration",
            stage="configuration",
            retryable=False,
        )
    if settings.NOMINATIM_API_KEY and not re.fullmatch(r"[A-Za-z0-9-]+", settings.NOMINATIM_API_KEY_HEADER):
        raise ExternalServiceError(
            "Configure o cabeçalho da chave do geocodificador.",
            code="geocoder_configuration",
            stage="configuration",
            retryable=False,
        )
    public = parsed.hostname.rstrip(".").lower() == "nominatim.openstreetmap.org"
    if public:
        if (
            parsed.scheme != "https"
            or not settings.NOMINATIM_PUBLIC_OPT_IN
            or settings.GEO_NOMINATIM_COOLDOWN < 1
            or coordination_mode() != "shared"
        ):
            raise ExternalServiceError(
                "Nominatim público exige adesão explícita e coordenação compartilhada Redis.",
                code="public_geocoder_not_ready",
                stage="configuration",
                retryable=False,
            )
    return {
        "configured": True,
        "adapter": "Nominatim JSONv2",
        "coordination": coordination_mode(),
        "public": public,
    }
