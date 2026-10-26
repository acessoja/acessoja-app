"""Fail closed on unsafe deployment configuration; local development stays explicit."""
import ipaddress
from pathlib import Path
from urllib.parse import urlsplit

from django.core.exceptions import ImproperlyConfigured
from django.core.exceptions import ValidationError
from django.core.validators import URLValidator


def require(condition, message):
    if not condition:
        raise ImproperlyConfigured(message)


def public_origin(value, secure=False):
    try:
        URLValidator(schemes=["https"] if secure else ["http", "https"])(value)
    except ValidationError:
        raise ImproperlyConfigured("Invalid public origin.") from None
    url = urlsplit(value)
    require(url.scheme in ({"https"} if secure else {"https", "http"}) and url.hostname
            and not url.username and not url.password and url.path in {"", "/"}
            and not url.query and not url.fragment, "Invalid FRONTEND_PUBLIC_ORIGIN.")
    return value.rstrip("/")


def configure_security(config, env):
    stage = env("APP_ENV", default="local")
    require(stage in {"local", "staging"}, "APP_ENV must be local or staging.")
    strict = stage == "staging"
    origin = public_origin(env("FRONTEND_PUBLIC_ORIGIN", default="http://localhost:7357"), strict)
    reset_url = env("PASSWORD_RESET_CONFIRM_URL", default="#/recuperar-senha/{uid}/{token}")
    require(reset_url == "#/recuperar-senha/{uid}/{token}", "Unsupported PASSWORD_RESET_CONFIRM_URL route.")
    tls, ssl = env.bool("EMAIL_USE_TLS", default=False), env.bool("EMAIL_USE_SSL", default=False)
    require(not (tls and ssl), "EMAIL_USE_TLS and EMAIL_USE_SSL are mutually exclusive.")
    email_timeout = env.int("EMAIL_TIMEOUT", default=10)
    require(1 <= email_timeout <= 30, "EMAIL_TIMEOUT must be between 1 and 30 seconds.")
    timeout = env.int("PASSWORD_RESET_TIMEOUT", default=1800)
    require(60 <= timeout <= 86400, "PASSWORD_RESET_TIMEOUT must be between 60 and 86400 seconds.")
    proxies = env.list("TRUSTED_PROXY_CIDRS", default=[])
    for value in proxies:
        try:
            network = ipaddress.ip_network(value)
        except ValueError:
            raise ImproperlyConfigured("Invalid TRUSTED_PROXY_CIDRS.") from None
        require(network.prefixlen > 0, "A wildcard proxy network is not trusted.")
    mail_backend = env("EMAIL_BACKEND", default="django.core.mail.backends.smtp.EmailBackend")
    config.update(
        APP_ENV=stage, FRONTEND_PUBLIC_ORIGIN=origin, PASSWORD_RESET_TIMEOUT=timeout,
        PASSWORD_RESET_CONFIRM_URL=reset_url,
        EMAIL_BACKEND=mail_backend, EMAIL_HOST=env("EMAIL_HOST", default="localhost"),
        EMAIL_PORT=env.int("EMAIL_PORT", default=1025), EMAIL_HOST_USER=env("EMAIL_HOST_USER", default=""),
        EMAIL_HOST_PASSWORD=env("EMAIL_HOST_PASSWORD", default=""), EMAIL_TIMEOUT=email_timeout,
        EMAIL_USE_TLS=tls, EMAIL_USE_SSL=ssl,
        DEFAULT_FROM_EMAIL=env("DEFAULT_FROM_EMAIL", default="AcessoJa <no-reply@localhost>"),
        TRUSTED_PROXY_CIDRS=proxies, USE_X_FORWARDED_HOST=False,
        SECURE_PROXY_SSL_HEADER=("HTTP_X_FORWARDED_PROTO", "https") if proxies else None,
        SECURE_REFERRER_POLICY="same-origin", SESSION_COOKIE_HTTPONLY=True,
        SESSION_COOKIE_SAMESITE="Lax", CSRF_COOKIE_SAMESITE="Lax",
        CSRF_TRUSTED_ORIGINS=env.list("CSRF_TRUSTED_ORIGINS", default=[]),
        STATIC_ROOT=Path(env("STATIC_ROOT", default=str(config["BASE_DIR"] / "staticfiles"))),
        MEDIA_ROOT=Path(env("MEDIA_ROOT", default=str(config["BASE_DIR"] / "private-media"))),
        MEDIA_URL="/private-media/", DATA_UPLOAD_MAX_MEMORY_SIZE=3 * 1024 * 1024,
        PRIVACY_NOTICE_VERSION="2026-10-21", PRIVACY_EXPORT_MAX_ROWS=10000,
        PRIVACY_CONTACT_EMAIL=env("PRIVACY_CONTACT_EMAIL", default=""),
        PRIVACY_EXPORT_MAX_BYTES=8 * 1024 * 1024,
        DELETION_JOURNAL_DIR=Path(env("DELETION_JOURNAL_DIR", default=str(config["BASE_DIR"] / "private-deletions"))),
        ACCOUNT_MAIL_MAX_PENDING=10000, ACCOUNT_MAIL_MAX_AGE=3600, ACCOUNT_MAIL_MAX_ATTEMPTS=5,
        SECURITY_RATES={
            "reset_request": (30, 5, 3600), "reset_confirm": (30, 10, 900),
            "login": (30, 10, 60), "export": (20, 3, 3600),
            "delete": (30, 5, 3600), "password_change": (30, 10, 3600),
        },
    )
    require(bool(config["EMAIL_HOST_USER"]) == bool(config["EMAIL_HOST_PASSWORD"]),
            "SMTP username and password must be configured together.")
    config["MIDDLEWARE"].insert(0, "acessoja.security_middleware.ProxyGuardMiddleware")
    config["MIDDLEWARE"].append("acessoja.security_middleware.SecurityAuditMiddleware")
    url = urlsplit(origin)
    config["DJOSER"].update({
        "PASSWORD_RESET_CONFIRM_URL": reset_url, "PASSWORD_RESET_CONFIRM_RETYPE": True,
        "SET_PASSWORD_RETYPE": True, "PASSWORD_RESET_SHOW_EMAIL_NOT_FOUND": False,
        "LOGOUT_ON_PASSWORD_CHANGE": True, "CREATE_SESSION_ON_LOGIN": False, "HIDE_USERS": True,
        "EMAIL_FRONTEND_PROTOCOL": url.scheme, "EMAIL_FRONTEND_DOMAIN": url.netloc,
        "SERIALIZERS": {"user": "usuarios.account_serializers.AccountUserSerializer",
                        "current_user": "usuarios.account_serializers.AccountUserSerializer",
                        "user_create": "usuarios.account_serializers.AccountCreateSerializer"},
    })
    if strict:
        require(bool(env("ALLOWED_HOSTS", default="")), "Set ALLOWED_HOSTS explicitly in staging.")
        require(not config["DEBUG"], "DEBUG must be False in staging.")
        key = config["SECRET_KEY"]
        require(len(key) >= 50 and len(set(key)) >= 8 and not any(
            word in key.lower() for word in ("example", "change-me", "gere-uma", "ci-secret", "insecure")
        ), "A strong, private SECRET_KEY is required in staging.")
        require(config["ALLOWED_HOSTS"] and all(
            host and "*" not in host and not host.startswith(".")
            for host in config["ALLOWED_HOSTS"]
        ), "Explicit ALLOWED_HOSTS are required in staging.")
        require(config["DATABASES"]["default"]["ENGINE"] == "django.db.backends.postgresql",
                "PostgreSQL is required in staging.")
        require(config["CACHES"]["default"]["BACKEND"] == "django.core.cache.backends.redis.RedisCache",
                "Shared Redis is required in staging.")
        require(mail_backend == "django.core.mail.backends.smtp.EmailBackend" and config["EMAIL_HOST"]
                and (tls or ssl), "Staging requires a real SMTP transport with TLS or SSL.")
        require("@localhost" not in config["DEFAULT_FROM_EMAIL"], "Configure a staging mail sender.")
        require(proxies, "Configure the exact trusted proxy network.")
        for name in ("CORS_ALLOWED_ORIGINS", "CSRF_TRUSTED_ORIGINS"):
            require(config[name] and all(public_origin(item, True) == item for item in config[name]),
                    f"Explicit HTTPS {name} are required.")
        require(env("DELETION_JOURNAL_DIR", default="").startswith("/"),
                "Use an absolute, independently persisted DELETION_JOURNAL_DIR.")
        config.update(SECURE_SSL_REDIRECT=True, SESSION_COOKIE_SECURE=True, CSRF_COOKIE_SECURE=True,
                      SECURE_HSTS_SECONDS=3600, SECURE_HSTS_INCLUDE_SUBDOMAINS=False, SECURE_HSTS_PRELOAD=False,
                      SECURE_REDIRECT_EXEMPT=[r"^health/live/$", r"^health/ready/$"],
                      GEO_REQUIRE_SHARED_COORDINATION=True)
        config["REST_FRAMEWORK"]["DEFAULT_AUTHENTICATION_CLASSES"] = [
            "acessoja.authentication.ExpiringTokenAuthentication"
        ]
        config["SPECTACULAR_SETTINGS"].update(
            SERVE_PERMISSIONS=["rest_framework.permissions.IsAdminUser"],
            SERVE_AUTHENTICATION=["acessoja.authentication.ExpiringTokenAuthentication",
                                  "rest_framework.authentication.SessionAuthentication"],
        )
        # The pilot proxy protects Admin/docs as well. No request bodies, headers,
        # query strings, exception messages or provider URLs reach deployment logs.
        config["LOGGING"] = {
            "version": 1, "disable_existing_loggers": False,
            "formatters": {"safe": {"()": "acessoja.security_middleware.SafeEventFormatter"}},
            "handlers": {"safe": {"class": "logging.StreamHandler", "formatter": "safe"}},
            "root": {"handlers": ["safe"], "level": "INFO"},
            "loggers": {name: {"handlers": ["safe"], "level": "INFO", "propagate": False}
                        for name in ("django", "django.server", "django.request", "acessoja.geographic")},
        }
        log_dir = env("SECURE_LOG_DIR", default="")
        require(log_dir.startswith("/"), "Configure an absolute protected SECURE_LOG_DIR.")
        config["LOGGING"]["handlers"]["safe"].update(
            {"class": "logging.handlers.WatchedFileHandler", "filename": str(Path(log_dir) / "app.json.log"),
             "encoding": "utf-8", "delay": True})
        require(bool(env("PRIVACY_CONTACT_EMAIL", default="")), "Configure the pilot privacy contact.")
    config["SPECTACULAR_SETTINGS"]["SWAGGER_UI_SETTINGS"]["persistAuthorization"] = False
