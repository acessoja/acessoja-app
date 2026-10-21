from django.apps import AppConfig


class LocaisConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'locais'

    def ready(self):
        from . import catalog_signals  # noqa: F401
