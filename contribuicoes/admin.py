from django.contrib import admin
from django.db import transaction
from .models import ContributionPointEvent, PointActivity, ReportRewardAttribution, UserAchievement
from .services import set_report_reward_status


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


@admin.register(ReportRewardAttribution)
class ReportRewardAttributionAdmin(admin.ModelAdmin):
    list_display = ("report", "beneficiary", "local", "status", "updated_by", "updated_at")
    list_filter = ("status", "action")
    readonly_fields = [field.name for field in ReportRewardAttribution._meta.fields]
    actions = ("revoke_as_fraud", "annul_formally", "restore_formally", "restore_after_fraud_review")

    def has_view_permission(self, request, obj=None):
        return request.user.has_perm("evidencias.moderate_content")

    def has_change_permission(self, request, obj=None):
        return request.user.has_perm("evidencias.moderate_content")

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False

    @transaction.atomic
    def _apply_status(self, request, queryset, status, reason):
        changed = sum(
            set_report_reward_status(row.pk, request.user, status=status, reason=reason)
            for row in queryset
        )
        self.message_user(request, f"{changed} recompensa(s) revisada(s).")

    @admin.action(description="Revogar por fraude")
    def revoke_as_fraud(self, request, queryset):
        self._apply_status(request, queryset, "revoked", "fraud")

    @admin.action(description="Anular formalmente")
    def annul_formally(self, request, queryset):
        self._apply_status(request, queryset, "revoked", "formal_annulment")

    @admin.action(description="Restaurar formalmente")
    def restore_formally(self, request, queryset):
        self._apply_status(request, queryset, "granted", "formal_restoration")

    @admin.action(description="Restaurar após revisão de fraude")
    def restore_after_fraud_review(self, request, queryset):
        self._apply_status(request, queryset, "granted", "fraud_cleared")
