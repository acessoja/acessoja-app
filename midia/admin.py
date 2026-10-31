import uuid
from django import forms
from django.contrib import admin, messages
from django.core.exceptions import PermissionDenied
from django.shortcuts import get_object_or_404, redirect
from django.template.response import TemplateResponse
from django.urls import path, reverse
from django.utils.html import format_html
from rest_framework.exceptions import APIException
from evidencias.moderation import allowed
from .models import ImageDecision, ReviewPhoto
from .moderation import decide_photo


class PhotoDecisionForm(forms.Form):
    action = forms.ChoiceField(choices=[("approve", "Aprovar imagem"), ("reject", "Rejeitar imagem")])
    reason = forms.CharField(min_length=10, max_length=1000, widget=forms.Textarea, label="Justificativa")
    author_reason = forms.ChoiceField(
        choices=ImageDecision._meta.get_field("author_reason").choices,
        initial="context",
        required=False,
        label="Orientação ao autor (sem notas internas)",
    )

    def clean_author_reason(self):
        return self.cleaned_data.get("author_reason") or "context"

    revision_id = forms.UUIDField(widget=forms.HiddenInput)
    expected_version = forms.IntegerField(widget=forms.HiddenInput)
    operation_id = forms.UUIDField(widget=forms.HiddenInput)


class RestrictedImageAdmin(admin.ModelAdmin):
    actions = None

    def has_module_permission(self, request):
        return allowed(request.user)

    def has_view_permission(self, request, obj=None):
        return allowed(request.user)

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False

    def has_add_permission(self, request):
        return False

    def get_queryset(self, request):
        return super().get_queryset(request) if allowed(request.user) else self.model.objects.none()


@admin.register(ReviewPhoto)
class PhotoAdmin(RestrictedImageAdmin):
    list_display = ["id", "review", "status", "created_at", "analysis_link"]
    list_filter = ["current_revision__state", "created_at"]
    readonly_fields = [field.name for field in ReviewPhoto._meta.fields]

    @admin.display(description="Estado")
    def status(self, obj):
        return obj.current_revision.get_state_display() if obj.current_revision else "Processando"

    @admin.display(description="Moderação")
    def analysis_link(self, obj):
        return format_html('<a href="{}">Analisar imagem</a>', reverse("admin:image-photo-decision", args=[obj.pk]))

    def get_urls(self):
        return [
            path(
                "<uuid:photo_id>/decidir/",
                self.admin_site.admin_view(self.decision_view),
                name="image-photo-decision",
            ),
            *super().get_urls(),
        ]

    def decision_view(self, request, photo_id):
        if not allowed(request.user):
            raise PermissionDenied()
        photo = get_object_or_404(ReviewPhoto.objects.select_related("current_revision__asset"), pk=photo_id)
        revision = photo.current_revision
        form = PhotoDecisionForm(
            request.POST or None,
            initial={
                "revision_id": revision.pk,
                "expected_version": revision.moderation_version,
                "operation_id": uuid.uuid4(),
            },
        )
        if request.method == "POST" and form.is_valid():
            try:
                decide_photo(request.user.pk, photo_id, **form.cleaned_data)
            except APIException as error:
                form.add_error(None, str(error.detail))
            else:
                self.message_user(
                    request, "Decisão registrada; elegibilidade e pontos reconciliados.", messages.SUCCESS
                )
                return redirect(reverse("admin:image-photo-decision", args=[photo_id]))
        return TemplateResponse(
            request,
            "admin/midia/photo_decision.html",
            {
                **self.admin_site.each_context(request),
                "title": "Analisar fotografia",
                "photo": photo,
                "revision": revision,
                "form": form,
                "image_url": f"/api/midia/arquivos/{revision.asset_id}/image/",
                "history": ImageDecision.objects.filter(revision__photo=photo).order_by("created_at"),
                "opts": self.model._meta,
            },
        )


@admin.register(ImageDecision)
class ImageDecisionAdmin(RestrictedImageAdmin):
    list_display = ["revision", "action", "created_at"]
    readonly_fields = [field.name for field in ImageDecision._meta.fields]
