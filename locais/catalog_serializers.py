from rest_framework import serializers

from .accessibility_serializers import ConsolidatedAccessibilitySerializer


class CatalogQuerySerializer(serializers.Serializer):
    bbox = serializers.CharField(required=False, help_text="sul,oeste,norte,leste; inclui a borda")
    search = serializers.CharField(required=False, max_length=180)
    categorias = serializers.CharField(required=False)
    recursos = serializers.CharField(required=False)
    origens = serializers.CharField(required=False)
    incluir_desconhecidos = serializers.BooleanField(required=False)
    ordering = serializers.ChoiceField(choices=["name", "proximity", "rating"], required=False)
    origin_lat = serializers.FloatField(required=False)
    origin_lon = serializers.FloatField(required=False)
    page = serializers.IntegerField(min_value=1, required=False)
    page_size = serializers.IntegerField(min_value=1, max_value=50, required=False)
    paginated = serializers.BooleanField(required=False, help_text="O catálogo sempre pagina, inclusive se false.")
    catalog_version = serializers.CharField(required=False, max_length=100)


class CatalogPlaceSerializer(serializers.Serializer):
    catalog_id = serializers.IntegerField()
    external_id = serializers.CharField()
    source = serializers.CharField()
    storage = serializers.CharField()
    origins = serializers.ListField(child=serializers.CharField())
    nome = serializers.CharField()
    name_is_fallback = serializers.BooleanField()
    endereco = serializers.CharField(allow_blank=True)
    categoria = serializers.CharField()
    categoria_label = serializers.CharField()
    latitude = serializers.FloatField()
    longitude = serializers.FloatField()
    internal_id = serializers.IntegerField(allow_null=True)
    linked_local = serializers.JSONField(allow_null=True)
    geometry_type = serializers.CharField()
    point_method = serializers.CharField()
    crosses_boundary = serializers.BooleanField()
    access_restriction = serializers.BooleanField()
    source_status = serializers.CharField()
    source_snapshot_at = serializers.DateTimeField(allow_null=True)
    catalog_snapshot_at = serializers.DateTimeField(allow_null=True)
    source_observed_in_current_batch = serializers.BooleanField()
    attribution = serializers.CharField()
    license_url = serializers.URLField()
    opening_status = serializers.CharField()
    quantidade_avaliacoes = serializers.IntegerField()
    media_estrelas = serializers.FloatField(allow_null=True)
    accessibility_data = serializers.JSONField()
    accessibility = ConsolidatedAccessibilitySerializer()
    missing_resources = serializers.ListField(child=serializers.CharField())


class CatalogResultsSerializer(serializers.Serializer):
    count = serializers.IntegerField()
    next = serializers.URLField(allow_null=True)
    previous = serializers.URLField(allow_null=True)
    catalog_version = serializers.CharField()
    available = serializers.BooleanField()
    coverage_complete = serializers.BooleanField()
    scope = serializers.CharField()
    ordering = serializers.CharField()
    results = CatalogPlaceSerializer(many=True)


class CatalogConfirmSerializer(serializers.Serializer):
    confirmed = serializers.BooleanField()
    nome = serializers.CharField(max_length=255, trim_whitespace=True)
    # OSM may have an exact position but no postal address. Never force users to invent one.
    endereco = serializers.CharField(max_length=255, trim_whitespace=True, allow_blank=True)

    def validate(self, attrs):
        if not attrs["confirmed"] or set(self.initial_data) - set(self.fields):
            raise serializers.ValidationError("Confirme os dados disponíveis; identidade e coordenadas vêm do catálogo.")
        if any(ord(c) < 32 for c in attrs["nome"] + attrs["endereco"]):
            raise serializers.ValidationError("Nome e endereço não podem conter caracteres de controle.")
        return attrs
