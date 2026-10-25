"""Administrative actions keep metadata, never copied review text or profile data."""
from django.contrib.admin.models import ADDITION, CHANGE, DELETION, LogEntry
from django.contrib.contenttypes.models import ContentType


class MinimalAdminLogMixin:
    def _minimal_log(self, request, obj, action):
        return LogEntry.objects.create(
            user_id=request.user.pk, content_type=ContentType.objects.get_for_model(obj),
            object_id=str(obj.pk), object_repr="Registro administrado", action_flag=action, change_message="[]",
        )

    def log_addition(self, request, obj, message):
        return self._minimal_log(request, obj, ADDITION)

    def log_change(self, request, obj, message):
        return self._minimal_log(request, obj, CHANGE)

    def log_deletion(self, request, obj, object_repr):
        return self._minimal_log(request, obj, DELETION)

    def log_deletions(self, request, queryset):
        return [self._minimal_log(request, obj, DELETION) for obj in queryset]
