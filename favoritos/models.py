from django.conf import settings
from django.db import models


class Favorito(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="favoritos")
    local = models.ForeignKey("locais.Local", on_delete=models.CASCADE, related_name="favoritos")
    criado_em = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-criado_em", "-id"]
        constraints = [models.UniqueConstraint(fields=["user", "local"], name="favorito_owner_local_unique")]
        indexes = [models.Index(fields=["user", "-criado_em", "-id"], name="favorito_owner_date")]

    def __str__(self):
        return f"Favorito {self.pk}"


class ListaPessoal(models.Model):
    ICONS = [(key, label) for key, label in (
        ("heart", "Favorito"), ("briefcase-business", "Trabalho"),
        ("graduation-cap", "Faculdade"), ("users", "Família"),
        ("house", "Casa"), ("bookmark", "Salvo"), ("map-pin", "Lugar especial"),
        ("hospital", "Hospital"), ("cross", "Farmácia"),
        ("accessibility", "Acessível"), ("wheelchair", "Cadeirante"),
        ("eye", "Acessibilidade visual"), ("ear", "Acessibilidade auditiva"),
        ("heart-handshake", "Apoio"), ("shield-check", "Local seguro"),
        ("bus", "Ônibus"), ("car", "Estacionamento"),
        ("train-front", "Estação"), ("footprints", "Caminhada"),
        ("bike", "Bicicleta"), ("route", "Rota frequente"),
        ("navigation", "Destino"), ("map", "Ponto de referência"),
        ("utensils", "Restaurante"), ("shopping-cart", "Mercado"),
        ("shopping-bag", "Loja"), ("landmark", "Serviço público"),
        ("trees", "Parque"), ("dumbbell", "Academia"),
        ("book-open", "Biblioteca"),
        # Legacy IDs remain accepted for lists already persisted by the app.
        ("favorite", "Favoritos"), ("flag", "Quero visitar"), ("star", "Estrela"),
        ("restaurant", "Talheres"), ("shopping_bag", "Sacola"), ("luggage", "Mala"),
        ("home", "Casa"), ("menu_book", "Livro"), ("coffee", "Café"),
        ("park", "Árvore"), ("local_hospital", "Hospital"), ("music_note", "Música"),
        ("photo_camera", "Câmera"), ("place", "Marcador"), ("check", "Visitado"),
    )]
    COLORS = [(key, label) for key, label in (
        ("blue", "Azul"), ("teal", "Verde-azulado"), ("orange", "Laranja"),
        ("purple", "Roxo"), ("red", "Vermelho"), ("green", "Verde"),
    )]
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="listas_pessoais")
    nome = models.CharField(max_length=80)
    descricao = models.CharField(max_length=240, blank=True)
    icone = models.CharField(max_length=24, choices=ICONS, default="favorite")
    cor = models.CharField(max_length=16, choices=COLORS, default="blue")
    sistema = models.BooleanField(default=False)
    visivel_mapa = models.BooleanField(default=True)
    ordem = models.PositiveIntegerField(default=0)
    criado_em = models.DateTimeField(auto_now_add=True)
    atualizado_em = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["ordem", "nome", "id"]
        constraints = [models.UniqueConstraint(fields=["user", "nome"], name="lista_pessoal_owner_name_unique")]

    def __str__(self):
        return self.nome


class ItemLista(models.Model):
    lista = models.ForeignKey(ListaPessoal, on_delete=models.CASCADE, related_name="itens")
    local = models.ForeignKey("locais.Local", on_delete=models.CASCADE, related_name="itens_listas")
    criado_em = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-criado_em", "-id"]
        constraints = [models.UniqueConstraint(fields=["lista", "local"], name="item_lista_unique")]

    def __str__(self):
        return f"Item de lista {self.pk}"


class EstadoPessoalLocal(models.Model):
    STATUS = [("unknown", "Não informado"), ("want", "Quero visitar"), ("visited", "Já visitei")]
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="estados_locais")
    local = models.ForeignKey("locais.Local", on_delete=models.CASCADE, related_name="estados_pessoais")
    status = models.CharField(max_length=12, choices=STATUS, default="unknown")
    nota = models.TextField(max_length=1000, blank=True)
    atualizado_em = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["user", "local"], name="estado_pessoal_owner_local_unique")]
        indexes = [models.Index(fields=["user", "status"], name="estado_pessoal_owner_status")]

    def __str__(self):
        return f"Estado pessoal do local {self.pk}"
