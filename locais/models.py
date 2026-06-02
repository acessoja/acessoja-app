from django.db import models
from django.conf import settings  # Importa a configuração AUTH_USER_MODEL
from django.contrib.auth.models import User



class Local(models.Model):
    id_local = models.AutoField(primary_key=True)
    nome = models.CharField(max_length=255)
    endereco = models.CharField(max_length=255)
    distancia = models.FloatField()
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    aberto = models.BooleanField(default=True)
    imagem = models.CharField(max_length=255, null=True, blank=True)
    cao_guia = models.BooleanField(default=False)
    mesa_acessivel = models.BooleanField(default=False)
    banheiro_acessivel = models.BooleanField(default=False)
    rampa_acesso = models.BooleanField(default=False)
    cardapio_braille = models.BooleanField(default=False)
    data_criacao = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'local'  # Nome da tabela no banco de dados
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
        return f"Visita a {self.local.nome} por {self.user.nome} em {self.data_visita}"
