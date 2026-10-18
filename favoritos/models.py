from django.conf import settings
from django.db import models


class Favorito(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="favoritos")
    local = models.ForeignKey("locais.Local", on_delete=models.CASCADE, related_name="favoritos")
    criado_em = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-criado_em", "-id"]
        constraints = [models.UniqueConstraint(fields=["user", "local"], name="favorito_owner_local_unique")]
        indexes = [models.Index(fields=["user", "-criado_em", "-id"], name="favorito_owner_date")]

    def __str__(self):
        return f"Favorito {self.pk}"
