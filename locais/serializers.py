from rest_framework import serializers
from .models import Local, VisitaRecente


class LocalSerializer(serializers.ModelSerializer):
    media_estrelas = serializers.FloatField(
        read_only=True,
        help_text='Media das estrelas das avaliacoes do local, de 0 a 5 (calculada).',
    )

    class Meta:
        model = Local
        fields = [
            'id_local', 'nome', 'endereco', 'distancia', 'latitude', 'longitude',
            'aberto', 'imagem', 'cao_guia', 'mesa_acessivel', 'banheiro_acessivel',
            'rampa_acesso', 'cardapio_braille', 'media_estrelas', 'data_criacao'
        ]
        extra_kwargs = {
            'id_local': {'help_text': 'Identificador unico do local.'},
            'nome': {'help_text': 'Nome do estabelecimento ou local publico.'},
            'endereco': {'help_text': 'Endereco completo em texto livre.'},
            'distancia': {'help_text': 'Distancia em km ate o usuario.'},
            'latitude': {'help_text': 'Latitude em graus decimais. Opcional.'},
            'longitude': {'help_text': 'Longitude em graus decimais. Opcional.'},
            'aberto': {'help_text': 'Indica se o local esta em funcionamento.'},
            'imagem': {'help_text': 'URL ou nome do arquivo de imagem do local.'},
            'cao_guia': {'help_text': 'Aceita cao-guia.'},
            'mesa_acessivel': {'help_text': 'Tem mesa acessivel para cadeirante.'},
            'banheiro_acessivel': {'help_text': 'Tem banheiro adaptado.'},
            'rampa_acesso': {'help_text': 'Tem rampa de acesso na entrada.'},
            'cardapio_braille': {'help_text': 'Tem cardapio em braile.'},
            'data_criacao': {'help_text': 'Data de cadastro do local (ISO-8601).'},
        }


class VisitaRecenteSerializer(serializers.ModelSerializer):
    local_detalhes = LocalSerializer(
        source='local', read_only=True, help_text='Dados completos do local visitado.'
    )
    nome_usuario = serializers.CharField(
        source='user.nome', read_only=True, help_text='Nome do usuario que visitou.'
    )

    class Meta:
        model = VisitaRecente
        fields = ['id', 'user', 'nome_usuario', 'local', 'local_detalhes', 'data_visita']
        read_only_fields = ['id', 'user', 'data_visita']
