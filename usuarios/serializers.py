from rest_framework import serializers
from .models import Usuario
from .account_serializers import guard_email_change, normalized_email


class UsuarioPerfilSerializer(serializers.ModelSerializer):
    """Serializer for reading and updating user profile info."""

    current_password = serializers.CharField(
        write_only=True, required=False, trim_whitespace=False, max_length=4096
    )

    def validate_email(self, value):
        return normalized_email(value, self.instance)

    def validate(self, attrs):
        if (
            "foto_perfil" in self.initial_data
            or "avatar_asset" in self.initial_data
            or "avatar_version" in self.initial_data
        ):
            raise serializers.ValidationError("Use o endpoint dedicado de avatar.")
        if set(self.initial_data) & {
            "accessibility_preferences",
            "save_route_history",
            "save_route_origin",
            "route_history_revision",
        }:
            raise serializers.ValidationError("Use o endpoint privado de preferências do usuário atual.")
        return guard_email_change(self.instance, attrs)

    class Meta:
        model = Usuario
        fields = [
            "id_usuario",
            "nome",
            "email",
            "nome_completo",
            "telefone",
            "foto_perfil",
            "avatar_version",
            "idioma",
            "unidade_distancia",
            "permitir_sugestoes",
            "impedir_autobloqueio",
            "perfil_publico",
            "mostrar_avaliacoes",
            "compartilhar_localizacao",
            "historico_visivel",
            "current_password",
        ]
        read_only_fields = ["id_usuario", "nome", "foto_perfil", "avatar_version"]


class UsuarioSenhaSerializer(serializers.Serializer):
    """Serializer for changing password."""

    senha_atual = serializers.CharField(required=True, trim_whitespace=False, max_length=4096)
    nova_senha = serializers.CharField(required=True, trim_whitespace=False, max_length=4096)
