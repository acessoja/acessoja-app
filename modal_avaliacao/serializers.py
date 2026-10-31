from rest_framework import serializers
from locais.serializers import LocalSerializer
from .models import ModalAvaliacao
from .questionnaire_fields import (
    AnswerDetailsField,
    AnswerMapField,
    CommentField,
    LegacyAnswerField,
    QuestionnaireVersionField,
    RatingField,
    prepare_write,
    validate_payload,
)


class ContributionResultSerializer(serializers.Serializer):
    operation = serializers.ChoiceField(choices=["created", "updated", "deleted"])
    outcome = serializers.ChoiceField(choices=["points_granted", "points_restored", "points_adjusted", "no_new_points"])
    points_delta = serializers.IntegerField()
    points = serializers.IntegerField()


class ContributionFeedbackSerializer(serializers.Serializer):
    points_delta = serializers.IntegerField()
    contribution_result = ContributionResultSerializer()


class ModalAvaliacaoSerializer(serializers.ModelSerializer):
    publicly_eligible = serializers.SerializerMethodField()
    expected_revision = serializers.UUIDField(write_only=True, required=False)
    operation_id = serializers.UUIDField(write_only=True, required=False)
    estrelas = RatingField()
    comentario = CommentField()
    questionnaire_version = QuestionnaireVersionField()
    answers = AnswerMapField(required=False)
    answer_details = AnswerDetailsField(required=False)
    pergunta_1 = LegacyAnswerField()
    pergunta_2 = LegacyAnswerField()
    pergunta_3 = LegacyAnswerField()
    pergunta_4 = LegacyAnswerField()
    nome_usuario = serializers.SerializerMethodField()
    local_detalhes = LocalSerializer(source="local", read_only=True)
    can_edit = serializers.SerializerMethodField()
    user = serializers.SerializerMethodField()
    points_delta = serializers.IntegerField(read_only=True, required=False)
    contribution_result = ContributionResultSerializer(read_only=True, required=False)

    class Meta:
        model = ModalAvaliacao
        fields = [
            "id",
            "local",
            "user",
            "nome_usuario",
            "pergunta_1",
            "pergunta_2",
            "pergunta_3",
            "pergunta_4",
            "estrelas",
            "comentario",
            "data_resposta",
            "local_detalhes",
            "can_edit",
            "points_delta",
            "contribution_result",
            "survey_completed",
            "questionnaire_version",
            "answers",
            "answer_details",
            "operation_id",
            "answer_dates",
            "is_current",
            "is_valid",
            "content_revision",
            "expected_revision",
            "publicly_eligible",
        ]
        read_only_fields = [
            "id",
            "user",
            "data_resposta",
            "can_edit",
            "survey_completed",
            "answer_dates",
            "is_current",
            "is_valid",
            "content_revision",
            "publicly_eligible",
        ]
        extra_kwargs = {
            "estrelas": {"min_value": 1, "max_value": 5},
            "comentario": {"max_length": 3000},
            **{f"pergunta_{i}": {"required": False} for i in range(1, 5)},
        }
        validators = []

    def get_publicly_eligible(self, obj) -> bool:
        return obj.is_current and obj.is_valid and obj.user.mostrar_avaliacoes and obj.user.is_active

    def to_representation(self, instance):
        result = super().to_representation(instance)
        if not self.get_can_edit(instance):
            masks = self.context.get("review_resource_masks")
            if masks is None:
                from django.db.models import Q
                from evidencias.models import ResourceEvidence

                keys = ResourceEvidence.objects.filter(
                    Q(current_revision__is_valid=False) | Q(superseded=True) | Q(withdrawn=True), review=instance
                ).values_list("resource", flat=True)
            else:
                keys = masks.get(instance.pk, ())
            result["answers"] = {key: value for key, value in result["answers"].items() if key not in keys}
            result["answer_dates"] = {key: value for key, value in result["answer_dates"].items() if key not in keys}
            result["answer_details"] = {
                key: value for key, value in result["answer_details"].items() if key not in keys
            }
        return result

    def get_can_edit(self, obj) -> bool:
        request = self.context.get("request")
        return bool(request and request.user.is_authenticated and request.user.pk == obj.user_id)

    def get_nome_usuario(self, obj) -> str:
        if obj.user.perfil_publico or self.get_can_edit(obj):
            return obj.user.nome_completo.strip() or obj.user.nome
        return "Colaborador AcessoJá"

    def get_user(self, obj) -> int | None:
        return obj.user_id if obj.user.perfil_publico or self.get_can_edit(obj) else None

    def validate_local(self, local):
        if self.instance and self.instance.local_id != local.pk:
            raise serializers.ValidationError("O local de uma avaliação não pode mudar.")
        return local

    def validate(self, attrs):
        protected = {
            "user",
            "points",
            "pontos",
            "verified_author",
            "is_valid",
            "is_current",
            "comment_verified",
            "survey_completed",
            "answer_dates",
            "content_revision",
            "publicly_eligible",
        }
        protected.update({"points_delta", "contribution_result", "data_resposta", "can_edit", "id", "local_detalhes"})
        if protected.intersection(self.initial_data):
            raise serializers.ValidationError("Autoria, moderação e pontos são controlados pelo servidor.")
        return validate_payload(self, attrs)

    def create(self, validated_data):
        validated_data.pop("expected_revision", None)
        validated_data.pop("operation_id", None)
        return super().create(prepare_write(None, validated_data))

    def update(self, instance, validated_data):
        validated_data.pop("operation_id", None)
        expected = validated_data.pop("expected_revision", None)
        if expected is not None and expected != instance.content_revision:
            from evidencias.exceptions import RevisionConflict

            raise RevisionConflict()
        return super().update(instance, prepare_write(instance, validated_data))
