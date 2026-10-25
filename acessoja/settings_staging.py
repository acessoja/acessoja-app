"""Explicit deployment entry point; never reads a developer's .env file."""
import os
from django.core.exceptions import ImproperlyConfigured

os.environ.setdefault("APP_ENV", "staging")
os.umask(0o077)
from .settings import *  # noqa: F401,F403,E402

if APP_ENV != "staging":  # noqa: F405
    raise ImproperlyConfigured("APP_ENV must be staging for settings_staging.")
