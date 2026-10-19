"""Map correction regressions. Providers are controlled; no public network or personal points."""

import io
import json
import re
import socket
from datetime import datetime, timedelta, timezone
from email.utils import format_datetime
from unittest.mock import MagicMock, patch

import pytest
import requests
from django.core.cache import cache
from django.core.management import call_command, CommandError
from rest_framework.test import APIClient

from locais.discovery import valid_coordinates
from locais.models import Local
from locais.services.categories import CATEGORIES
from locais.services.external_places_service import (
    ExternalPlacesService,
    geocode,
    overpass_selectors,
    request_json,
    validate_geocoder_configuration,
)
from locais.services.geographic_runtime import ExternalServiceError, ProviderGate, retry_after

QUERY = {"latitude": 0.0, "longitude": 0.0, "raio": 1500, "limite": 100}


def response(payload=None, status=200, headers=None, raw=None):
    result = MagicMock()
    result.status_code = status
    result.headers = headers or {}
    result.__enter__.return_value = result
    result.iter_content.return_value = [raw if raw is not None else json.dumps(payload).encode()]
    return result


@pytest.fixture(autouse=True)
def isolated_cache(settings):
    settings.CACHES = {
        "default": {"BACKEND": "django.core.cache.backends.locmem.LocMemCache", "LOCATION": "map-correction-tests"}
    }
    settings.GEO_REQUIRE_SHARED_COORDINATION = False
    cache.clear()
    yield
    cache.clear()


@pytest.mark.django_db
def test_eight_internal_places_four_without_point_survive_general_and_paged_queries():
    # Four homonyms at the same point must remain four identities, even if clustered.
    points = [
        Local.objects.create(nome="Mesmo café", endereco="Galeria pública", distancia=0, latitude=0, longitude=0)
        for _ in range(4)
    ]
    missing = [Local.objects.create(nome=f"Sem ponto {i}", endereco="Rua de teste", distancia=0) for i in range(4)]
    api = APIClient()
    general = api.get("/api/locais/")
    assert len(general.data) == 8
    assert {r["id_local"] for r in general.data} == {r.pk for r in points + missing}
    page = api.get("/api/locais/", {"paginated": "true", "page_size": 3})
    ids = []
    while True:
        assert page.data["count"] == 8
        ids.extend(row["id_local"] for row in page.data["results"])
        if page.data["next"] is None:
            break
        page = api.get(page.data["next"])
    assert len(ids) == len(set(ids)) == 8
    area = api.get("/api/locais/", {"paginated": "true", "bbox": "0,0,0,0", "search": "café"})
    assert area.data["count"] == 4
    assert {row["id_local"] for row in area.data["results"]} == {row.pk for row in points}
    assert api.get(f"/api/locais/{missing[0].pk}/").status_code == 200


@pytest.mark.parametrize(
    "lat,lon,valid",
    [
        (0, 0, True),
        (-90, 180, True),
        (90, -180, True),
        (None, 0, False),
        (0, None, False),
        (True, 0, False),
        (0, False, False),
        (float("nan"), 0, False),
        (0, float("inf"), False),
        (90.1, 0, False),
        (0, 180.1, False),
    ],
)
def test_coordinate_pair(lat, lon, valid):
    assert valid_coordinates(lat, lon) is valid


@pytest.mark.parametrize(
    "header,expected,source",
    [
        ("0", 0, "upstream"),
        ("8640000", 8640000, "upstream"),
        ("not a date", 15, "application"),
        (None, 15, "application"),
        ("-1", 15, "application"),
        ("9" * 100, None, "upstream"),
    ],
)
def test_retry_after_seconds_and_fail_closed(header, expected, source):
    assert retry_after(header, 15) == (expected, source)


def test_retry_after_http_dates_past_and_long_future():
    now = datetime(2026, 10, 18, tzinfo=timezone.utc)
    for days in [-1, 7, 365]:
        value = format_datetime(now + timedelta(days=days), usegmt=True)
        assert retry_after(value, 15, now=now) == (max(0, days * 86400), "upstream")
    assert retry_after("Monday, 19-Oct-26 00:00:00 GMT", 15, now=now) == (86400, "upstream")
    assert retry_after("Mon Oct 19 00:00:00 2026", 15, now=now) == (86400, "upstream")


@pytest.mark.parametrize("status", [429, 502, 503, 504])
def test_upstream_status_header_cooldown_and_no_early_second_call(status):
    with patch(
        "locais.services.external_places_service.requests.post",
        return_value=response(status=status, headers={"Retry-After": "86400"}),
    ) as post:
        with pytest.raises(ExternalServiceError) as failure:
            request_json("overpass", "https://provider.invalid/api", data={"data": "controlled"})
        error = failure.value
        assert (error.status, error.upstream_status, error.stage, error.retry_after, error.retry_source) == (
            status,
            status,
            "upstream",
            86400,
            "upstream",
        )
        with pytest.raises(ExternalServiceError) as blocked:
            request_json("overpass", "https://provider.invalid/api", data={"data": "controlled"})
        assert blocked.value.code == "provider_cooldown" and blocked.value.retry_after >= 86399
        assert post.call_count == 1


@pytest.mark.parametrize(
    "failure,code,stage,status",
    [
        (requests.ConnectTimeout(), "connect_timeout", "connect", 504),
        (requests.ReadTimeout(), "read_timeout", "read", 504),
        (requests.exceptions.SSLError(), "tls_failed", "connect", 503),
        (requests.ConnectionError(socket.gaierror("hidden dns detail")), "dns_failed", "connect", 503),
    ],
)
def test_transport_failure_is_distinct_from_http_and_sanitized(failure, code, stage, status):
    with patch("locais.services.external_places_service.requests.get", side_effect=failure):
        with pytest.raises(ExternalServiceError) as caught:
            request_json("nominatim", "https://provider.invalid/search")
    error = caught.value
    assert (error.code, error.stage, error.status, error.upstream_status) == (code, stage, status, None)
    assert "hidden" not in str(error.as_dict())


@pytest.mark.parametrize(
    "payload,raw",
    [
        ({"remark": "runtime error", "elements": []}, None),
        ({"elements": {}}, None),
        ({"elements": [{}] * 500}, None),
        (None, b"<html>private details</html>"),
        (None, b"{bad json"),
    ],
)
def test_invalid_or_partial_is_not_empty_success_or_cached(payload, raw):
    with patch(
        "locais.services.external_places_service.requests.post", return_value=response(payload, raw=raw)
    ) as post:
        for _ in range(2):
            cache.delete("geo:gate:overpass")
            with pytest.raises(ExternalServiceError) as caught:
                ExternalPlacesService().search(**QUERY)
            assert caught.value.status == 502
        assert post.call_count == 2


def test_complete_empty_cache_metadata_expiry_and_exact_centres(settings):
    settings.EXTERNAL_PLACES_CACHE_SECONDS = 1
    settings.EXTERNAL_PLACES_MAX_AGE_SECONDS = 60
    settings.GEO_OVERPASS_COOLDOWN = 0
    with patch(
        "locais.services.external_places_service.requests.post", return_value=response({"elements": []})
    ) as post:
        with patch("time.time", return_value=1000):
            first = ExternalPlacesService().search(**QUERY)
            cached = ExternalPlacesService().search(**QUERY)
        assert first["complete"] is True and first["results"] == cached["results"] == []
        assert (first["fetched_at"], first["fresh_for_seconds"], first["valid_for_seconds"]) == (1000, 1, 60)
        assert post.call_count == 1
        with patch("time.time", return_value=1002):
            ExternalPlacesService().search(**QUERY)
            ExternalPlacesService().search(**{**QUERY, "latitude": 0.00000001})
        assert post.call_count == 3


def test_selector_union_covers_catalog_without_duplicating_shop():
    selectors = overpass_selectors()
    assert len(selectors) == 4 and selectors.count("[shop]") == 1
    for category in CATEGORIES.values():
        for selector in category["filters"]:
            if selector.startswith('[amenity~"^('):
                expected = set(selector.split("(")[1].split(")")[0].split("|"))
                combined = set(selectors[0].split("(")[1].split(")")[0].split("|"))
                assert expected <= combined
                continue
            key, _, value = selector.strip("[]").partition("=")
            assert (
                selector.startswith("[shop]")
                or selector in selectors
                or f"[{key}]" in selectors
                or any(
                    s.startswith(f'[{key}~"^(') and value in s.split("(")[1].split(")")[0].split("|")
                    for s in selectors
                )
            )
    with patch("locais.services.external_places_service.request_json", return_value={"elements": []}) as request:
        ExternalPlacesService().search(**QUERY)
        ql = request.call_args.kwargs["data"]["data"]
    assert ql.count("nwr") == 4 and "timeout:10" in ql and "maxsize:16777216" in ql
    assert re.search(r"out center 500", ql)


def test_cache_failure_prevents_provider_call():
    with patch("locais.services.geographic_runtime.cache.get", side_effect=ConnectionError("secret url")), patch(
        "locais.services.external_places_service.requests.post"
    ) as request:
        with pytest.raises(ExternalServiceError) as failure:
            ExternalPlacesService().search(**QUERY)
    assert failure.value.code == "cache_unavailable"
    request.assert_not_called()


def test_owner_release_cannot_unlock_successor():
    old = ProviderGate("overpass", "https://provider.invalid", "a")
    old.acquire()
    # Simulates expired lease and another owner; no sleep and no provider calls.
    cache.delete(old.key)
    successor = ProviderGate("overpass", "https://provider.invalid", "b")
    successor.acquire()
    old.release(0)
    with pytest.raises(ExternalServiceError) as failure:
        ProviderGate("overpass", "https://provider.invalid", "c").acquire()
    assert failure.value.code == "provider_busy"
    successor.release(0)
    ProviderGate("overpass", "https://provider.invalid", "d").acquire()


@pytest.mark.django_db
def test_normalized_error_envelope_headers_and_strict_query():
    api = APIClient()
    error = ExternalServiceError(
        "Mensagem segura",
        504,
        3600,
        code="upstream_http",
        stage="upstream",
        upstream_status=504,
        retry_source="upstream",
        correlation_id="fixture-id",
    )
    with patch.object(ExternalPlacesService, "search", side_effect=error):
        result = api.get("/api/locais/externos/", QUERY)
    assert result.status_code == 504 and result["Retry-After"] == "3600"
    assert result["X-Correlation-ID"] == result.data["correlation_id"] == "fixture-id"
    assert result.data["retry_source"] == "upstream" and result.data["upstream_status"] == 504
    assert result["Cache-Control"] == "private, no-store"
    with patch.object(ExternalPlacesService, "search") as request:
        assert api.get("/api/locais/externos/?latitude=0&latitude=1&longitude=0").status_code == 400
        assert api.get("/api/locais/externos/", {**QUERY, "extra": "injection"}).status_code == 400
        request.assert_not_called()


def test_disabled_geocoder_command_and_private_compatible_configuration(settings):
    settings.NOMINATIM_URL = ""
    output = io.StringIO()
    with patch("locais.services.external_places_service.requests.get") as request:
        call_command("check_geographic_provider", check_cache=True, stdout=output)
        with pytest.raises(CommandError, match="desativado"):
            call_command("check_geographic_provider", require_geocoder=True, stdout=io.StringIO())
        request.assert_not_called()
    assert json.loads(output.getvalue())["geocoder"]["configured"] is False
    settings.NOMINATIM_URL = "https://provider.invalid/nominatim"
    settings.NOMINATIM_API_KEY = "fixture-private-key"
    settings.NOMINATIM_API_KEY_HEADER = "X-Api-Key"
    assert validate_geocoder_configuration()["coordination"] == "process"
    with patch("locais.services.external_places_service.requests.get", return_value=response([])) as request:
        assert geocode({"q": "Praça pública"}) == []
        assert request.call_args.kwargs["headers"]["X-Api-Key"] == "fixture-private-key"
        assert request.call_args.kwargs["allow_redirects"] is False
    output = io.StringIO()
    call_command("check_geographic_provider", stdout=output)
    assert "fixture-private-key" not in output.getvalue() and "provider.invalid" not in output.getvalue()


@pytest.mark.parametrize("public", [False, True])
def test_public_geocoder_never_calls_with_local_coordination(settings, public):
    settings.NOMINATIM_URL = "https://nominatim.openstreetmap.org"
    settings.NOMINATIM_PUBLIC_OPT_IN = public
    with patch("locais.services.external_places_service.requests.get") as request:
        with pytest.raises(ExternalServiceError, match="adesão"):
            geocode({"q": "Praça pública"})
        request.assert_not_called()


def test_required_shared_coordination_fails_closed(settings):
    settings.GEO_REQUIRE_SHARED_COORDINATION = True
    with patch("locais.services.external_places_service.requests.post") as request:
        with pytest.raises(ExternalServiceError) as failure:
            ExternalPlacesService().search(**QUERY)
        assert failure.value.code == "coordination_unavailable"
        request.assert_not_called()


@pytest.mark.parametrize(
    "name,value",
    [("GEO_READ_TIMEOUT", float("nan")), ("GEO_TOTAL_TIMEOUT", 31), ("EXTERNAL_PLACES_MAX_AGE_SECONDS", 100)],
)
def test_invalid_budgets_fail_before_network(settings, name, value):
    setattr(settings, name, value)
    with patch("locais.services.external_places_service.requests.post") as request:
        with pytest.raises(ExternalServiceError) as failure:
            ExternalPlacesService().search(**QUERY)
        assert failure.value.stage == "configuration"
        request.assert_not_called()
