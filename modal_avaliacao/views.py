from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiExample, OpenApiParameter, extend_schema, extend_schema_view
from rest_framework import viewsets
from rest_framework.permissions import AllowAny

from acessoja.api_schema import ErroSerializer
from .models import ModalAvaliacao
from .serializers import LocalSerializer, ModalAvaliacaoSerializer
from locais.models import Local


class LocalViewSet(viewsets.ModelViewSet):
    queryset = Local.objects.all()
    serializer_class = LocalSerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        return self.queryset


PARAM_LOCAL = OpenApiParameter(
    name='local_id',
    type=OpenApiTypes.INT,
    location=OpenApiParameter.QUERY,
    required=False,
    description='Filtra as avaliações de um único local, pelo `id_local`.',
    examples=[OpenApiExample('Local 1', value=1)],
)

EXEMPLO_ENVIO = OpenApiExample(
    'Requisição',
    request_only=True,
    value={
        'local': 1,
        'nome_usuario': 'leo',
        'pergunta_1': 'Sim',
        'pergunta_2': 'Não',
        'pergunta_3': 'Sim',
        'pergunta_4': 'Não sei',
        'estrelas': 4,
        'comentario': 'Rampa na entrada, mas o banheiro não é adaptado.',
    },
)

EXEMPLO_RESPOSTA = OpenApiExample(
    'Avaliação',
    response_only=True,
    value={
        'id': 12,
        'local': 1,
        'user': 3,
        'nome_usuario': 'Leonardo Rabelo',
        'pergunta_1': 'Sim',
        'pergunta_2': 'Não',
        'pergunta_3': 'Sim',
        'pergunta_4': 'Não sei',
        'estrelas': 4,
        'comentario': 'Rampa na entrada, mas o banheiro não é adaptado.',
        'data_resposta': '2026-09-09T18:20:00Z',
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
        summary='Listar avaliações',
        description=(
            'Lista as avaliações de acessibilidade. Use `?local_id=` para trazer '
            'apenas as de um local — é o que a tela de detalhe do app consome.\n\n'
            'Rota **pública**.'
        ),
        parameters=[PARAM_LOCAL],
        responses={200: ModalAvaliacaoSerializer(many=True)},
        examples=[EXEMPLO_RESPOSTA],
    ),
    retrieve=extend_schema(
        summary='Detalhar uma avaliação',
        responses={200: ModalAvaliacaoSerializer, 404: ErroSerializer},
        examples=[EXEMPLO_RESPOSTA, NAO_ENCONTRADO],
    ),
    create=extend_schema(
        summary='Enviar avaliação',
        description=(
            'Registra a avaliação de acessibilidade de um local.\n\n'
            '**Efeito colateral importante:** cada resposta `Sim` liga a flag '
            'correspondente no próprio local, e a mudança vale para todo mundo:\n\n'
            '| Pergunta | Flag ligada em `Local` |\n'
            '|---|---|\n'
            '| `pergunta_1` = Sim | `rampa_acesso` |\n'
            '| `pergunta_2` = Sim | `banheiro_acessivel` |\n'
            '| `pergunta_3` = Sim | `mesa_acessivel` |\n'
            '| `pergunta_4` = Sim | `cao_guia` |\n\n'
            'Uma flag ligada **nunca é desligada** por uma avaliação posterior.\n\n'
            '**Autoria:** o campo `user` do corpo é ignorado. A view usa o '
            '`nome_usuario` enviado no corpo; se não encontrar, cai no primeiro '
            'usuário do banco. Envie sempre `nome_usuario`.\n\n'
            'As quatro perguntas aceitam apenas `Sim`, `Não` ou `Não sei`; '
            '`estrelas` vai de 0 a 5. Rota **pública**.'
        ),
        responses={201: ModalAvaliacaoSerializer, 400: ErroSerializer},
        examples=[EXEMPLO_ENVIO, EXEMPLO_RESPOSTA],
    ),
    update=extend_schema(
        summary='Substituir avaliação',
        description='Reescreve a avaliação inteira. Não reavalia as flags do local.',
        responses={200: ModalAvaliacaoSerializer, 400: ErroSerializer, 404: ErroSerializer},
        examples=[EXEMPLO_ENVIO, EXEMPLO_RESPOSTA, NAO_ENCONTRADO],
    ),
    partial_update=extend_schema(
        summary='Atualizar avaliação parcialmente',
        description='Atualiza só os campos enviados. Não reavalia as flags do local.',
        responses={200: ModalAvaliacaoSerializer, 400: ErroSerializer, 404: ErroSerializer},
        examples=[
            OpenApiExample(
                'Requisição',
                request_only=True,
                value={'estrelas': 5, 'comentario': 'Instalaram banheiro adaptado.'},
            ),
            EXEMPLO_RESPOSTA,
        ],
    ),
    destroy=extend_schema(
        summary='Remover avaliação',
        description=(
            'Exclui a avaliação. As flags que ela ligou no local **continuam ligadas**. '
            'Responde `204` sem corpo.'
        ),
        responses={204: None, 404: ErroSerializer},
        examples=[NAO_ENCONTRADO],
    ),
)
@extend_schema(tags=['Avaliações'])
class ModalAvaliacaoViewSet(viewsets.ModelViewSet):
    queryset = ModalAvaliacao.objects.all()
    serializer_class = ModalAvaliacaoSerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        local_id = self.request.query_params.get('local_id')
        if local_id:
            return self.queryset.filter(local_id=local_id)
        return self.queryset.all()

    def perform_create(self, serializer):
        user = self.request.user
        nome_usuario = self.request.data.get('nome_usuario')
        if nome_usuario:
            from django.contrib.auth import get_user_model
            User = get_user_model()
            found_user = User.objects.filter(nome=nome_usuario).first()
            if found_user:
                user = found_user

        if user.is_anonymous:
            from django.contrib.auth import get_user_model
            User = get_user_model()
            user = User.objects.first()

        evaluation = serializer.save(user=user)

        # Update local accessibility flags based on the survey responses
        local = evaluation.local
        if evaluation.pergunta_1 == 'Sim':
            local.rampa_acesso = True
        if evaluation.pergunta_2 == 'Sim':
            local.banheiro_acessivel = True
        if evaluation.pergunta_3 == 'Sim':
            # Map question 3 (vagas de estacionamento) or 4 (mesa acessivel)
            local.mesa_acessivel = True
        if evaluation.pergunta_4 == 'Sim':
            local.cao_guia = True

        local.save()
