from django.contrib import admin
from .models import ModalAvaliacao


@admin.register(ModalAvaliacao)
class ReviewAdmin(admin.ModelAdmin):
    list_display = ["id", "local", "user", "verified_author", "is_current", "is_valid", "comment_verified"]
    list_filter = ["is_valid", "comment_verified", "verified_author", "is_current"]
    search_fields = ["local__nome", "user__nome", "comentario"]
    readonly_fields = ["user", "local", "verified_author", "is_current", "data_resposta"]

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return request.user.is_active and request.user.is_superuser

    def has_delete_permission(self, request, obj=None):
        return self.has_change_permission(request, obj)
