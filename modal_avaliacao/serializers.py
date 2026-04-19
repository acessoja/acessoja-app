from rest_framework import serializers
from .models import ModalAvaliacao
from locais.models import Local


class LocalSerializer(serializers.ModelSerializer):
    media_estrelas = serializers.FloatField(
        source='media_estrelas', read_only=True)

    class Meta:
        model = Local
        fields = ['id', 'nome', 'endereco',
                  'distancia', 'aberto', 'media_estrelas']


class ModalAvaliacaoSerializer(serializers.ModelSerializer):
    class Meta:
        model = ModalAvaliacao
        fields = [
            'id', 'local', 'user', 'pergunta_1', 'pergunta_2',
            'pergunta_3', 'pergunta_4', 'estrelas', 'data_resposta'
        ]
        read_only_fields = ['id', 'user', 'data_resposta']
