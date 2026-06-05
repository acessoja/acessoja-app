from rest_framework import serializers
from .models import Local, VisitaRecente


class LocalSerializer(serializers.ModelSerializer):
    media_estrelas = serializers.ReadOnlyField()

    class Meta:
        model = Local
        fields = [
            'id_local', 'nome', 'endereco', 'distancia', 'latitude', 'longitude',
            'aberto', 'imagem', 'cao_guia', 'mesa_acessivel', 'banheiro_acessivel',
            'rampa_acesso', 'cardapio_braille', 'media_estrelas', 'data_criacao'
        ]


class VisitaRecenteSerializer(serializers.ModelSerializer):
    local_detalhes = LocalSerializer(source='local', read_only=True)
    nome_usuario = serializers.ReadOnlyField(source='user.nome')

    class Meta:
        model = VisitaRecente
        fields = ['id', 'user', 'nome_usuario', 'local', 'local_detalhes', 'data_visita']
        read_only_fields = ['id', 'user', 'data_visita']
