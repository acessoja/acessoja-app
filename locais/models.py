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
    # Metadados opcionais: não modificam os campos da Sprint 1.
    categoria = models.CharField(max_length=32, blank=True)
    osm_id = models.CharField(max_length=64, unique=True, null=True, blank=True)
    accessibility_information = models.JSONField(default=dict, blank=True)
    data_criacao = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.nome

    class Meta:
        db_table = "local"
        managed = True

    @property
    def media_estrelas(self):
        avaliacoes = self.avaliacoes.filter(is_current=True, is_valid=True)
        if avaliacoes.exists():
            return round(avaliacoes.aggregate(models.Avg("estrelas"))["estrelas__avg"], 1)
        return 0.0


class VisitaRecente(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="visitas")
    local = models.ForeignKey(Local, on_delete=models.CASCADE, related_name="visitas")
    data_visita = models.DateTimeField(auto_now_add=True)
    arrival_confirmed = models.BooleanField(default=False)

    class Meta:
        db_table = "visita_recente"
        ordering = ["-data_visita"]
        managed = True

    def __str__(self):
        return f"Visita a {self.local.nome} por {self.user} em {self.data_visita}"


class RouteHistorySession(models.Model):
    """Private session snapshots. Deleted rows retain only an opaque retry tombstone."""

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="route_sessions")
    session_id = models.UUIDField()
    consent_revision = models.PositiveBigIntegerField(default=0)
    destination_name = models.CharField(max_length=255, blank=True)
    destination_source = models.CharField(max_length=32, blank=True, choices=[
        ("acessoja", "AcessoJá"), ("openstreetmap", "OpenStreetMap"), ("manual", "Destino manual")])
    local = models.ForeignKey(Local, null=True, blank=True, on_delete=models.SET_NULL)
    external_id = models.CharField(max_length=64, blank=True)
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    origin_latitude = models.FloatField(null=True, blank=True)
    origin_longitude = models.FloatField(null=True, blank=True)
    estimated_distance = models.FloatField(null=True, blank=True)
    estimated_duration = models.FloatField(null=True, blank=True)
    started_at = models.DateTimeField(null=True, blank=True)
    ended_at = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=16, blank=True, choices=[
        ("in_progress", "Em andamento"), ("completed", "Concluída"),
        ("cancelled", "Cancelada"), ("interrupted", "Interrompida")])
    event_index = models.PositiveIntegerField(default=0)
    last_event = models.CharField(max_length=16, blank=True)
    deleted_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"Route session {self.session_id}"

    class Meta:
        ordering = ["-started_at", "-id"]
        constraints = [models.UniqueConstraint(fields=["user", "session_id"], name="route_session_owner_unique")]
        indexes = [models.Index(fields=["user", "-started_at", "-id"], name="route_history_owner_date")]


class ManualRegistrationGuard(models.Model):
    """Singleton created during migration, never created on request."""
    id = models.PositiveSmallIntegerField(primary_key=True, default=1, editable=False)

    def __str__(self):
        return "Manual registration guard"


class ManualPlaceRegistration(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    request_id = models.UUIDField()
    payload_hash = models.CharField(max_length=64)
    local = models.ForeignKey(Local, null=True, on_delete=models.SET_NULL)
    distinct_reason = models.CharField(max_length=500, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Manual request {self.request_id}"

    class Meta:
        constraints = [models.UniqueConstraint(fields=["user", "request_id"], name="manual_registration_owner_uuid")]
