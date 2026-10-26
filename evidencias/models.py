"""Versioned assertions and private moderation; confirmations are not votes."""

import uuid

from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models
from django.utils import timezone

STATES = [
    (value, value)
    for value in ("presence_reported", "absence_reported", "unknown", "limited", "not_applicable")
]
OPEN_STATES = ("pending", "reviewing", "revision_requested")
REPORT_STATES = [
    (key, label)
    for key, label in (
        ("pending", "Pendente"),
        ("reviewing", "Em análise"),
        ("revision_requested", "Aguardando revisão"),
        ("closed", "Concluída"),
    )
]
REASONS = [
    (key, label)
    for key, label in (
        ("incorrect", "Informação incorreta"),
        ("outdated", "Informação desatualizada"),
        ("inappropriate", "Conteúdo inadequado"),
        ("other", "Outro"),
    )
]
ACTIONS = [
    (key, label)
    for key, label in (
        ("start", "Iniciar análise"),
        ("keep", "Manter conteúdo"),
        ("invalidate", "Invalidar conteúdo"),
        ("request_review", "Solicitar revisão"),
        ("unavailable", "Encerrar por alvo removido ou alterado"),
    )
]
GUIDANCE = {
    "resource_details": {
        "pt": "Revise o valor do recurso e informe a data da observação, se souber.",
        "en": "Review the feature value and provide the observation date if known.",
    },
    "comment_language": {
        "pt": "Revise o comentário para relatar sua experiência sem conteúdo inadequado.",
        "en": "Review your comment to describe your experience without inappropriate content.",
    },
    "overall_review": {
        "pt": "Confira a nota e o comentário conforme sua experiência no local.",
        "en": "Check your rating and comment against your experience at the place.",
    },
    "account_privacy": {
        "pt": "Revise os dados informados. Não é necessário compartilhar diagnóstico ou dados pessoais.",
        "en": "Review the information provided. Diagnoses and personal details are not required.",
    },
}


class ImmutableRecord(models.Model):
    class Meta:
        abstract = True

    def save(self, *args, **kwargs):
        if not self._state.adding:
            raise ValidationError("Histórico não pode ser editado pelo fluxo comum.")
        return super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        raise ValidationError("Use somente o procedimento documentado de retenção/privacidade.")


class ReviewRevision(ImmutableRecord):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    review = models.ForeignKey(
        "modal_avaliacao.ModalAvaliacao",
        null=True,
        on_delete=models.SET_NULL,
        related_name="content_revisions",
    )
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="+"
    )
    payload = models.JSONField(default=dict)
    recorded_at = models.DateTimeField(null=True)
    original_submission_at = models.DateTimeField(null=True)
    captured_at = models.DateTimeField(default=timezone.now)

    def __str__(self):
        return f"ReviewRevision {self.pk}"


class ResourceEvidence(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    key = models.CharField(max_length=220, unique=True)
    resource = models.CharField(max_length=64)
    kind = models.CharField(
        max_length=16, choices=[(key, key) for key in ("review", "observation", "registration", "osm")]
    )
    source = models.CharField(max_length=32, default="not_recorded")
    local = models.ForeignKey(
        "locais.Local", null=True, on_delete=models.SET_NULL, related_name="resource_evidence"
    )
    external_id = models.CharField(max_length=64, blank=True, db_index=True)
    review = models.ForeignKey(
        "modal_avaliacao.ModalAvaliacao", null=True, on_delete=models.SET_NULL, related_name="+"
    )
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="+"
    )
    current_revision = models.ForeignKey(
        "EvidenceRevision", null=True, on_delete=models.SET_NULL, related_name="+"
    )
    source_metadata = models.JSONField(default=dict)
    withdrawn = models.BooleanField(default=False)

    class Meta:
        indexes = [models.Index(fields=["local", "resource", "withdrawn"], name="evidence_local_resource")]

    def __str__(self):
        return f"ResourceEvidence {self.pk}"


class EvidenceRevision(ImmutableRecord):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    evidence = models.ForeignKey(ResourceEvidence, on_delete=models.CASCADE, related_name="revisions")
    number = models.PositiveIntegerField()
    fingerprint = models.CharField(max_length=64)
    state = models.CharField(max_length=32, choices=STATES)
    note = models.CharField(max_length=1000, blank=True)
    observed_at = models.DateTimeField(null=True)
    observed_on = models.DateField(null=True)
    received_at = models.DateTimeField(null=True)
    captured_at = models.DateTimeField(default=timezone.now)
    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="+"
    )
    source_metadata = models.JSONField(default=dict)
    is_valid = models.BooleanField(default=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["evidence", "number"], name="evidence_revision_number_unique")
        ]

    def __str__(self):
        return f"EvidenceRevision {self.pk}"


class EvidenceConfirmation(models.Model):
    revision = models.ForeignKey(EvidenceRevision, on_delete=models.CASCADE, related_name="confirmations")
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="+")
    confirmed_at = models.DateTimeField(default=timezone.now)
    observed_at = models.DateTimeField(null=True)
    observed_on = models.DateField(null=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["revision", "user"], name="one_confirmation_user_revision")
        ]

    def __str__(self):
        return f"EvidenceConfirmation {self.pk}"


class ContentReport(models.Model):
    protocol = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    reporter = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="+"
    )
    target_kind = models.CharField(max_length=12, choices=[("review", "Avaliação"), ("evidence", "Recurso")])
    target_key = models.CharField(max_length=220)
    target_revision = models.UUIDField()
    review_revision = models.ForeignKey(
        ReviewRevision, null=True, on_delete=models.SET_NULL, related_name="reports"
    )
    evidence = models.ForeignKey(
        ResourceEvidence, null=True, on_delete=models.SET_NULL, related_name="reports"
    )
    evidence_revision = models.ForeignKey(
        EvidenceRevision, null=True, on_delete=models.SET_NULL, related_name="reports"
    )
    reason = models.CharField(max_length=20, choices=REASONS)
    description = models.CharField(max_length=1000, blank=True)
    state = models.CharField(max_length=24, choices=REPORT_STATES, default="pending")
    outcome = models.CharField(max_length=24, blank=True)
    version = models.PositiveIntegerField(default=1)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(default=timezone.now)

    class Meta:
        permissions = [("moderate_content", "Analisar denúncias e decidir sobre conteúdo")]
        constraints = [
            models.UniqueConstraint(
                fields=["reporter", "target_key", "target_revision"], name="one_report_user_target_revision"
            )
        ]
        indexes = [models.Index(fields=["state", "created_at"], name="report_queue_state_date")]

    def __str__(self):
        return f"ContentReport {self.protocol}"


class ModerationDecision(ImmutableRecord):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    report = models.ForeignKey(ContentReport, on_delete=models.PROTECT, related_name="decisions")
    operation_id = models.UUIDField()
    request_fingerprint = models.CharField(max_length=64)
    moderator = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="+"
    )
    action = models.CharField(max_length=24, choices=ACTIONS)
    reason = models.CharField(max_length=1000)
    author_message = models.CharField(max_length=400, blank=True)
    target_revision = models.UUIDField()
    previous_state = models.CharField(max_length=24)
    next_state = models.CharField(max_length=24)
    effect_applied = models.BooleanField(default=False)
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["report", "operation_id"], name="one_decision_case_operation")
        ]

    def __str__(self):
        return f"ModerationDecision {self.pk}"


class ExternalEvidenceGuard(models.Model):
    """Stable lock for equivalent OSM assertions, including first appearance in a channel."""

    key = models.CharField(max_length=64, primary_key=True)

    def __str__(self):
        return f"ExternalEvidenceGuard {self.pk}"
