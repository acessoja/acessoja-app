"""TLS terminates at the exact private proxy; access logs come from middleware."""
import os

bind = "0.0.0.0:8000"
workers = 2
threads = 1
timeout = 90  # Image clients wait 60s; uncertain outcomes are reconciled by operation id.
accesslog = None
# Let Django's guarded logging handle operational events; never log requests.
errorlog = "-"
capture_output = False
forwarded_allow_ips = ""  # Only ProxyGuardMiddleware interprets trusted forwarding.
preload_app = False


def post_fork(server, worker):
    import django
    from django.conf import settings
    from logging.config import dictConfig
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "acessoja.settings_staging")
    django.setup()
    logging_config = settings.LOGGING.copy()
    logging_config["loggers"] = {**logging_config["loggers"],
                                 "gunicorn.error": {"handlers": ["safe"], "level": "INFO", "propagate": False}}
    dictConfig(logging_config)
