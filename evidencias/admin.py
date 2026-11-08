import json
import uuid

from django import forms
from django.contrib import admin, messages
from django.core.exceptions import PermissionDenied
from django.shortcuts import get_object_or_404, redirect
from django.core.paginator import Paginator
from django.template.response import TemplateResponse
from django.urls import path, reverse
from django.utils.html import format_html
from rest_framework.exceptions import APIException

from .models import ACTIONS, ContentReport, GUIDANCE, ModerationDecision
from .moderation import allowed, decide
from .services import reports_related, target_status


FIELD_LABELS = {
    "description": "Descrição", "estrelas": "Nota", "comentario": "Comentário",
    "resource": "Recurso", "state": "Estado", "note": "Observação",
    "answers": "Respostas", "answer_dates": "Datas das respostas",
    "answer_details": "Detalhes das respostas", "questionnaire_version": "Versão do questionário",
    "pergunta_1": "Pergunta 1", "pergunta_2": "Pergunta 2",
    "pergunta_3": "Pergunta 3", "pergunta_4": "Pergunta 4",
}


def display_fields(payload):
    """Present trusted snapshot values as escaped template text, never as HTML."""
    if not isinstance(payload, dict):
        return []
    rows = []

    def add(label, value, depth=0):
        if isinstance(value, dict) and depth < 4:
            for key, nested in value.items():
                add(f"{label} · {str(key).replace('_', ' ')}", nested, depth + 1)
        elif isinstance(value, list) and depth < 4:
            for index, nested in enumerate(value, 1):
                add(f"{label} {index}", nested, depth + 1)
        else:
            rows.append((label, "Não informado" if value is None or value == "" else str(value)))

    for key, value in payload.items():
        add(FIELD_LABELS.get(key, key.replace("_", " ").capitalize()), value)
    return rows


class DecisionForm(forms.Form):
    action = forms.ChoiceField(label="Decisão", choices=ACTIONS, widget=forms.RadioSelect)
    reason = forms.CharField(
        label="Justificativa interna", min_length=10, max_length=1000, widget=forms.Textarea
    )
    author_message = forms.ChoiceField(
        label="Orientação ao autor (somente ao solicitar revisão)",
        required=False,
        choices=[("", "Sem orientação"), *[(key, value["pt"]) for key, value in GUIDANCE.items()]],
    )
    expected_version = forms.IntegerField(widget=forms.HiddenInput)
    expected_target_revision = forms.UUIDField(widget=forms.HiddenInput)
    operation_id = forms.UUIDField(widget=forms.HiddenInput)


@admin.register(ContentReport)
class ReportAdmin(admin.ModelAdmin):
    change_list_template = "admin/moderation/change_list.html"
    list_display = ["protocol", "target_kind", "reason", "state", "created_at", "review_link"]
    list_filter = ["state", "reason", "target_kind", ("created_at", admin.DateFieldListFilter)]
    search_fields = ["protocol"]
    readonly_fields = [field.name for field in ContentReport._meta.fields if field.name != "reporter"]
    exclude = ["reporter"]
    actions = None
    ordering = ["created_at", "protocol"]

    def has_module_permission(self, request):
        return allowed(request.user)

    def has_view_permission(self, request, obj=None):
        return allowed(request.user)

    def has_change_permission(self, request, obj=None):
        return False

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False

    def get_queryset(self, request):
        return super().get_queryset(request) if allowed(request.user) else ContentReport.objects.none()

    @admin.display(description="Análise")
    def review_link(self, obj):
        return format_html(
            '<a href="{}">{}</a>', reverse("admin:evidence-report-decision", args=[obj.pk]),
            "Ver histórico" if obj.state == "closed" else "Analisar",
        )

    def changelist_view(self, request, extra_context=None):
        return self.dashboard_view(request, queue_only=True)

    def change_view(self, request, object_id, form_url="", extra_context=None):
        if not allowed(request.user):
            raise PermissionDenied()
        return redirect(reverse("admin:evidence-report-decision", args=[object_id]))

    def get_urls(self):
        return [
            path("central/", self.admin_site.admin_view(self.dashboard_view), name="moderation-dashboard"),
            path(
                "<uuid:protocol>/decidir/",
                self.admin_site.admin_view(self.decision_view),
                name="evidence-report-decision",
            ),
            *super().get_urls(),
        ]

    def dashboard_view(self, request, queue_only=False):
        if not allowed(request.user):
            raise PermissionDenied()
        queryset = reports_related(self.get_queryset(request)).select_related(
            "review_revision__review__local", "photo_revision__photo__review__local", "evidence__local"
        )
        counts = {
            state: queryset.filter(state=state).count()
            for state in ("pending", "reviewing", "revision_requested", "closed")
        }
        state = request.GET.get("state", "")
        kind = request.GET.get("kind", "")
        search = request.GET.get("q", "").strip()
        if state in counts:
            queryset = queryset.filter(state=state)
        if kind in dict(ContentReport._meta.get_field("target_kind").choices):
            queryset = queryset.filter(target_kind=kind)
        if search:
            try:
                queryset = queryset.filter(protocol=uuid.UUID(search))
            except ValueError:
                queryset = queryset.none()
        page = Paginator(queryset.order_by("-created_at"), 20).get_page(request.GET.get("page"))
        return TemplateResponse(request, "admin/moderation/dashboard.html", {
            **self.admin_site.each_context(request), "title": "Denúncias" if queue_only else "Central de Moderação",
            "nav_active": "reports" if queue_only else "overview", "queue_only": queue_only,
            "counts": counts, "page": page, "state_filter": state, "kind_filter": kind,
            "search": search, "report_states": ContentReport._meta.get_field("state").choices,
            "target_kinds": ContentReport._meta.get_field("target_kind").choices,
            "opts": self.model._meta,
        })

    def decision_view(self, request, protocol):
        if not allowed(request.user):
            raise PermissionDenied()
        report = get_object_or_404(reports_related(ContentReport.objects.all()), pk=protocol)
        form = DecisionForm(
            request.POST or None,
            initial={
                "expected_version": report.version,
                "expected_target_revision": report.target_revision,
                "operation_id": uuid.uuid4(),
            },
        )
        if request.method == "POST" and form.is_valid():
            try:
                decide(request.user.pk, report.pk, **form.cleaned_data)
            except APIException as error:
                form.add_error(None, str(error.detail))
            else:
                self.message_user(
                    request,
                    "Decisão registrada. Indicadores e pontos foram tratados na mesma transação.",
                    messages.SUCCESS,
                )
                return redirect(reverse("admin:evidence-report-decision", args=[report.pk]))
        photo_snapshot = (
            {"description": report.photo_revision.description, "revision": str(report.photo_revision_id)}
            if report.photo_revision
            else None
        )
        snapshot = photo_snapshot or (
            report.review_revision.payload
            if report.review_revision
            else {
                "resource": report.evidence.resource if report.evidence else None,
                "state": report.evidence_revision.state if report.evidence_revision else None,
                "note": report.evidence_revision.note if report.evidence_revision else None,
            }
        )
        status = target_status(report)
        if status == "current":
            actions = [
                (key, label)
                for key, label in ACTIONS
                if key != "unavailable" and not (key == "start" and report.state != "pending")
            ]
        else:
            actions = [(key, label) for key, label in ACTIONS if key == "unavailable"]
        form.fields["action"].choices = actions
        current_content = None
        if status in {"current", "changed"}:
            if report.target_kind == "review":
                from .capture import review_payload

                current_content = review_payload(report.review_revision.review)
            elif report.photo_revision:
                current_content = {"description": report.photo_revision.photo.current_revision.description}
            elif report.evidence and report.evidence.current_revision:
                row = report.evidence.current_revision
                current_content = {"resource": report.evidence.resource, "state": row.state, "note": row.note}
        context = {
            **self.admin_site.each_context(request),
            "title": "Analisar denúncia",
            "nav_active": "reports",
            "report": report,
            "target_status": status,
            "current_content": (
                json.dumps(current_content, ensure_ascii=False, indent=2) if current_content else None
            ),
            "snapshot": json.dumps(snapshot, ensure_ascii=False, indent=2),
            "snapshot_fields": display_fields(snapshot),
            "current_fields": display_fields(current_content),
            "form": form,
            "history": report.decisions.select_related("moderator").order_by("created_at"),
            "opts": self.model._meta,
        }
        return TemplateResponse(request, "admin/evidencias/decision.html", context)


@admin.register(ModerationDecision)
class DecisionAdmin(admin.ModelAdmin):
    change_list_template = "admin/moderation/change_list.html"

    def changelist_view(self, request, extra_context=None):
        return super().changelist_view(
            request,
            extra_context={**(extra_context or {}), "title": "Histórico de denúncias", "nav_active": "history"},
        )

    def change_view(self, request, object_id, form_url="", extra_context=None):
        if not allowed(request.user):
            raise PermissionDenied()
        item = get_object_or_404(self.get_queryset(request), pk=object_id)
        return redirect(reverse("admin:evidence-report-decision", args=[item.report_id]))
    list_display = ["report", "action", "previous_state", "next_state", "created_at"]
    readonly_fields = [field.name for field in ModerationDecision._meta.fields]
    actions = None

    def has_module_permission(self, request):
        return allowed(request.user)

    def has_view_permission(self, request, obj=None):
        return allowed(request.user)

    def has_change_permission(self, request, obj=None):
        return False

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False

    def get_queryset(self, request):
        return super().get_queryset(request) if allowed(request.user) else ModerationDecision.objects.none()
