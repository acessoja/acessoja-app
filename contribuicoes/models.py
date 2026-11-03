import uuid

from django.conf import settings
from django.db import models


class ReportRewardAttribution(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    report = models.ForeignKey("evidencias.ContentReport", on_delete=models.PROTECT, related_name="reward_attributions")
    decision = models.ForeignKey(
        "evidencias.ModerationDecision",
        null=True,
        blank=True,
        on_delete=models.PROTECT,
        related_name="reward_attributions",
    )
    review = models.ForeignKey(
        "modal_avaliacao.ModalAvaliacao",
        null=True,
        blank=True,
        on_delete=models.PROTECT,
        related_name="report_rewards",
    )
    local = models.ForeignKey("locais.Local", on_delete=models.PROTECT, related_name="report_rewards")
    beneficiary = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="report_rewards")
    action = models.CharField(max_length=24, default="report_upheld")
    status = models.CharField(
        max_length=16,
        default="pending",
        choices=[("pending", "Pendente"), ("granted", "Concedida"), ("revoked", "Revogada")],
    )
    event = models.ForeignKey(
        "ContributionPointEvent",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="report_reward_attributions",
    )
    idempotency_key = models.CharField(max_length=180, unique=True)
    reason = models.CharField(max_length=200, blank=True)
    updated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="moderated_report_rewards",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    granted_at = models.DateTimeField(null=True, blank=True)
    revoked_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["review"], name="one_report_reward_per_review"),
            models.UniqueConstraint(
                fields=["beneficiary", "local", "action"],
                name="one_report_reward_per_user_local_action",
            )
        ]

    def __str__(self):
        return f"ReportRewardAttribution {self.pk}"


class ContributionPointEvent(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    local = models.ForeignKey("locais.Local", on_delete=models.CASCADE)
    evaluation = models.ForeignKey("modal_avaliacao.ModalAvaliacao", null=True, on_delete=models.SET_NULL)
    action = models.CharField(max_length=40)
    points = models.PositiveIntegerField()
    active = models.BooleanField(default=True)
    revision = models.PositiveIntegerField(default=1)
    idempotency_key = models.CharField(max_length=120, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user_id}:{self.local_id}:{self.action} ({self.points})"

    class Meta:
        constraints = [models.UniqueConstraint(fields=["user", "local", "action"], name="one_award_per_place_action")]


class PointActivity(models.Model):
    event = models.ForeignKey(ContributionPointEvent, on_delete=models.CASCADE)
    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="point_activities",
    )
    delta = models.IntegerField()
    idempotency_key = models.CharField(max_length=150, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    # Defaults identify old entries honestly; their original cause is unknown.
    operation = models.CharField(max_length=20, default="recorded")
    reason = models.CharField(max_length=40, default="legacy")
    source_evaluation_id = models.PositiveBigIntegerField(null=True, blank=True)

    def __str__(self):
        return f"{self.event_id}: {self.delta:+d}"

    class Meta:
        ordering = ["-created_at", "-pk"]


class UserAchievement(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    code = models.CharField(max_length=40)
    active = models.BooleanField(default=True)
    unlocked_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user_id}: {self.code}"

    class Meta:
        constraints = [models.UniqueConstraint(fields=["user", "code"], name="one_user_achievement")]
