from django.apps import AppConfig


class AcessojaConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'acessoja'

    def ready(self):
        # Registra os ajustes de schema (drf-spectacular) na inicializacao.
        from . import schema_fixes  # noqa: F401
