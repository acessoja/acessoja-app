"""Atomic fixed-window counters. Shared Redis is mandatory in staging."""
import math
import time
import threading

from django.conf import settings
from django.core.cache import cache
from django.utils.crypto import salted_hmac
from rest_framework.exceptions import APIException
from rest_framework.throttling import BaseThrottle


class SecurityUnavailable(APIException):
    status_code = 503
    default_detail = "Serviço temporariamente indisponível. Tente novamente mais tarde."


class SecurityThrottle(BaseThrottle):
    def allow_request(self, request, view):
        scope = getattr(view, "security_scope", None)
        if not scope:
            return True
        ip_limit, identifier_limit, period = settings.SECURITY_RATES[scope]
        body = request.data if isinstance(request.data, dict) else {}
        identifier = (body.get("nome", "") if getattr(view, "credential_login", False)
                      else body.get("email", body.get("uid", body.get("nome", ""))))
        if request.user.is_authenticated:
            identifier = str(request.user.pk)
        identifier = str(identifier)[:512].strip().casefold()
        now = time.time()
        bucket = int(now // period)
        self.remaining = max(1, math.ceil((bucket + 1) * period - now))
        limits = [("ip", request.META.get("REMOTE_ADDR", ""), ip_limit), ("id", identifier, identifier_limit)]
        admitted = True
        try:
            for kind, value, maximum in limits:
                digest = salted_hmac("acessoja.security.throttle", f"{scope}:{kind}:{value}",
                                     algorithm="sha256").hexdigest()
                key = f"security:{scope}:{bucket}:{digest}"
                if cache.add(key, 1, timeout=period + 1):
                    count = 1
                else:
                    count = cache.incr(key)
                admitted = admitted and count <= maximum
        except Exception:
            # No fallback to an uncoordinated counter while Redis is unavailable.
            raise SecurityUnavailable() from None
        return admitted

    def wait(self):
        return self.remaining


class LoginProtection:
    """Credential failures only; one pair counter across all login contracts.

    Redis executes the transition atomically. LocMem is for local tests only.
    The base throttle still limits aggregate identifier/IP request volume.
    """
    _lock = threading.Lock()
    _script = """
    local count = redis.call('INCR', KEYS[1])
    if count == 1 then redis.call('EXPIRE', KEYS[1], ARGV[1]) end
    local delay = 0
    if count >= tonumber(ARGV[7]) then delay = tonumber(ARGV[8])
    elseif count >= tonumber(ARGV[5]) then delay = tonumber(ARGV[6])
    elseif count >= tonumber(ARGV[3]) then delay = tonumber(ARGV[4]) end
    if delay > 0 then redis.call('SET', KEYS[2], ARGV[2] + delay, 'EX', delay) end
    return count
    """

    def __init__(self, request, identifier):
        digest = salted_hmac("acessoja.login.failures",
                             f"{str(identifier).strip().casefold()}:{request.META.get('REMOTE_ADDR', '')}",
                             algorithm="sha256").hexdigest()
        self.key = f"login-failures:{digest}"
        self.cooldown = self.key + ":cooldown"

    def check(self):
        from rest_framework.exceptions import Throttled
        try:
            until = float(cache.get(self.cooldown) or 0)
        except Exception:
            raise SecurityUnavailable() from None
        remaining = math.ceil(until - time.time())
        if remaining > 0:
            raise Throttled(wait=remaining, detail="Muitas tentativas. Aguarde para tentar novamente.")

    def result(self, success):
        try:
            if success:
                cache.delete_many([self.key, self.cooldown])
                return
            horizon = settings.LOGIN_FAILURE_WINDOW
            stages = settings.LOGIN_FAILURE_STAGES
            if settings.CACHES["default"]["BACKEND"] == "django.core.cache.backends.redis.RedisCache":
                client = cache._cache.get_client(self.key, write=True)
                client.eval(self._script, 2, cache.make_key(self.key), cache.make_key(self.cooldown),
                            horizon, int(time.time()), *(value for stage in stages for value in stage))
            else:
                if settings.APP_ENV != "local":
                    raise SecurityUnavailable()
                with self._lock:
                    if cache.add(self.key, 1, timeout=horizon):
                        count = 1
                    else:
                        count = cache.incr(self.key)
                    delay = max((delay for threshold, delay in stages if count >= threshold), default=0)
                    if delay:
                        cache.set(self.cooldown, time.time() + delay, timeout=delay)
        except Exception:
            raise SecurityUnavailable() from None
