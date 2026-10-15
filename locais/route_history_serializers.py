import math
from rest_framework import serializers

from usuarios.route_history_preferences import StrictHistorySerializer
from .models import RouteHistorySession


class FiniteNumber(serializers.FloatField):
    def to_internal_value(self, value):
        if isinstance(value, bool):
            raise serializers.ValidationError("Número válido obrigatório.")
        result = super().to_internal_value(value)
        if not math.isfinite(result):
            raise serializers.ValidationError("Número finito obrigatório.")
        return result


class HistoryMetricsSerializer(StrictHistorySerializer):
    consent_revision = serializers.IntegerField(min_value=0)
    origin_latitude = FiniteNumber(min_value=-90, max_value=90, required=False)
    origin_longitude = FiniteNumber(min_value=-180, max_value=180, required=False)
    estimated_distance = FiniteNumber(min_value=0, required=False)
    estimated_duration = FiniteNumber(min_value=0, required=False)

    def validate(self, attrs):
        if ("origin_latitude" in attrs) != ("origin_longitude" in attrs):
            raise serializers.ValidationError("Informe ambas as coordenadas de origem ou nenhuma.")
        return attrs


class RouteHistoryStartSerializer(HistoryMetricsSerializer):
    event = serializers.ChoiceField(choices=["started"])
    session_id = serializers.UUIDField()
    destination_name = serializers.CharField(max_length=255)
    destination_source = serializers.ChoiceField(choices=["acessoja", "openstreetmap", "manual"])
    local_id = serializers.IntegerField(min_value=1, required=False)
    external_id = serializers.RegexField(r"^osm:(node|way|relation):[1-9][0-9]*$", max_length=64, required=False)
    latitude = FiniteNumber(min_value=-90, max_value=90)
    longitude = FiniteNumber(min_value=-180, max_value=180)

    def validate(self, attrs):
        attrs = super().validate(attrs)
        source = attrs["destination_source"]
        if (source != "acessoja" and "local_id" in attrs) or (source != "openstreetmap" and "external_id" in attrs):
            raise serializers.ValidationError("Referência incompatível com a origem do destino.")
        if source == "acessoja" and "local_id" not in attrs:
            raise serializers.ValidationError({"local_id": ["Informe o local interno."]})
        if source == "openstreetmap" and "external_id" not in attrs:
            raise serializers.ValidationError({"external_id": ["Informe a identidade OpenStreetMap."]})
        return attrs


class RouteHistoryEventSerializer(HistoryMetricsSerializer):
    event = serializers.ChoiceField(choices=["recalculated", "resumed", "interrupted", "arrived", "cancelled"])
    event_index = serializers.IntegerField(min_value=1)
    arrival_confirmed = serializers.BooleanField(default=False)

    def validate(self, attrs):
        attrs = super().validate(attrs)
        if (attrs["event"] == "arrived") != attrs["arrival_confirmed"]:
            raise serializers.ValidationError("Conclusão exige um evento de chegada confirmada pelo navegador.")
        return attrs


class RouteHistoryReadSerializer(serializers.ModelSerializer):
    local_id = serializers.IntegerField(read_only=True, allow_null=True)
    destination_available = serializers.SerializerMethodField()

    def get_destination_available(self, obj) -> bool:
        return obj.destination_source != "acessoja" or obj.local_id is not None

    class Meta:
        model = RouteHistorySession
        fields = [
            "session_id",
            "destination_name",
            "destination_source",
            "local_id",
            "external_id",
            "destination_available",
            "latitude",
            "longitude",
            "origin_latitude",
            "origin_longitude",
            "started_at",
            "ended_at",
            "status",
            "estimated_distance",
            "estimated_duration",
            "event_index",
        ]
        read_only_fields = fields
