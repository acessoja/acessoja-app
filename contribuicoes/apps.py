from django.apps import AppConfig


class ContribuicoesConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "contribuicoes"

    def ready(self):
        from . import signals  # noqa: F401
