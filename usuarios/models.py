from django.contrib.auth.models import AbstractBaseUser, BaseUserManager
from django.db import models

class UsuarioManager(BaseUserManager):
    def create_user(self, nome, senha=None, **extra_fields):
        if not nome:
            raise ValueError("O campo 'nome' é obrigatório")
        user = self.model(nome=nome, **extra_fields)
        user.set_password(senha)  # Usa o método para criar o hash da senha
        user.save(using=self._db)
        return user

    def create_superuser(self, nome, senha=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        return self.create_user(nome, senha, **extra_fields)

class Usuario(AbstractBaseUser):
    id_usuario = models.AutoField(primary_key=True)  # Chave primária
    nome = models.CharField(max_length=255, unique=True)
    email = models.EmailField(unique=True)
    password = models.CharField(max_length=255)  # Campo padrão para senha
    data_criacao = models.DateTimeField()


    objects = UsuarioManager()

    USERNAME_FIELD = 'nome'
    REQUIRED_FIELDS = ['email']

    class Meta:
        db_table = 'usuarios'
        managed = False  # A tabela é gerenciada manualmente

    def __str__(self):
        return self.nome