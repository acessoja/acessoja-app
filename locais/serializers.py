from django.db import transaction
from django.utils import timezone
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers
from .models import Local, VisitaRecente
from .accessibility import merge_information
from .accessibility_serializers import AccessibilityInformationField, ConsolidatedAccessibilitySerializer
from .services.accessibility import local_accessibility


class LocalSerializer(serializers.ModelSerializer):
    accessibility_information = AccessibilityInformationField(required=False)
    accessibility = serializers.SerializerMethodField()
    origins = serializers.SerializerMethodField()
    missing_resources = serializers.SerializerMethodField()

    @extend_schema_field(ConsolidatedAccessibilitySerializer)
    def get_accessibility(self, obj):
        return local_accessibility(obj, self.context)

    def get_origins(self, obj) -> list[str]:
        return ["acessoja", "openstreetmap"] if obj.osm_id else ["acessoja"]

    def get_missing_resources(self, obj) -> list[str]:
        return self.context.get("missing_resources", {}).get(obj.pk, [])

    def validate(self, attrs):
        if set(self.initial_data) & {"accessibility", "origins", "missing_resources"}:
            raise serializers.ValidationError("Os estados consolidados são somente leitura.")
        return attrs

    def create(self, validated_data):
        information = validated_data.pop("accessibility_information", {})
        validated_data["accessibility_information"] = merge_information(
            {}, information, timezone.now().isoformat(), "acessoja_registration"
        )
        with transaction.atomic():
            return super().create(validated_data)

    def update(self, instance, validated_data):
        with transaction.atomic():
            instance = Local.objects.select_for_update().get(pk=instance.pk)
            if "accessibility_information" in validated_data:
                validated_data["accessibility_information"] = merge_information(
                    instance.accessibility_information, validated_data["accessibility_information"],
                    timezone.now().isoformat(), "acessoja_staff_update"
                )
            return super().update(instance, validated_data)

    media_estrelas = serializers.SerializerMethodField(
        help_text="Media das estrelas das avaliacoes do local, de 0 a 5 (calculada).",
    )

    quantidade_avaliacoes = serializers.SerializerMethodField()
    categoria_label = serializers.SerializerMethodField()

    def get_quantidade_avaliacoes(self, obj) -> int:
        return self._review_stats(obj)["count"]

    def get_media_estrelas(self, obj) -> float:
        value = self._review_stats(obj)["average"]
        return round(value, 1) if value is not None else 0.0

    def _review_stats(self, obj):
        request = self.context.get("request")
        user = getattr(request, "user", None)
        own_id = user.pk if user and user.is_authenticated else None
        key = (obj.pk, own_id)
        if key not in self.context.get("visible_review_stats", {}):
            local_accessibility(obj, self.context)
        return self.context["visible_review_stats"][key]

    def get_categoria_label(self, obj) -> str:
        from .services.categories import CATEGORIES

        return CATEGORIES[obj.categoria]["label"] if obj.categoria in CATEGORIES else "Categoria não informada"

    class Meta:
        model = Local
        fields = [
            "id_local",
            "nome",
            "endereco",
            "distancia",
            "latitude",
            "longitude",
            "aberto",
            "imagem",
            "cao_guia",
            "mesa_acessivel",
            "banheiro_acessivel",
            "rampa_acesso",
            "cardapio_braille",
            "media_estrelas",
            "data_criacao",
            "categoria",
            "categoria_label",
            "osm_id",
            "quantidade_avaliacoes",
            "accessibility_information",
            "accessibility",
            "origins",
            "missing_resources",
        ]
        read_only_fields = ["osm_id"]
        extra_kwargs = {
            "id_local": {"help_text": "Identificador unico do local."},
            "nome": {"help_text": "Nome do estabelecimento ou local publico."},
            "endereco": {"help_text": "Endereco completo em texto livre."},
            "distancia": {"help_text": "Distancia em km ate o usuario."},
            "latitude": {"help_text": "Latitude em graus decimais. Opcional."},
            "longitude": {"help_text": "Longitude em graus decimais. Opcional."},
            "aberto": {"help_text": "Indica se o local esta em funcionamento."},
            "imagem": {"help_text": "URL ou nome do arquivo de imagem do local."},
            "cao_guia": {"help_text": "Aceita cao-guia."},
            "mesa_acessivel": {"help_text": "Tem mesa acessivel para cadeirante."},
            "banheiro_acessivel": {"help_text": "Tem banheiro adaptado."},
            "rampa_acesso": {"help_text": "Tem rampa de acesso na entrada."},
            "cardapio_braille": {"help_text": "Tem cardapio em braile."},
            "data_criacao": {"help_text": "Data de cadastro do local (ISO-8601)."},
        }


class VisitaRecenteSerializer(serializers.ModelSerializer):
    local_detalhes = LocalSerializer(source="local", read_only=True, help_text="Dados completos do local visitado.")
    nome_usuario = serializers.CharField(source="user.nome", read_only=True, help_text="Nome do usuario que visitou.")

    class Meta:
        model = VisitaRecente
        fields = ["id", "user", "nome_usuario", "local", "local_detalhes", "data_visita", "arrival_confirmed"]
        read_only_fields = ["id", "user", "data_visita", "arrival_confirmed"]


class ArrivalRequestSerializer(serializers.Serializer):
    local = serializers.IntegerField(min_value=1)
    latitude = serializers.FloatField(min_value=-90, max_value=90)
    longitude = serializers.FloatField(min_value=-180, max_value=180)
    accuracy = serializers.FloatField(min_value=0.01, max_value=50)
