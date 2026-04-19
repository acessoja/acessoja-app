from rest_framework import serializers
from .models import Local, AvaliacaoLocal


class AvaliacaoLocalSerializer(serializers.ModelSerializer):
    class Meta:
        model = AvaliacaoLocal
        fields = ['id', 'local', 'user',
                  'comentario', 'estrelas', 'data_criacao']
        read_only_fields = ['id', 'user', 'data_criacao']


class LocalSerializer(serializers.ModelSerializer):
    media_estrelas = serializers.FloatField(
        source='media_estrelas', read_only=True)

    class Meta:
        model = Local
        fields = ['id', 'nome', 'endereco',
                  'distancia', 'aberto', 'media_estrelas']
