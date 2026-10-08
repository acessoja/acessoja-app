from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiExample, OpenApiParameter, extend_schema, extend_schema_view
from rest_framework import viewsets
from rest_framework.permissions import AllowAny

from acessoja.api_schema import ErroSerializer
from .models import Local, VisitaRecente
from .serializers import LocalSerializer, VisitaRecenteSerializer


def _filtro(nome, descricao):
    """Monta um filtro booleano de acessibilidade (?campo=true)."""
    return OpenApiParameter(
        name=nome,
        type=OpenApiTypes.STR,
        location=OpenApiParameter.QUERY,
        required=False,
        description=f'{descricao} Só filtra com o valor exato `true`; qualquer outro valor é ignorado.',
        enum=['true'],
    )


FILTROS_ACESSIBILIDADE = [
    _filtro('cao_guia', 'Mantém apenas locais que aceitam cão-guia.'),
    _filtro('mesa_acessivel', 'Mantém apenas locais com mesa acessível.'),
    _filtro('banheiro_acessivel', 'Mantém apenas locais com banheiro adaptado.'),
    _filtro('rampa_acesso', 'Mantém apenas locais com rampa de acesso.'),
    _filtro('cardapio_braille', 'Mantém apenas locais com cardápio em braile.'),
]

EXEMPLO_LOCAL = OpenApiExample(
    'Local',
    response_only=True,
    value={
        'id_local': 1,
        'nome': 'Biblioteca Municipal',
        'endereco': 'Rua das Flores, 120 - Centro',
        'distancia': 1.4,
        'latitude': -23.5505,
        'longitude': -46.6333,
        'aberto': True,
        'imagem': 'biblioteca.png',
        'cao_guia': True,
        'mesa_acessivel': False,
        'banheiro_acessivel': True,
        'rampa_acesso': True,
        'cardapio_braille': False,
        'media_estrelas': 4.3,
        'data_criacao': '2026-09-02T14:30:00Z',
    },
)

EXEMPLO_LOCAL_ENVIO = OpenApiExample(
    'Requisição',
    request_only=True,
    value={
        'nome': 'Biblioteca Municipal',
        'endereco': 'Rua das Flores, 120 - Centro',
        'distancia': 1.4,
        'latitude': -23.5505,
        'longitude': -46.6333,
        'aberto': True,
        'rampa_acesso': True,
        'banheiro_acessivel': True,
    },
)

NAO_ENCONTRADO = OpenApiExample(
    'Não encontrado (404)',
    response_only=True,
    status_codes=['404'],
    value={'detail': 'Não encontrado.'},
)


@extend_schema_view(
    list=extend_schema(
        summary='Listar locais',
        description=(
            'Lista os locais cadastrados com `media_estrelas` já calculada a partir '
            'das avaliações.\n\n'
            'Os cinco filtros de acessibilidade são **cumulativos**: combiná-los '
            'devolve apenas os locais que atendem a todos.\n\n'
            'Exemplo: `/api/locais/?rampa_acesso=true&banheiro_acessivel=true`\n\n'
            'Rota **pública** (`AllowAny`).'
        ),
        parameters=FILTROS_ACESSIBILIDADE,
        responses={200: LocalSerializer(many=True)},
        examples=[EXEMPLO_LOCAL],
    ),
    retrieve=extend_schema(
        summary='Detalhar um local',
        description='Retorna um local pelo `id_local`. Rota **pública**.',
        responses={200: LocalSerializer, 404: ErroSerializer},
        examples=[EXEMPLO_LOCAL, NAO_ENCONTRADO],
    ),
    create=extend_schema(
        summary='Cadastrar local',
        description=(
            'Cria um local. `nome`, `endereco` e `distancia` são obrigatórios; as '
            'cinco flags de acessibilidade têm padrão `false`.\n\n'
            'O local **não** fica associado a nenhum usuário.\n\n'
            'Rota **pública** (`AllowAny`) — qualquer cliente pode cadastrar.'
        ),
        responses={201: LocalSerializer, 400: ErroSerializer},
        examples=[EXEMPLO_LOCAL_ENVIO, EXEMPLO_LOCAL],
    ),
    update=extend_schema(
        summary='Substituir local',
        description='Reescreve todos os campos do local. Rota **pública**.',
        responses={200: LocalSerializer, 400: ErroSerializer, 404: ErroSerializer},
        examples=[EXEMPLO_LOCAL_ENVIO, EXEMPLO_LOCAL, NAO_ENCONTRADO],
    ),
    partial_update=extend_schema(
        summary='Atualizar local parcialmente',
        description='Atualiza só os campos enviados — útil para alternar `aberto`.',
        responses={200: LocalSerializer, 400: ErroSerializer, 404: ErroSerializer},
        examples=[
            OpenApiExample('Requisição', request_only=True, value={'aberto': False}),
            EXEMPLO_LOCAL,
        ],
    ),
    destroy=extend_schema(
        summary='Remover local',
        description=(
            'Exclui o local e, em cascata, suas avaliações e visitas. '
            'Responde `204` sem corpo.'
        ),
        responses={204: None, 404: ErroSerializer},
        examples=[NAO_ENCONTRADO],
    ),
)
@extend_schema(tags=['Locais'])
class LocalViewSet(viewsets.ModelViewSet):
    queryset = Local.objects.all()
    serializer_class = LocalSerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        queryset = self.queryset

        # Filtros de acessibilidade
        cao_guia = self.request.query_params.get('cao_guia')
        mesa_acessivel = self.request.query_params.get('mesa_acessivel')
        banheiro_acessivel = self.request.query_params.get('banheiro_acessivel')
        rampa_acesso = self.request.query_params.get('rampa_acesso')
        cardapio_braille = self.request.query_params.get('cardapio_braille')

        if cao_guia == 'true':
            queryset = queryset.filter(cao_guia=True)
        if mesa_acessivel == 'true':
            queryset = queryset.filter(mesa_acessivel=True)
        if banheiro_acessivel == 'true':
            queryset = queryset.filter(banheiro_acessivel=True)
        if rampa_acesso == 'true':
            queryset = queryset.filter(rampa_acesso=True)
        if cardapio_braille == 'true':
            queryset = queryset.filter(cardapio_braille=True)

        return queryset

    def perform_create(self, serializer):
        # Salva o local sem associação ao usuário
        serializer.save()


PARAM_NOME_USUARIO = OpenApiParameter(
    name='nome_usuario',
    type=OpenApiTypes.STR,
    location=OpenApiParameter.QUERY,
    required=False,
    description='Filtra o histórico por usuário. Sem ele, devolve as visitas de todos.',
    examples=[OpenApiExample('leo', value='leo')],
)

EXEMPLO_VISITA = OpenApiExample(
    'Visita',
    response_only=True,
    value={
        'id': 7,
        'user': 1,
        'nome_usuario': 'leo',
        'local': 1,
        'local_detalhes': {'id_local': 1, 'nome': 'Biblioteca Municipal'},
        'data_visita': '2026-09-09T18:05:00Z',
    },
)


@extend_schema_view(
    list=extend_schema(
        summary='Listar visitas recentes',
        description=(
            'Histórico de locais visitados, do mais recente para o mais antigo. '
            'É o que alimenta a seção "Vistos recentemente" do app.\n\n'
            'Rota **pública**: sem `?nome_usuario=`, devolve o histórico de **todos** '
            'os usuários.'
        ),
        parameters=[PARAM_NOME_USUARIO],
        responses={200: VisitaRecenteSerializer(many=True)},
        examples=[EXEMPLO_VISITA],
    ),
    retrieve=extend_schema(
        summary='Detalhar uma visita',
        responses={200: VisitaRecenteSerializer, 404: ErroSerializer},
        examples=[EXEMPLO_VISITA, NAO_ENCONTRADO],
    ),
    create=extend_schema(
        summary='Registrar visita',
        description=(
            'Registra que um usuário abriu um local.\n\n'
            '**Como a autoria é resolvida:** o campo `user` do corpo é ignorado. '
            'A view procura o usuário pelo `nome_usuario` enviado no corpo; se não '
            'encontrar (ou se o campo vier vazio), atribui a visita ao **primeiro '
            'usuário do banco**. Envie sempre `nome_usuario`.'
        ),
        responses={201: VisitaRecenteSerializer, 400: ErroSerializer},
        examples=[
            OpenApiExample(
                'Requisição',
                request_only=True,
                value={'local': 1, 'nome_usuario': 'leo'},
            ),
            EXEMPLO_VISITA,
        ],
    ),
    update=extend_schema(
        summary='Substituir visita',
        responses={200: VisitaRecenteSerializer, 400: ErroSerializer, 404: ErroSerializer},
    ),
    partial_update=extend_schema(
        summary='Atualizar visita parcialmente',
        responses={200: VisitaRecenteSerializer, 400: ErroSerializer, 404: ErroSerializer},
    ),
    destroy=extend_schema(
        summary='Remover visita do histórico',
        description='Responde `204` sem corpo.',
        responses={204: None, 404: ErroSerializer},
        examples=[NAO_ENCONTRADO],
    ),
)
@extend_schema(tags=['Visitas'])
class VisitaRecenteViewSet(viewsets.ModelViewSet):
    queryset = VisitaRecente.objects.all()
    serializer_class = VisitaRecenteSerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        nome_usuario = self.request.query_params.get('nome_usuario')
        if nome_usuario:
            return self.queryset.filter(user__nome=nome_usuario)
        return self.queryset.all()

    def perform_create(self, serializer):
        nome_usuario = self.request.data.get('nome_usuario')
        from django.contrib.auth import get_user_model
        User = get_user_model()
        user = None
        if nome_usuario:
            user = User.objects.filter(nome=nome_usuario).first()
        if not user:
            user = User.objects.first()
        serializer.save(user=user)
