from rest_framework import serializers
from .models import Usuario


class UsuarioPerfilSerializer(serializers.ModelSerializer):
    """Serializer for reading and updating user profile info."""
    class Meta:
        model = Usuario
        fields = [
            'id_usuario', 'nome', 'email', 'nome_completo', 'telefone',
            'foto_perfil', 'idioma', 'unidade_distancia',
            'permitir_sugestoes', 'impedir_autobloqueio',
            'perfil_publico', 'mostrar_avaliacoes',
            'compartilhar_localizacao', 'historico_visivel',
        ]
        read_only_fields = ['id_usuario']


class UsuarioSenhaSerializer(serializers.Serializer):
    """Serializer for changing password."""
    senha_atual = serializers.CharField(required=True)
    nova_senha = serializers.CharField(required=True, min_length=6)
