from django.db import models
from django.conf import settings


class Local(models.Model):
    # This legacy establishment table can also have reviews by other accounts.
    # Removing its creator must not cascade through those shared records.
    user = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL)
    nome = models.CharField(max_length=255)
    endereco = models.CharField(max_length=255)
    distancia = models.FloatField()
    aberto = models.BooleanField(default=True)

    @property
    def media_estrelas(self):
        avaliacoes = self.avaliacoes.all()
        if avaliacoes.exists():
            return round(avaliacoes.aggregate(models.Avg('estrelas'))['estrelas__avg'], 1)
        return 0

    def __str__(self):
        return self.nome


class AvaliacaoLocal(models.Model):
    local = models.ForeignKey(
        Local, on_delete=models.CASCADE, related_name='avaliacoes')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    comentario = models.TextField(blank=True)
    estrelas = models.PositiveIntegerField(default=0)
    data_criacao = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('local', 'user')

    def __str__(self):
        return f"Avaliação de {self.local.nome} por {self.user.nome}"
