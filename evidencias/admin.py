import json
import uuid

from django import forms
from django.contrib import admin, messages
from django.core.exceptions import PermissionDenied
from django.shortcuts import get_object_or_404, redirect
from django.template.response import TemplateResponse
from django.urls import path, reverse
from django.utils.html import format_html
from rest_framework.exceptions import APIException

from .models import ACTIONS, ContentReport, GUIDANCE, ModerationDecision
from .moderation import allowed, decide
from .services import reports_related, target_status


class DecisionForm(forms.Form):
    action = forms.ChoiceField(label="Decisão", choices=ACTIONS)
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
            '<a href="{}">Analisar</a>', reverse("admin:evidence-report-decision", args=[obj.pk])
        )

    def get_urls(self):
        return [
            path(
                "<uuid:protocol>/decidir/",
                self.admin_site.admin_view(self.decision_view),
                name="evidence-report-decision",
            ),
            *super().get_urls(),
        ]

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
        snapshot = (
            report.review_revision.payload
            if report.review_revision
            else {
                "resource": report.evidence.resource if report.evidence else None,
                "state": report.evidence_revision.state if report.evidence_revision else None,
                "note": report.evidence_revision.note if report.evidence_revision else None,
            }
        )
        status = target_status(report)
        current_content = None
        if status in {"current", "changed"}:
            if report.target_kind == "review":
                from .capture import review_payload

                current_content = review_payload(report.review_revision.review)
            elif report.evidence and report.evidence.current_revision:
                row = report.evidence.current_revision
                current_content = {"resource": report.evidence.resource, "state": row.state, "note": row.note}
        context = {
            **self.admin_site.each_context(request),
            "title": "Analisar denúncia",
            "report": report,
            "target_status": status,
            "current_content": (
                json.dumps(current_content, ensure_ascii=False, indent=2) if current_content else None
            ),
            "snapshot": json.dumps(snapshot, ensure_ascii=False, indent=2),
            "form": form,
            "history": report.decisions.select_related("moderator").order_by("created_at"),
            "opts": self.model._meta,
        }
        return TemplateResponse(request, "admin/evidencias/decision.html", context)


@admin.register(ModerationDecision)
class DecisionAdmin(admin.ModelAdmin):
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
