from django.db import models
from django.conf import settings

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

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["user", "local"], condition=models.Q(is_current=True), name="one_current_review_per_user_place"
            )
        ]

    def __str__(self):
        return f"Avaliação de {self.local.nome} por {self.user.nome}"
