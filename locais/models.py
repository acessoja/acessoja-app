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
    data_criacao = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'local'  # Nome da tabela no banco de dados
        managed = False      # Django não gerenciará essa tabela (somente leitura/escrita)
