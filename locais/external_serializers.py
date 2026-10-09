import math

from rest_framework import serializers

from .services.categories import CATEGORIES


class FiniteFloat(serializers.FloatField):
    def to_internal_value(self, data):
        value = super().to_internal_value(data)
        if not math.isfinite(value):
            self.fail("invalid")
        return value


class ExternalSearchSerializer(serializers.Serializer):
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
    additional_data = serializers.DictField()
    registration_token = serializers.CharField()


class ExternalResultsSerializer(serializers.Serializer):
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


class GeocodeQuerySerializer(serializers.Serializer):
    q = serializers.CharField(max_length=180, required=False)
    latitude = FiniteFloat(min_value=-90, max_value=90, required=False)
    longitude = FiniteFloat(min_value=-180, max_value=180, required=False)

    def validate(self, attrs):
        query = "q" in attrs
        coords = "latitude" in attrs and "longitude" in attrs
        if query == coords or (query and ("latitude" in attrs or "longitude" in attrs)):
            raise serializers.ValidationError("Envie q OU latitude e longitude.")
        return attrs


class GeocodeResultSerializer(serializers.Serializer):
    nome = serializers.CharField()
    latitude = serializers.FloatField()
    longitude = serializers.FloatField()
