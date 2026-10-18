from django.db.models import Avg, Count
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from locais.models import Local
from locais.serializers import LocalSerializer
from locais.services.accessibility import populate_accessibility_context
from modal_avaliacao.models import ModalAvaliacao
from .models import Favorito


class StrictPositiveId(serializers.IntegerField):
    def to_internal_value(self, data):
        if isinstance(data, bool):
            self.fail("invalid")
        return super().to_internal_value(data)


class FavoriteCreateSerializer(serializers.Serializer):
    local = serializers.PrimaryKeyRelatedField(queryset=Local.objects.all(), pk_field=StrictPositiveId(min_value=1))

    def to_internal_value(self, data):
        if not isinstance(data, dict) or set(data) != {"local"}:
            raise serializers.ValidationError({
                "detail": "Envie somente o ID interno em local; o proprietário é a sessão."
            })
        return super().to_internal_value(data)


class PublicRatingSerializer(serializers.Serializer):
    average = serializers.FloatField(allow_null=True)
    count = serializers.IntegerField(min_value=0)


class OwnReviewSummarySerializer(serializers.Serializer):
    id = serializers.IntegerField(min_value=1)
    estrelas = serializers.IntegerField(allow_null=True)
    is_current = serializers.BooleanField()
    is_valid = serializers.BooleanField()
    can_edit = serializers.BooleanField()
    questionnaire_version = serializers.IntegerField()


def favorite_context(locals_, context):
    """A fixed three review queries per page, not per venue. No private foreign reviews."""
    locals_ = list(locals_)
    ids = [local.pk for local in locals_]
    populate_accessibility_context(locals_, context)
    public = ModalAvaliacao.objects.filter(
        local_id__in=ids, is_current=True, is_valid=True,
        user__mostrar_avaliacoes=True, estrelas__gte=1, estrelas__lte=5,
    ).values("local_id").annotate(average=Avg("estrelas"), count=Count("id"))
    context["favorite_public_stats"] = {
        row["local_id"]: {"average": round(row["average"], 1), "count": row["count"]} for row in public
    }
    own = ModalAvaliacao.objects.filter(
        user=context["request"].user, local_id__in=ids, is_current=True,
    ).values("id", "local_id", "estrelas", "is_current", "is_valid", "questionnaire_version")
    context["favorite_own_reviews"] = {
        row["local_id"]: {
            **{key: value for key, value in row.items() if key != "local_id"},
            "estrelas": row["estrelas"] if 1 <= row["estrelas"] <= 5 else None,
            "can_edit": True,
        } for row in own
    }
    return context


class FavoriteLocalSerializer(LocalSerializer):
    public_rating = serializers.SerializerMethodField()
    own_review = serializers.SerializerMethodField()
    opening_status = serializers.CharField(read_only=True, default="unknown")

    def _review_stats(self, obj):
        return self.context["favorite_public_stats"].get(obj.pk, {"average": None, "count": 0})

    def get_media_estrelas(self, obj) -> float | None:
        return self._review_stats(obj)["average"]

    @extend_schema_field(PublicRatingSerializer)
    def get_public_rating(self, obj):
        return self._review_stats(obj)

    @extend_schema_field(OwnReviewSummarySerializer(allow_null=True))
    def get_own_review(self, obj):
        return self.context["favorite_own_reviews"].get(obj.pk)

    class Meta(LocalSerializer.Meta):
        # Neither the old unmeasured distance nor the default open boolean is live evidence.
        fields = [field for field in LocalSerializer.Meta.fields if field not in {"distancia", "aberto"}] + [
            "public_rating", "own_review", "opening_status",
        ]


class FavoriteSerializer(serializers.ModelSerializer):
    local_detalhes = FavoriteLocalSerializer(source="local", read_only=True)

    class Meta:
        model = Favorito
        fields = ["id", "local", "criado_em", "local_detalhes"]
        read_only_fields = fields


class FavoriteStateSerializer(serializers.Serializer):
    local = serializers.IntegerField(min_value=1)
    id = serializers.IntegerField(allow_null=True)
    exists = serializers.BooleanField()


class FavoriteStatesSerializer(serializers.Serializer):
    results = FavoriteStateSerializer(many=True)
