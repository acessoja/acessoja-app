from django.contrib import admin
from .models import ModalAvaliacao
from acessoja.private_admin import MinimalAdminLogMixin


@admin.register(ModalAvaliacao)
class ReviewAdmin(MinimalAdminLogMixin, admin.ModelAdmin):
    list_display = ["id", "local", "user", "verified_author", "is_current", "is_valid", "comment_verified"]
    list_filter = ["is_valid", "comment_verified", "verified_author", "is_current"]
    search_fields = ["local__nome", "user__nome", "comentario"]
    readonly_fields = [field.name for field in ModalAvaliacao._meta.fields if field.name != 'comment_verified']

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return request.user.is_active and request.user.is_superuser

    def has_delete_permission(self, request, obj=None):
        return False
