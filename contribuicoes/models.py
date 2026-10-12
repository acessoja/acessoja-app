from django.conf import settings
from django.db import models


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
    delta = models.IntegerField()
    idempotency_key = models.CharField(max_length=150, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)

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
