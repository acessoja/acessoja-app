from django.db import models, router, transaction
from django.conf import settings
from django.core.exceptions import ValidationError

# Respostas aceitas nas quatro perguntas do modal de avaliacao.
# Extraido para uma constante para que as quatro perguntas compartilhem
# um unico enum no schema OpenAPI (ver ENUM_NAME_OVERRIDES em settings.py).
RESPOSTAS = [
    ("Sim", "Sim"),
    ("Não", "Não"),
    ("Não sei", "Não sei"),
]


class ModalAvaliacao(models.Model):
    local = models.ForeignKey(
        "locais.Local",  # Substitua 'locais' pelo nome do app onde Local está definido
        on_delete=models.CASCADE,
        related_name="avaliacoes",
    )
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    pergunta_1 = models.CharField(max_length=10, choices=RESPOSTAS)
    pergunta_2 = models.CharField(max_length=10, choices=RESPOSTAS)
    pergunta_3 = models.CharField(max_length=10, choices=RESPOSTAS)
    pergunta_4 = models.CharField(max_length=10, choices=RESPOSTAS)
    estrelas = models.PositiveIntegerField(default=0)  # De 1 a 5 estrelas
    comentario = models.TextField(blank=True)
    data_resposta = models.DateTimeField(auto_now_add=True)

    verified_author = models.BooleanField(default=False)
    is_current = models.BooleanField(default=True)
    is_valid = models.BooleanField(default=True)
    comment_verified = models.BooleanField(default=False)
    survey_completed = models.BooleanField(default=False)

    def save(self, *args, **kwargs):
        from usuarios.models import Usuario

        using = kwargs.get("using") or router.db_for_write(type(self), instance=self)
        # Include both the source write and post_save's ledger in one transaction.
        # Every ordinary ORM write takes the author lock before the review lock.
        with transaction.atomic(using=using):
            Usuario.objects.using(using).select_for_update().get(pk=self.user_id)
            previous = type(self).objects.using(using).filter(pk=self.pk).first() if self.pk else None
            if previous and (previous.user_id != self.user_id or previous.local_id != self.local_id):
                raise ValidationError("O autor e o local de uma avaliação não podem mudar.")
            update_fields = kwargs.get("update_fields")
            writes_comment = update_fields is None or "comentario" in update_fields
            changed_comment = previous and writes_comment and previous.comentario != self.comentario
            self._contribution_reason = "comment_changed" if changed_comment else None
            if changed_comment and previous.comment_verified:
                self.comment_verified = False
                if update_fields is not None:
                    kwargs["update_fields"] = set(update_fields) | {"comment_verified"}
            return super().save(*args, **kwargs)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["user", "local"], condition=models.Q(is_current=True), name="one_current_review_per_user_place"
            )
        ]

    def __str__(self):
        return f"Avaliação de {self.local.nome} por {self.user.nome}"
