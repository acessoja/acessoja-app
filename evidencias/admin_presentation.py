from django.db.models import Count, Q
from django.urls import reverse

from .models import ContentReport, REPORT_STATES
from .services import reports_related


def report_queue(queryset):
    return reports_related(queryset).select_related(
        "review_revision__review__local",
        "evidence__local",
        "photo_revision__photo__review__local",
    )


REPORT_SEARCH_FIELDS = (
    "protocol", "description", "review_revision__review__local__nome",
    "photo_revision__photo__review__local__nome", "evidence__local__nome",
)


def report_place(report):
    if report.review_revision and report.review_revision.review:
        return report.review_revision.review.local
    if report.photo_revision and report.photo_revision.photo:
        return report.photo_revision.photo.review.local
    if report.evidence:
        return report.evidence.local
    return None


def dashboard_context():
    counts = dict(
        ContentReport.objects.order_by().values("state").annotate(total=Count("pk"))
        .values_list("state", "total")
    )
    reports_url = reverse("admin:evidencias_contentreport_changelist")
    return {
        "state_cards": [
            {
                "label": label, "state": state, "total": counts.get(state, 0),
                "url": f"{reports_url}?state__exact={state}",
            }
            for state, label in REPORT_STATES
        ],
        "recent_reports": [
            {"report": row, "place": report_place(row)}
            for row in report_queue(ContentReport.objects.all()).order_by("-created_at", "pk")[:12]
        ],
    }


def report_search(queryset, term):
    if not term:
        return queryset
    condition = Q()
    for field in REPORT_SEARCH_FIELDS:
        condition |= Q(**{f"{field}__icontains": term})
    return queryset.filter(condition)
