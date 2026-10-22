"""Atomic fixed-window counters. Shared Redis is mandatory in staging."""
import math
import time

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
        identifier = body.get("email", body.get("uid", body.get("nome", "")))
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
