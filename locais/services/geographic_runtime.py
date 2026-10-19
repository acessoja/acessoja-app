"""Provider budgets. LocMem is one-process only; Redis uses owner-checked Lua leases."""

import hashlib
import json
import logging
import math
import re
import threading
import time
import uuid
from urllib.parse import urlsplit
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime

from django.conf import settings
from django.core.cache import cache

logger = logging.getLogger("acessoja.geographic")
_local_mutex = threading.RLock()
REDIS_BACKEND = "django.core.cache.backends.redis.RedisCache"
LOCAL_BACKEND = "django.core.cache.backends.locmem.LocMemCache"
LEASE_SECONDS = 90


class ExternalServiceError(Exception):
    def __init__(
        self,
        detail,
        status=503,
        retry_after=15,
        *,
        code="provider_unavailable",
        stage="application",
        upstream_status=None,
        retry_source="application",
        correlation_id=None,
        retryable=True,
    ):
        self.detail, self.status, self.retry_after = detail, status, retry_after
        self.code, self.stage, self.upstream_status = code, stage, upstream_status
        self.retry_source, self.retryable = retry_source, retryable and retry_after is not None
        self.correlation_id = correlation_id or uuid.uuid4().hex
        super().__init__(detail)
        event(
            "failure",
            self.correlation_id,
            status=status,
            code=code,
            stage=stage,
            upstream_status=upstream_status,
            retry_source=retry_source,
        )

    def as_dict(self):
        return {
            "detail": self.detail,
            "code": self.code,
            "stage": self.stage,
            "upstream_status": self.upstream_status,
            "retryable": self.retryable,
            "retry_after_seconds": self.retry_after,
            "retry_source": self.retry_source,
            "correlation_id": self.correlation_id,
        }


def event(name, correlation_id, **fields):
    # No URLs, coordinates, terms, user identities, tokens or upstream bodies.
    allowed = {
        "provider",
        "status",
        "upstream_status",
        "stage",
        "cache",
        "count",
        "raw_count",
        "milliseconds",
        "code",
        "selectors",
        "retry_source",
    }
    logger.info(
        "geographic %s",
        json.dumps(
            {"event": name, "correlation_id": correlation_id, **{k: v for k, v in fields.items() if k in allowed}},
            sort_keys=True,
        ),
    )


def retry_after(header, fallback, *, now=None):
    """Return seconds and source. None means an unrepresentably long valid delay: fail closed."""
    if not isinstance(header, str):
        return fallback, "application"
    value = header.strip()
    if value.isascii() and value.isdigit():
        # Lua/Redis and web timers cannot safely schedule arbitrary integers.
        # Refuse automatic recovery for impractical delays rather than shorten them.
        if len(value) > 12 or int(value) > 100_000_000_000:
            return None, "upstream"
        return int(value), "upstream"
    try:
        date = parsedate_to_datetime(value)
        if date.tzinfo is None:
            # The asctime HTTP-date form omits GMT; RFC 9110 still defines it as UTC.
            if not re.fullmatch(r"[A-Za-z]{3} [A-Za-z]{3} +[0-9]{1,2} [0-9]{2}:[0-9]{2}:[0-9]{2} [0-9]{4}", value):
                raise ValueError
            date = date.replace(tzinfo=timezone.utc)
        current = now or datetime.now(timezone.utc)
        return max(0, math.ceil((date - current).total_seconds())), "upstream"
    except (TypeError, ValueError, OverflowError):
        return fallback, "application"


def cached_get(key, correlation_id):
    try:
        return cache.get(key)
    except Exception as exc:
        event("cache_failed", correlation_id, code="cache_unavailable", stage="cache")
        raise ExternalServiceError(
            "Cache geográfico indisponível. Tente novamente mais tarde.",
            code="cache_unavailable",
            stage="cache",
            correlation_id=correlation_id,
        ) from exc


def cached_set(key, value, seconds, correlation_id):
    try:
        cache.set(key, value, timeout=seconds)
    except Exception as exc:
        raise ExternalServiceError(
            "Cache geográfico indisponível. Tente novamente mais tarde.",
            code="cache_unavailable",
            stage="cache",
            correlation_id=correlation_id,
        ) from exc


def coordination_mode():
    backend = settings.CACHES["default"]["BACKEND"]
    if backend == REDIS_BACKEND:
        return "shared"
    if backend == LOCAL_BACKEND and not getattr(settings, "GEO_REQUIRE_SHARED_COORDINATION", False):
        return "process"
    raise ExternalServiceError(
        "Configure Redis para coordenação geográfica compartilhada.",
        code="coordination_unavailable",
        stage="configuration",
        retryable=False,
    )


_ACQUIRE = """
local t = redis.call('TIME')
local now = tonumber(t[1]) + tonumber(t[2])/1000000
local raw = redis.call('GET', KEYS[1])
if raw then
  local v = cjson.decode(raw)
  if v.forever or v.until_at > now then
    local wait = v.forever and -1 or math.ceil(v.until_at-now)
    if v.owner then wait = math.min(wait,2) end
    return {0,wait,v.source or 'application',v.owner and 'provider_busy' or 'provider_cooldown'}
  end
end
redis.call('SET',KEYS[1],cjson.encode({owner=ARGV[1],until_at=now+tonumber(ARGV[2]),source='application'}),
  'PX',tonumber(ARGV[2])*1000)
return {1,0,'application',''}
"""
_RELEASE = """
local raw = redis.call('GET',KEYS[1])
if not raw or cjson.decode(raw).owner ~= ARGV[1] then return 0 end
if ARGV[2] == '-1' then
  redis.call('SET',KEYS[1],cjson.encode({forever=true,source=ARGV[3]}))
else
  local t = redis.call('TIME')
  local now = tonumber(t[1]) + tonumber(t[2])/1000000
  local delay = tonumber(ARGV[2])
  if delay <= 0 then redis.call('DEL',KEYS[1]) else
    redis.call('SET',KEYS[1],cjson.encode({until_at=now+delay,source=ARGV[3]}),'PX',math.ceil(delay*1000))
  end
end
return 1
"""


class ProviderGate:
    def __init__(self, kind, url, correlation_id):
        validate_budgets()
        self.kind, self.correlation_id = kind, correlation_id
        self.owner = uuid.uuid4().hex
        self.mode = coordination_mode()
        self.key = f"geo:gate:{kind}"
        self.client = None
        if self.mode == "shared":
            # Django 5.1 RedisCacheClient: a single writable leader, never a stale replica for locks.
            self.key = cache.make_key(
                self.key
                + ":"
                + hashlib.sha256(
                    (
                        f"{urlsplit(url).scheme.lower()}://{urlsplit(url).netloc.lower()}"
                        if kind == "nominatim"
                        else url.rstrip("/")
                    ).encode()
                ).hexdigest()
            )
            try:
                self.client = cache._cache.get_client(self.key, write=True)
            except Exception as exc:
                raise ExternalServiceError(
                    "Controle compartilhado indisponível.",
                    code="coordination_unavailable",
                    stage="cache",
                    correlation_id=correlation_id,
                ) from exc

    def acquire(self):
        try:
            if self.client is not None:
                answer = self.client.eval(_ACQUIRE, 1, self.key, self.owner, LEASE_SECONDS)
                if int(answer[0]):
                    return
                seconds = int(answer[1])
                source = answer[2].decode() if isinstance(answer[2], bytes) else answer[2]
                code = answer[3].decode() if isinstance(answer[3], bytes) else answer[3]
                self._blocked(None if seconds < 0 else seconds, source, code)
            else:
                with _local_mutex:
                    current = cache.get(self.key)
                    now = time.time()
                    if current:
                        if not isinstance(current, dict):
                            self._blocked(2, "application", "provider_busy")
                        if current.get("forever") or current["until_at"] > now:
                            wait = None if current.get("forever") else max(0, math.ceil(current["until_at"] - now))
                            self._blocked(
                                min(wait, 2) if current.get("owner") and wait is not None else wait,
                                current.get("source", "application"),
                                "provider_busy" if current.get("owner") else "provider_cooldown",
                            )
                    cache.set(self.key, {"owner": self.owner, "until_at": now + LEASE_SECONDS}, LEASE_SECONDS)
        except ExternalServiceError:
            raise
        except Exception as exc:
            raise ExternalServiceError(
                "Controle de consultas indisponível. Aguarde e tente novamente.",
                code="coordination_unavailable",
                stage="cache",
                correlation_id=self.correlation_id,
            ) from exc

    def _blocked(self, seconds, source, code):
        event(
            "blocked",
            self.correlation_id,
            provider=self.kind,
            code=code,
            stage="coordination",
            retry_source=source,
        )
        raise ExternalServiceError(
            "Fonte ocupada. Aguarde antes de tentar novamente.",
            429,
            seconds,
            code=code,
            stage="coordination",
            retry_source=source,
            correlation_id=self.correlation_id,
        )

    def release(self, seconds, source="application"):
        try:
            if self.client is not None:
                self.client.eval(_RELEASE, 1, self.key, self.owner, -1 if seconds is None else seconds, source)
            else:
                with _local_mutex:
                    current = cache.get(self.key)
                    if isinstance(current, dict) and current.get("owner") == self.owner:
                        value = {
                            "source": source,
                            "forever": seconds is None,
                            "until_at": time.time() + (seconds or 0),
                        }
                        cache.set(self.key, value, None if seconds is None else max(1, seconds))
        except Exception as exc:
            # No successful response may hide failure to enforce a mandatory cooldown.
            raise ExternalServiceError(
                "Controle de consultas indisponível. Tente novamente mais tarde.",
                code="coordination_unavailable",
                stage="cache",
                correlation_id=self.correlation_id,
            ) from exc


def validate_budgets():
    values = [
        settings.GEO_CONNECT_TIMEOUT,
        settings.GEO_READ_TIMEOUT,
        settings.GEO_TOTAL_TIMEOUT,
        settings.GEO_OVERPASS_COOLDOWN,
        settings.GEO_NOMINATIM_COOLDOWN,
        settings.GEO_RATE_LIMIT_COOLDOWN,
        settings.EXTERNAL_PLACES_CACHE_SECONDS,
        settings.EXTERNAL_PLACES_MAX_AGE_SECONDS,
    ]
    if any(not isinstance(v, (int, float)) or isinstance(v, bool) or not math.isfinite(v) for v in values) or not (
        0 < values[0] <= 10
        and 0 < values[1] <= 20
        and 0 < values[2] <= 30
        and all(0 <= v <= 3600 for v in values[3:7])
        and values[6] <= values[7] <= 86400
        and values[7] > 0
    ):
        raise ExternalServiceError(
            "Revise os limites de tempo e validade geográficos.",
            code="geographic_configuration",
            stage="configuration",
            retryable=False,
        )
