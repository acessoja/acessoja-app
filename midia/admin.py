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
    action = forms.ChoiceField(
        label="Decisão sobre a foto", choices=[("approve", "Aprovar imagem"), ("reject", "Rejeitar imagem")],
        widget=forms.RadioSelect,
    )
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
    change_list_template = "admin/moderation/queue.html"
    list_display = ["id", "place_name", "status", "created_at", "analysis_link"]
    list_display_links = None
    list_select_related = ["current_revision", "review__local"]
    search_fields = ["review__local__nome", "id"]
    list_filter = ["current_revision__state", "created_at"]
    readonly_fields = [field.name for field in ReviewPhoto._meta.fields]

    def changelist_view(self, request, extra_context=None):
        return super().changelist_view(request, {**(extra_context or {}), "moderation_section": "photos"})

    @admin.display(description="Estabelecimento")
    def place_name(self, obj):
        return obj.review.local.nome

    @admin.display(description="Estado", ordering="current_revision__state")
    def status(self, obj):
        row = obj.current_revision
        if obj.deleted_at:
            return format_html('<span class="mod-badge">{}</span>', "Retirada")
        key, label = (row.state, row.get_state_display()) if row else ("", "Sem versão disponível")
        return format_html('<span class="mod-badge {}">{}</span>', key, label)

    @admin.display(description="Moderação")
    def analysis_link(self, obj):
        return format_html(
            '<a class="mod-button" href="{}">{}</a>',
            reverse("admin:image-photo-decision", args=[obj.pk]),
            "Analisar imagem" if not obj.deleted_at and obj.current_revision_id else "Ver detalhes",
        )

    def change_view(self, request, object_id, form_url="", extra_context=None):
        if request.method in {"GET", "HEAD"}:
            if not allowed(request.user):
                raise PermissionDenied()
            obj = self.get_object(request, object_id)
            if obj is not None:
                return redirect(reverse("admin:image-photo-decision", args=[obj.pk]))
        return super().change_view(request, object_id, form_url, extra_context)

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
        photo = get_object_or_404(ReviewPhoto.objects.select_related("current_revision__asset", "review__local"), pk=photo_id)
        revision = photo.current_revision
        form = PhotoDecisionForm(
            request.POST or None,
            initial={
                "revision_id": revision.pk,
                "expected_version": revision.moderation_version,
                "operation_id": uuid.uuid4(),
            },
        ) if revision and not photo.deleted_at else None
        if request.method == "POST" and form is not None and form.is_valid():
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
                "moderation_section": "photos",
                "revision": revision,
                "form": form,
                "image_url": (
                    reverse("protected-image", args=[revision.asset_id, "image"])
                    if revision and not photo.deleted_at else None
                ),
                "history": ImageDecision.objects.filter(revision__photo=photo).order_by("created_at"),
                "opts": self.model._meta,
            },
        )


@admin.register(ImageDecision)
class ImageDecisionAdmin(RestrictedImageAdmin):
    change_list_template = "admin/moderation/queue.html"

    def changelist_view(self, request, extra_context=None):
        return super().changelist_view(request, {**(extra_context or {}), "moderation_section": "image_history"})
    list_display = ["photo_link", "action", "created_at"]
    list_display_links = None
    list_select_related = ["revision"]

    @admin.display(description="Fotografia")
    def photo_link(self, obj):
        photo_id = obj.revision.photo_id
        if photo_id is None:
            return "Fotografia indisponível"
        return format_html(
            '<a href="{}">{}</a>', reverse("admin:image-photo-decision", args=[photo_id]), photo_id,
        )
    readonly_fields = [field.name for field in ImageDecision._meta.fields]
