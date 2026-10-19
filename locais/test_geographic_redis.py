"""Actual independent processes and Redis Lua. Opt in with an isolated Redis DB URL."""

import json
import multiprocessing
import os
import time
import uuid
from unittest.mock import patch

import pytest
from django.core.cache import cache
from django.test import override_settings

from locais.services.geographic_runtime import ExternalServiceError, ProviderGate

REDIS_URL = os.environ.get("GEOGRAPHIC_REDIS_TEST_URL")
pytestmark = pytest.mark.skipif(
    not REDIS_URL, reason="Requires actual isolated Redis; see geographic-coordination CI"
)


def redis_settings(url):
    return {
        "default": {
            "BACKEND": "django.core.cache.backends.redis.RedisCache",
            "LOCATION": url,
            "KEY_PREFIX": "geographic-regression",
        }
    }


def acquire_in_process(url, address, start, release, output):
    import django

    django.setup()
    with override_settings(CACHES=redis_settings(url), GEO_REQUIRE_SHARED_COORDINATION=True):
        gate = ProviderGate("overpass", address, uuid.uuid4().hex)
        start.wait(10)
        try:
            gate.acquire()
            output.put(("acquired", os.getpid(), gate.owner))
            release.wait(10)
            gate.release(3600, "upstream")
        except ExternalServiceError as failure:
            output.put((failure.code, failure.status, failure.retry_after))


def test_redis_independent_workers_one_lease_and_shared_long_cooldown():
    address = "https://provider.invalid/" + uuid.uuid4().hex
    ctx = multiprocessing.get_context("spawn")
    start, release, output = ctx.Event(), ctx.Event(), ctx.Queue()
    workers = [
        ctx.Process(target=acquire_in_process, args=(REDIS_URL, address, start, release, output)) for _ in range(4)
    ]
    try:
        for worker in workers:
            worker.start()
        start.set()
        results = [output.get(timeout=15) for _ in workers]
        assert sum(row[0] == "acquired" for row in results) == 1
        assert sum(row[:2] == ("provider_busy", 429) for row in results) == 3
        release.set()
        for worker in workers:
            worker.join(15)
            assert worker.exitcode == 0
        with override_settings(CACHES=redis_settings(REDIS_URL), GEO_REQUIRE_SHARED_COORDINATION=True):
            gate = ProviderGate("overpass", address, "parent")
            with pytest.raises(ExternalServiceError) as failure:
                gate.acquire()
            assert failure.value.code == "provider_cooldown"
            assert failure.value.retry_source == "upstream"
            assert 3590 <= failure.value.retry_after <= 3600
            assert gate.client.pttl(gate.key) > 3_590_000
            gate.client.delete(gate.key)
    finally:
        release.set()
        for worker in workers:
            if worker.is_alive():
                worker.terminate()
                worker.join(5)
        output.close()


def test_redis_lease_expiry_recovers_and_old_owner_cannot_release_new_owner():
    address = "https://provider.invalid/" + uuid.uuid4().hex
    with override_settings(CACHES=redis_settings(REDIS_URL), GEO_REQUIRE_SHARED_COORDINATION=True):
        old = ProviderGate("overpass", address, "old")
        old.acquire()
        assert 89_000 <= old.client.pttl(old.key) <= 90_000
        old.client.pexpire(old.key, 30)  # Controlled expiry, not a 90s CI sleep.
        deadline = time.monotonic() + 2
        while old.client.exists(old.key) and time.monotonic() < deadline:
            time.sleep(0.01)
        assert not old.client.exists(old.key)
        new = ProviderGate("overpass", address, "new")
        new.acquire()
        old.release(0)
        assert json.loads(new.client.get(new.key))["owner"] == new.owner
        new.release(None, "upstream")
        with pytest.raises(ExternalServiceError) as failure:
            ProviderGate("overpass", address, "blocked").acquire()
        assert failure.value.retry_after is None and not failure.value.retryable
        assert new.client.pttl(new.key) == -1
        new.client.delete(new.key)


def test_redis_nominatim_origin_budget_public_opt_in_and_coordination_failure(settings):
    from locais.services.external_places_service import validate_geocoder_configuration

    with override_settings(CACHES=redis_settings(REDIS_URL), GEO_REQUIRE_SHARED_COORDINATION=True):
        settings.NOMINATIM_URL = "https://nominatim.openstreetmap.org"
        settings.NOMINATIM_PUBLIC_OPT_IN = True
        assert validate_geocoder_configuration()["coordination"] == "shared"
        search = ProviderGate("nominatim", settings.NOMINATIM_URL + "/search", "search")
        reverse = ProviderGate("nominatim", settings.NOMINATIM_URL + "/reverse", "reverse")
        assert search.key == reverse.key
        search.client.delete(search.key)
        search.acquire()
        with pytest.raises(ExternalServiceError, match="ocupada"):
            reverse.acquire()
        search.release(0)
        with patch.object(cache._cache, "get_client", side_effect=ConnectionError("not exposed")):
            with pytest.raises(ExternalServiceError) as failure:
                ProviderGate("nominatim", settings.NOMINATIM_URL, "error")
        assert failure.value.code == "coordination_unavailable"
