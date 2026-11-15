from django.contrib.admin import AdminSite
from django.contrib.admin.apps import AdminConfig


class AcessoJaAdminConfig(AdminConfig):
    default_site = "acessoja.admin_site.AcessoJaAdminSite"


class AcessoJaAdminSite(AdminSite):
    site_header = "AcessoJá"
    site_title = "AcessoJá"
    index_title = "Administração do AcessoJá"
    index_template = "admin/moderation/index.html"
    login_template = "admin/moderation/login.html"

    def index(self, request, extra_context=None):
        from evidencias.admin_presentation import dashboard_context
        from evidencias.moderation import allowed

        can_moderate = allowed(request.user)
        return super().index(request, {
            "can_moderate": can_moderate,
            **(dashboard_context() if can_moderate else {}),
            **(extra_context or {}),
        })
