from django.contrib import admin
from .models import ContributionPointEvent, PointActivity, UserAchievement


class ReadOnlyLedgerAdmin(admin.ModelAdmin):
    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


admin.site.register(ContributionPointEvent, ReadOnlyLedgerAdmin)
admin.site.register(PointActivity, ReadOnlyLedgerAdmin)
admin.site.register(UserAchievement, ReadOnlyLedgerAdmin)
