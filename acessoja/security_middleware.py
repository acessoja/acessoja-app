"""Trusted proxy boundary and minimal, structured operational events."""
import ipaddress
import json
import logging
import time
import uuid

from django.conf import settings

logger = logging.getLogger("acessoja.security")


class ProxyGuardMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        try:
            address = ipaddress.ip_address(request.META.get("REMOTE_ADDR", ""))
            trusted = any(address in ipaddress.ip_network(net) for net in settings.TRUSTED_PROXY_CIDRS)
        except ValueError:
            trusted = False
        # Even trusted proxies cannot pass through arbitrary forwarding chains.
        proto = request.META.get("HTTP_X_FORWARDED_PROTO") if trusted else None
        real_ip = request.META.get("HTTP_X_REAL_IP") if trusted else None
        for name in ("HTTP_FORWARDED", "HTTP_X_FORWARDED_FOR", "HTTP_X_FORWARDED_HOST",
                     "HTTP_X_FORWARDED_PORT", "HTTP_X_FORWARDED_PROTO", "HTTP_X_REAL_IP"):
            request.META.pop(name, None)
        if proto in {"https", "http"}:
            request.META["HTTP_X_FORWARDED_PROTO"] = proto
        if real_ip:
            try:
                request.META["REMOTE_ADDR"] = str(ipaddress.ip_address(real_ip))
            except ValueError:
                pass
        return self.get_response(request)


class SafeEventFormatter(logging.Formatter):
    """Allowlist fields instead of attempting to redact every possible secret."""

    def format(self, record):
        event = getattr(record, "security_event", "application_event")
        allowed = {"http_request", "mail_sent", "mail_discarded", "mail_failed", "mail_expired", "privacy_deleted",
                   "restore_privacy_applied", "application_event"}
        data = {"event": event if event in allowed else "application_event", "level": record.levelname}
        for name in ("correlation_id", "status", "duration_ms"):
            value = getattr(record, name, None)
            if name == "correlation_id":
                try:
                    uuid.UUID(str(value))
                except (ValueError, TypeError):
                    continue
            elif not isinstance(value, (int, float)):
                continue
            data[name] = value
        return json.dumps(data, ensure_ascii=True, separators=(",", ":"))


class SecurityAuditMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        started = time.monotonic()
        # Do not echo untrusted user input into logs or response headers.
        request.correlation_id = str(uuid.uuid4())
        response = self.get_response(request)
        existing = response.get("X-Correlation-ID")
        if existing:
            try:
                uuid.UUID(existing)
                request.correlation_id = existing
            except ValueError:
                pass  # Preserve a server-generated provider header; never log arbitrary text.
        else:
            response["X-Correlation-ID"] = request.correlation_id
        if request.path.startswith(("/auth/", "/api/usuarios/", "/api/favoritos/", "/api/route-history/",
                                    "/api/visitas/", "/api/contribuicoes/")):
            response["Cache-Control"] = "private, no-store"
            response["Pragma"] = "no-cache"
        logger.info("http_request", extra={"security_event": "http_request",
                    "correlation_id": request.correlation_id, "status": response.status_code,
                                           "duration_ms": round((time.monotonic() - started) * 1000, 2)})
        return response
