from django.db import models
from django.conf import settings


class Local(models.Model):
    id_local = models.AutoField(primary_key=True)
    nome = models.CharField(max_length=255)
    endereco = models.CharField(max_length=255)
    distancia = models.FloatField()
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    aberto = models.BooleanField(default=True)
    imagem = models.CharField(max_length=255, blank=True)
    cao_guia = models.BooleanField(default=False)
    mesa_acessivel = models.BooleanField(default=False)
    banheiro_acessivel = models.BooleanField(default=False)
    rampa_acesso = models.BooleanField(default=False)
    cardapio_braille = models.BooleanField(default=False)
    data_criacao = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.nome

    class Meta:
        db_table = 'local'
        managed = True

    @property
    def media_estrelas(self):
        avaliacoes = self.avaliacoes.all()
        if avaliacoes.exists():
            return round(avaliacoes.aggregate(models.Avg('estrelas'))['estrelas__avg'], 1)
        return 0.0


class VisitaRecente(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='visitas')
    local = models.ForeignKey(Local, on_delete=models.CASCADE, related_name='visitas')
    data_visita = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'visita_recente'
        ordering = ['-data_visita']
        managed = True

    def __str__(self):
        return f"Visita a {self.local.nome} por {self.user} em {self.data_visita}"
