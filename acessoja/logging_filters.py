"""Do not put transient proximity origins into development HTTP access logs."""

import logging
import re

from django.views.debug import SafeExceptionReporterFilter


class RedactCoordinates(logging.Filter):
    def filter(self, record):
        message = record.getMessage()
        if re.search(
            r"(?:personalization|accessibility_preferences|snapshot_revision|[\"']resources[\"']|Authorization\s*[:=])",
            message,
            re.I,
        ):
            record.msg, record.args = "[redacted private context]", ()
            return True
        record.msg = re.sub(
            r'((?:origin_lat|origin_lon|latitude|longitude)=)[^&\s"\\]+', r"\1[redacted]", message, flags=re.IGNORECASE
        )
        record.args = ()
        return True


class PrivateDiscoveryReporterFilter(SafeExceptionReporterFilter):
    """Do not render JSON snapshots in technical error frame locals, even in DEBUG."""

    def get_traceback_frame_variables(self, request, tb_frame):
        values = super().get_traceback_frame_variables(request, tb_frame)
        if request and request.path.startswith(
            ("/api/locais/descoberta/", "/api/usuarios/me/accessibility-preferences/")
        ):
            return [(key, self.cleansed_substitute) for key, _ in values]
        return values
