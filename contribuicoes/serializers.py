from rest_framework import serializers
from locais.serializers import LocalSerializer


class DiscoveryPlaceSerializer(LocalSerializer):
    distance_meters = serializers.IntegerField(read_only=True, allow_null=True, required=False)

    class Meta(LocalSerializer.Meta):
        fields = [*LocalSerializer.Meta.fields, "distance_meters"]


class AchievementSerializer(serializers.Serializer):
    code = serializers.CharField()
    name = serializers.CharField()
    description = serializers.CharField()
    icon = serializers.CharField()
    progress = serializers.IntegerField()
    target = serializers.IntegerField()
    unlocked = serializers.BooleanField()
    unlocked_at = serializers.DateTimeField(allow_null=True)


class ImpactSerializer(serializers.Serializer):
    points = serializers.IntegerField()
    level = serializers.IntegerField()
    title = serializers.CharField()
    next_level_points = serializers.IntegerField(allow_null=True)
    remaining_points = serializers.IntegerField()
    progress = serializers.FloatField()
    reviews = serializers.IntegerField()
    places = serializers.IntegerField()
    achievements_count = serializers.IntegerField()
    achievements = AchievementSerializer(many=True)
    profile = serializers.DictField()
    reliability = serializers.CharField()
    rules = serializers.DictField()


class ActivitySerializer(serializers.Serializer):
    id = serializers.IntegerField()
    delta = serializers.IntegerField()
    action = serializers.CharField()
    created_at = serializers.DateTimeField()
    local = serializers.DictField()
    evaluation_id = serializers.IntegerField(allow_null=True)


class DiscoveryQuerySerializer(serializers.Serializer):
    search = serializers.CharField(required=False, max_length=100)
    categoria = serializers.CharField(required=False, max_length=40)
    latitude = serializers.FloatField(required=False, min_value=-90, max_value=90)
    longitude = serializers.FloatField(required=False, min_value=-180, max_value=180)
    raio = serializers.IntegerField(required=False, default=3000, min_value=100, max_value=20000)
    estado = serializers.ChoiceField(required=False, choices=["all", "unreviewed", "incomplete", "visited"])

    def validate(self, attrs):
        import math

        if ("latitude" in attrs) != ("longitude" in attrs):
            raise serializers.ValidationError("Informe latitude e longitude juntas.")
        if any(not math.isfinite(attrs[c]) for c in ["latitude", "longitude"] if c in attrs):
            raise serializers.ValidationError("Coordenadas devem ser finitas.")
        return attrs
