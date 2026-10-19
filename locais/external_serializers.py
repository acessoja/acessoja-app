import math

from rest_framework import serializers

from .services.categories import CATEGORIES


class FiniteFloat(serializers.FloatField):
    def to_internal_value(self, data):
        if isinstance(data, bool):
            self.fail("invalid")
        value = super().to_internal_value(data)
        if not math.isfinite(value):
            self.fail("invalid")
        return value


class StrictQuerySerializer(serializers.Serializer):
    def validate(self, attrs):
        if set(self.initial_data) - set(self.fields):
            raise serializers.ValidationError("Parâmetro geográfico desconhecido.")
        getlist = getattr(self.initial_data, "getlist", None)
        if getlist and any(len(getlist(k)) != 1 for k in self.initial_data):
            raise serializers.ValidationError("Envie cada parâmetro geográfico uma vez.")
        return attrs


class ExternalSearchSerializer(StrictQuerySerializer):
    latitude = FiniteFloat(min_value=-90, max_value=90)
    longitude = FiniteFloat(min_value=-180, max_value=180)
    raio = serializers.IntegerField(min_value=100, max_value=3000, default=1500)
    categoria = serializers.ChoiceField(choices=list(CATEGORIES), required=False)
    limite = serializers.IntegerField(min_value=1, max_value=100, default=50)


class ExternalPlaceSerializer(serializers.Serializer):
    id = serializers.CharField()
    external_id = serializers.CharField()
    source = serializers.CharField()
    nome = serializers.CharField()
    categoria = serializers.CharField()
    categoria_label = serializers.CharField()
    endereco = serializers.CharField(allow_blank=True)
    latitude = serializers.FloatField()
    longitude = serializers.FloatField()
    internal_id = serializers.IntegerField(allow_null=True)
    has_community_reviews = serializers.BooleanField()
    media_estrelas = serializers.FloatField(allow_null=True)
    accessibility_data = serializers.DictField()
    accessibility = serializers.DictField()
    linked_local = serializers.DictField(allow_null=True)
    additional_data = serializers.DictField()
    registration_token = serializers.CharField()


class ExternalResultsSerializer(serializers.Serializer):
    complete = serializers.BooleanField()
    fetched_at = serializers.FloatField(help_text="Epoch UTC da obtenção do dado público.")
    fresh_for_seconds = serializers.IntegerField()
    valid_for_seconds = serializers.IntegerField()
    correlation_id = serializers.CharField()
    results = ExternalPlaceSerializer(many=True)
    attribution = serializers.CharField()
    truncated = serializers.BooleanField()


class ExternalImportSerializer(serializers.Serializer):
    registration_token = serializers.CharField(max_length=8000)
    nome = serializers.CharField(max_length=255)
    endereco = serializers.CharField(max_length=255)


class CategorySerializer(serializers.Serializer):
    id = serializers.CharField()
    label = serializers.CharField()


class GeocodeQuerySerializer(StrictQuerySerializer):
    q = serializers.CharField(max_length=180, required=False)
    latitude = FiniteFloat(min_value=-90, max_value=90, required=False)
    longitude = FiniteFloat(min_value=-180, max_value=180, required=False)

    def validate(self, attrs):
        super().validate(attrs)
        query = "q" in attrs
        coords = "latitude" in attrs and "longitude" in attrs
        if query == coords or (query and ("latitude" in attrs or "longitude" in attrs)):
            raise serializers.ValidationError("Envie q OU latitude e longitude.")
        return attrs


class GeocodeResultSerializer(serializers.Serializer):
    kind = serializers.ChoiceField(choices=["region", "address", "place"])
    provider_id = serializers.CharField(allow_null=True)
    bounding_box = serializers.ListField(child=serializers.FloatField(), allow_null=True)
    place = serializers.DictField(allow_null=True)
    nome = serializers.CharField()
    latitude = serializers.FloatField()
    longitude = serializers.FloatField()


class GeographicErrorSerializer(serializers.Serializer):
    detail = serializers.CharField()
    code = serializers.CharField()
    stage = serializers.CharField()
    upstream_status = serializers.IntegerField(allow_null=True)
    retryable = serializers.BooleanField()
    retry_after_seconds = serializers.IntegerField(allow_null=True)
    retry_source = serializers.ChoiceField(choices=["application", "upstream"])
    correlation_id = serializers.CharField()
