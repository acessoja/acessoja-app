from django.contrib.auth.models import AbstractBaseUser, BaseUserManager
from django.db import models
from django.utils import timezone
import uuid


class UsuarioManager(BaseUserManager):
    def create_user(self, nome, password=None, **extra_fields):
        if not nome:
            raise ValueError("O campo 'nome' é obrigatório")
        if "senha" in extra_fields:
            password = extra_fields.pop("senha")
        extra_fields.setdefault("data_criacao", timezone.now())
        extra_fields.setdefault("is_staff", False)
        extra_fields.setdefault("is_superuser", False)
        extra_fields.setdefault("is_active", True)
        user = self.model(nome=nome, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, nome, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        if extra_fields["is_staff"] is not True or extra_fields["is_superuser"] is not True:
            raise ValueError("Superusuário exige permissões explícitas.")
        return self.create_user(nome, password, **extra_fields)


class Usuario(AbstractBaseUser):
    id_usuario = models.AutoField(primary_key=True)  # Chave primária
    nome = models.CharField(max_length=255, unique=True)
    email = models.EmailField(unique=True)
    password = models.CharField(max_length=255)  # Campo padrão para senha
    data_criacao = models.DateTimeField()

    # ── Novos campos de perfil ──
    nome_completo = models.CharField(max_length=255, blank=True, default="")
    telefone = models.CharField(max_length=30, blank=True, default="")
    foto_perfil = models.TextField(blank=True, default="")  # base64 ou URL

    # ── Preferências / Configurações ──
    idioma = models.CharField(max_length=10, default="pt_BR")
    unidade_distancia = models.CharField(max_length=5, default="KM")  # KM ou Milha
    permitir_sugestoes = models.BooleanField(default=True)
    impedir_autobloqueio = models.BooleanField(default=False)

    # ── Privacidade ──
    perfil_publico = models.BooleanField(default=True)
    mostrar_avaliacoes = models.BooleanField(default=True)
    compartilhar_localizacao = models.BooleanField(default=False)
    historico_visivel = models.BooleanField(default=True)

    # Private search criteria; excluded from profile and public serializers.
    accessibility_preferences = models.JSONField(default=list, blank=True)

    # Separate, explicit opt-in for new route-history collection.
    save_route_history = models.BooleanField(default=False)
    save_route_origin = models.BooleanField(default=False)
    route_history_revision = models.PositiveBigIntegerField(default=0)
    # Immutable identity for applying deletion receipts after a database restore.
    privacy_id = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    credential_revision = models.PositiveBigIntegerField(default=0)

    is_staff = models.BooleanField(default=False)
    is_superuser = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)

    objects = UsuarioManager()

    USERNAME_FIELD = "nome"
    REQUIRED_FIELDS = ["email"]

    class Meta:
        db_table = "usuarios"
        managed = True

    def __str__(self):
        return self.nome

    def has_perm(self, perm, obj=None):
        return self.is_active and self.is_superuser

    def has_module_perms(self, app_label):
        return self.is_active and self.is_superuser


class PrivacyConsent(models.Model):
    user = models.ForeignKey(Usuario, on_delete=models.CASCADE, related_name="privacy_consents")
    purpose = models.CharField(max_length=32, choices=[("route_history", "Histórico de rotas"),
                                                       ("route_origin", "Origem aproximada")])
    notice_version = models.CharField(max_length=32)
    granted = models.BooleanField()
    recorded_at = models.DateTimeField(default=timezone.now)

    def __str__(self):
        return f"Consent {self.pk}"

    class Meta:
        ordering = ["recorded_at", "pk"]
        indexes = [models.Index(fields=["user", "purpose", "-recorded_at"], name="consent_owner_purpose")]


class AccountMailJob(models.Model):
    """A bounded outbox contains no recipient text, reset token or password hash."""
    user = models.ForeignKey(Usuario, null=True, on_delete=models.CASCADE)
    kind = models.CharField(max_length=16, choices=[("reset", "Redefinição"), ("changed", "Aviso de alteração")])
    credential_revision = models.PositiveBigIntegerField(default=0)
    state = models.CharField(max_length=12, default="pending", choices=[
        ("pending", "Pendente"), ("sending", "Enviando"), ("done", "Finalizado"), ("failed", "Falhou")])
    attempts = models.PositiveSmallIntegerField(default=0)
    created_at = models.DateTimeField(default=timezone.now)
    available_at = models.DateTimeField(default=timezone.now)
    lease_until = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"Account mail job {self.pk}"

    class Meta:
        indexes = [models.Index(fields=["state", "available_at"], name="mail_outbox_ready")]


class AccountDeletionReceipt(models.Model):
    """Minimal pseudonymous restore suppression, not a retained user profile."""
    operation_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    privacy_id = models.UUIDField(unique=True)
    deleted_at = models.DateTimeField(default=timezone.now)
    published = models.BooleanField(default=False)

    def __str__(self):
        return f"Deletion receipt {self.operation_id}"
