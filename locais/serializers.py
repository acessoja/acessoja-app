from rest_framework import serializers
from .models import Local, VisitaRecente


class RecursoSerializer(serializers.Serializer):
    estado = serializers.ChoiceField(choices=['disponivel', 'indisponivel', 'nao_informado', 'nao_se_aplica'])
    observacao = serializers.CharField(required=False, allow_blank=True, max_length=1000)
    fonte = serializers.CharField(required=False, allow_blank=True, max_length=255)
    atualizado_em = serializers.DateField(required=False, allow_null=True)


RECURSOS = ('entrada_sem_degraus', 'rampa_acesso', 'elevador', 'banheiro_acessivel',
            'vaga_reservada', 'circulacao', 'mesa_acessivel', 'cardapio_braille',
            'sinalizacao_tatil', 'atendimento_acessivel', 'cao_guia')


class AreaVisitaSerializer(serializers.Serializer):
    nome = serializers.CharField(max_length=255)
    descricao = serializers.CharField(required=False, allow_blank=True, max_length=3000)
    entrada = serializers.CharField(required=False, allow_blank=True, max_length=2000)
    foto = serializers.URLField(required=False, allow_blank=True)
    fonte = serializers.CharField(required=False, allow_blank=True, max_length=255)
    atualizado_em = serializers.DateField(required=False, allow_null=True)
    recursos = serializers.DictField(child=RecursoSerializer(), required=False)

    def validate_recursos(self, value):
        if set(value) - set(RECURSOS):
            raise serializers.ValidationError('Recurso de acessibilidade desconhecido.')
        return value


class GuiaVisitaSerializer(AreaVisitaSerializer):
    categoria = serializers.ChoiceField(
        choices=[
            'educacao', 'alimentacao', 'saude', 'comercio',
            'servico', 'lazer', 'outro',
        ],
        required=False,
    )
    nome = serializers.CharField(required=False, max_length=255)
    horarios = serializers.CharField(required=False, allow_blank=True, max_length=2000)
    telefone = serializers.CharField(required=False, allow_blank=True, max_length=40)
    site = serializers.URLField(required=False, allow_blank=True)
    areas = AreaVisitaSerializer(many=True, required=False)


class LocalSerializer(serializers.ModelSerializer):
    guia_visita = GuiaVisitaSerializer(required=False)

    def validate_latitude(self, value):
        if value is not None and not -90 <= value <= 90:
            raise serializers.ValidationError('Latitude inválida.')
        return value

    def validate_longitude(self, value):
        if value is not None and not -180 <= value <= 180:
            raise serializers.ValidationError('Longitude inválida.')
        return value

    def validate(self, attrs):
        if not self.instance:
            nome = attrs.get('nome', '').strip()
            endereco = attrs.get('endereco', '').strip()
            if Local.objects.filter(nome__iexact=nome, endereco__iexact=endereco).exists():
                raise serializers.ValidationError({'nome': 'Este local já está cadastrado neste endereço.'})
        # Keep the existing search filters consistent with explicitly supplied facts.
        resources = attrs.get('guia_visita', {}).get('recursos', {})
        for key in ('rampa_acesso', 'banheiro_acessivel', 'mesa_acessivel',
                    'cardapio_braille', 'cao_guia'):
            if key in resources:
                attrs[key] = resources[key]['estado'] == 'disponivel'
        return attrs

    def validate_guia_visita(self, value):
        # Convert validated dates to JSON-compatible ISO strings before storing.
        import json
        from django.core.serializers.json import DjangoJSONEncoder
        return json.loads(json.dumps(value, cls=DjangoJSONEncoder))

    media_estrelas = serializers.FloatField(
        read_only=True,
        help_text='Media das estrelas das avaliacoes do local, de 0 a 5 (calculada).',
    )

    class Meta:
        model = Local
        fields = [
            'id_local', 'nome', 'endereco', 'distancia', 'latitude', 'longitude',
            'aberto', 'guia_visita', 'imagem', 'cao_guia', 'mesa_acessivel', 'banheiro_acessivel',
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
