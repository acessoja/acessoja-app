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
    nome_usuario = serializers.SerializerMethodField()

    class Meta:
        model = ModalAvaliacao
        fields = [
            'id', 'local', 'user', 'nome_usuario', 'pergunta_1', 'pergunta_2',
            'pergunta_3', 'pergunta_4', 'estrelas', 'comentario', 'data_resposta'
        ]
        read_only_fields = ['id', 'user', 'data_resposta']
        extra_kwargs = {
            'local': {'help_text': 'ID do local avaliado (`id_local`).'},
            'pergunta_1': {'help_text': 'Tem rampa de acesso? Sim | Nao | Nao sei'},
            'pergunta_2': {'help_text': 'Tem banheiro adaptado? Sim | Nao | Nao sei'},
            'pergunta_3': {'help_text': 'Tem mesa acessivel? Sim | Nao | Nao sei'},
            'pergunta_4': {'help_text': 'Aceita cao-guia? Sim | Nao | Nao sei'},
            'estrelas': {'help_text': 'Nota geral de acessibilidade, de 0 a 5.'},
            'comentario': {'help_text': 'Observacao livre sobre o local. Opcional.'},
            'data_resposta': {'help_text': 'Momento do envio da avaliacao (ISO-8601).'},
        }

    def get_nome_usuario(self, obj) -> str:
        if obj.user.nome_completo and obj.user.nome_completo.strip():
            return obj.user.nome_completo
        return obj.user.nome
