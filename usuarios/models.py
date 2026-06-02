from django.contrib.auth.models import AbstractBaseUser, BaseUserManager
from django.db import models
from django.utils import timezone


class UsuarioManager(BaseUserManager):
    def create_user(self, nome, password=None, **extra_fields):
        if not nome:
            raise ValueError("O campo 'nome' é obrigatório")
        if 'senha' in extra_fields:
            password = extra_fields.pop('senha')
        extra_fields.setdefault('data_criacao', timezone.now())
        extra_fields.pop('is_staff', None)
        extra_fields.pop('is_superuser', None)
        extra_fields.pop('is_active', None)
        user = self.model(nome=nome, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, nome, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        return self.create_user(nome, password, **extra_fields)


class Usuario(AbstractBaseUser):
    id_usuario = models.AutoField(primary_key=True)  # Chave primária
    nome = models.CharField(max_length=255, unique=True)
    email = models.EmailField(unique=True)
    password = models.CharField(max_length=255)  # Campo padrão para senha
    data_criacao = models.DateTimeField()

    # ── Novos campos de perfil ──
    nome_completo = models.CharField(max_length=255, blank=True, default='')
    telefone = models.CharField(max_length=30, blank=True, default='')
    foto_perfil = models.TextField(blank=True, default='')  # base64 ou URL

    # ── Preferências / Configurações ──
    idioma = models.CharField(max_length=10, default='pt_BR')
    unidade_distancia = models.CharField(max_length=5, default='KM')  # KM ou Milha
    permitir_sugestoes = models.BooleanField(default=True)
    impedir_autobloqueio = models.BooleanField(default=False)

    # ── Privacidade ──
    perfil_publico = models.BooleanField(default=True)
    mostrar_avaliacoes = models.BooleanField(default=True)
    compartilhar_localizacao = models.BooleanField(default=False)
    historico_visivel = models.BooleanField(default=True)

    objects = UsuarioManager()

    USERNAME_FIELD = 'nome'
    REQUIRED_FIELDS = ['email']

    class Meta:
        db_table = 'usuarios'
        managed = True

    def __str__(self):
        return self.nome

    @property
    def is_staff(self):
        return True

    @property
    def is_superuser(self):
        return True

    @property
    def is_active(self):
        return True

    def has_perm(self, perm, obj=None):
        return True

    def has_module_perms(self, app_label):
        return True