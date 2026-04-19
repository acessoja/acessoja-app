from django.db import models
from django.conf import settings

class ModalAvaliacao(models.Model):
    local = models.ForeignKey(
        'locais.Local',  # Substitua 'locais' pelo nome do app onde Local está definido
        on_delete=models.CASCADE,
        related_name='avaliacoes'
    )
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    pergunta_1 = models.CharField(max_length=10, choices=[(
        'Sim', 'Sim'), ('Não', 'Não'), ('Não sei', 'Não sei')])
    pergunta_2 = models.CharField(max_length=10, choices=[(
        'Sim', 'Sim'), ('Não', 'Não'), ('Não sei', 'Não sei')])
    pergunta_3 = models.CharField(max_length=10, choices=[(
        'Sim', 'Sim'), ('Não', 'Não'), ('Não sei', 'Não sei')])
    pergunta_4 = models.CharField(max_length=10, choices=[(
        'Sim', 'Sim'), ('Não', 'Não'), ('Não sei', 'Não sei')])
    estrelas = models.PositiveIntegerField(default=0)  # De 1 a 5 estrelas
    data_resposta = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Avaliação de {self.local.nome} por {self.user.username}"
