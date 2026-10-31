"""Private processed derivatives, recoverable operations and revision-bound photographs."""

import uuid
from django.conf import settings
from django.db import models, transaction
from django.utils import timezone
from evidencias.models import ImmutableRecord


class ImageAsset(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="+")
    purpose = models.CharField(max_length=12, choices=[("avatar", "Avatar"), ("photo", "Avaliação")])
    state = models.CharField(
        max_length=12, default="preparing", choices=[(x, x) for x in ["preparing", "ready", "retired"]]
    )
    mime_type = models.CharField(max_length=32, default="image/jpeg", editable=False)
    image_key = models.CharField(max_length=120)
    thumb_key = models.CharField(max_length=120)
    width = models.PositiveIntegerField(default=0)
    height = models.PositiveIntegerField(default=0)
    size = models.PositiveIntegerField(default=0)
    sha256 = models.CharField(max_length=64, blank=True)
    created_at = models.DateTimeField(default=timezone.now)

    def __str__(self):
        return f"ImageAsset {self.pk}"


class ReviewPhoto(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    review = models.ForeignKey("modal_avaliacao.ModalAvaliacao", on_delete=models.CASCADE, related_name="photos")
    owner = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="+")
    current_revision = models.ForeignKey("PhotoRevision", null=True, on_delete=models.SET_NULL, related_name="+")
    deleted_at = models.DateTimeField(null=True)
    created_at = models.DateTimeField(default=timezone.now)

    def save(self, *args, **kwargs):
        from usuarios.models import Usuario
        from modal_avaliacao.models import ModalAvaliacao

        with transaction.atomic():
            Usuario.objects.select_for_update().filter(pk=self.owner_id).first()
            ModalAvaliacao.objects.select_for_update().filter(pk=self.review_id).first()
            return super().save(*args, **kwargs)

    def __str__(self):
        return f"ReviewPhoto {self.pk}"


class PhotoRevision(ImmutableRecord):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    photo = models.ForeignKey(ReviewPhoto, null=True, on_delete=models.SET_NULL, related_name="revisions")
    owner = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="+")
    asset = models.ForeignKey(ImageAsset, on_delete=models.PROTECT, related_name="photo_revisions")
    description = models.CharField(max_length=500)
    submitted_at = models.DateTimeField(default=timezone.now)
    state = models.CharField(
        max_length=12,
        default="pending",
        choices=[("pending", "Pendente"), ("approved", "Aprovada"), ("rejected", "Rejeitada")],
    )
    moderation_version = models.PositiveIntegerField(default=1)

    def __str__(self):
        return f"PhotoRevision {self.pk}"


class ImageOperation(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="+")
    operation_id = models.UUIDField()
    kind = models.CharField(max_length=20)
    signature = models.CharField(max_length=64)
    state = models.CharField(max_length=12, default="processing")
    lease = models.UUIDField(default=uuid.uuid4)
    expires_at = models.DateTimeField()
    asset = models.ForeignKey(ImageAsset, null=True, on_delete=models.SET_NULL, related_name="+")
    review = models.ForeignKey("modal_avaliacao.ModalAvaliacao", null=True, on_delete=models.SET_NULL, related_name="+")
    photo = models.ForeignKey(ReviewPhoto, null=True, on_delete=models.SET_NULL, related_name="+")
    result_revision = models.UUIDField(null=True)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(default=timezone.now)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["owner", "operation_id"], name="image_operation_owner_unique")]
        indexes = [models.Index(fields=["state", "expires_at"], name="image_operation_recovery")]

    def __str__(self):
        return f"ImageOperation {self.pk}"


class ImageCleanup(models.Model):
    asset = models.OneToOneField(ImageAsset, on_delete=models.CASCADE, primary_key=True, related_name="cleanup")
    state = models.CharField(max_length=12, default="pending")
    attempts = models.PositiveIntegerField(default=0)
    updated_at = models.DateTimeField(default=timezone.now)

    def __str__(self):
        return f"ImageCleanup {self.pk}"


class ImageDecision(ImmutableRecord):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    revision = models.ForeignKey(PhotoRevision, on_delete=models.PROTECT, related_name="decisions")
    report = models.ForeignKey("evidencias.ContentReport", null=True, on_delete=models.SET_NULL, related_name="+")
    moderator = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="+")
    operation_id = models.UUIDField()
    signature = models.CharField(max_length=64)
    action = models.CharField(max_length=12, choices=[("approve", "Aprovar"), ("reject", "Rejeitar")])
    reason = models.CharField(max_length=1000)
    author_reason = models.CharField(
        max_length=20,
        default="context",
        choices=[
            ("context", "Revise a descrição e a relação da imagem com o recurso."),
            ("quality", "Escolha uma imagem legível que mostre o recurso."),
            ("privacy", "Remova pessoas, documentos ou dados pessoais da imagem e descrição."),
            ("irrelevant", "Escolha uma imagem relacionada à acessibilidade deste local."),
        ],
    )
    previous_state = models.CharField(max_length=12)
    next_state = models.CharField(max_length=12)
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["revision", "operation_id"], name="image_decision_operation_unique")
        ]

    def __str__(self):
        return f"ImageDecision {self.pk}"
