from rest_framework import serializers
from locais.serializers import LocalSerializer
from .models import ModalAvaliacao


class ModalAvaliacaoSerializer(serializers.ModelSerializer):
    nome_usuario = serializers.SerializerMethodField()
    local_detalhes = LocalSerializer(source="local", read_only=True)
    can_edit = serializers.SerializerMethodField()
    user = serializers.SerializerMethodField()
    points_delta = serializers.IntegerField(read_only=True, required=False)

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
            "survey_completed",
        ]
        read_only_fields = ["id", "user", "data_resposta", "can_edit", "survey_completed"]
        extra_kwargs = {
            "estrelas": {"min_value": 1, "max_value": 5},
            "comentario": {"max_length": 3000},
            **{f"pergunta_{i}": {"required": False} for i in range(1, 5)},
        }
        validators = []

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
        }
        if protected.intersection(self.initial_data):
            raise serializers.ValidationError("Autoria, moderação e pontos são controlados pelo servidor.")
        supplied = [f"pergunta_{i}" in attrs for i in range(1, 5)]
        if not self.instance and any(supplied) and not all(supplied):
            raise serializers.ValidationError("Responda todas as perguntas ou envie apenas estrelas e comentário.")
        return attrs
