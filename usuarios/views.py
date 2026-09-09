from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiExample, OpenApiParameter, extend_schema
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny

from acessoja.api_schema import (
    ErroSerializer,
    FotoPerfilRequestSerializer,
    MensagemSerializer,
    TrocaSenhaRequestSerializer,
)
from .models import Usuario
from .serializers import UsuarioPerfilSerializer, UsuarioSenhaSerializer

PARAM_NOME = OpenApiParameter(
    name='nome',
    type=OpenApiTypes.STR,
    location=OpenApiParameter.QUERY,
    required=True,
    description='Nome de usuário (campo de login) do perfil a ler ou atualizar.',
    examples=[OpenApiExample('leo', value='leo')],
)

ERRO_SEM_NOME = OpenApiExample(
    'Sem o parâmetro nome (400)',
    response_only=True,
    status_codes=['400'],
    value={'error': 'Parâmetro "nome" é obrigatório.'},
)

ERRO_NAO_ENCONTRADO = OpenApiExample(
    'Usuário inexistente (404)',
    response_only=True,
    status_codes=['404'],
    value={'error': 'Usuário não encontrado.'},
)


@extend_schema(tags=['Usuários'])
@extend_schema(
    methods=['GET'],
    summary='Ler perfil',
    description=(
        'Devolve o perfil completo do usuário identificado pelo parâmetro `?nome=`, '
        'incluindo preferências do app (idioma, unidade de distância, privacidade).\n\n'
        'Rota **pública**: não exige autenticação.'
    ),
    parameters=[PARAM_NOME],
    responses={200: UsuarioPerfilSerializer, 400: ErroSerializer, 404: ErroSerializer},
    examples=[ERRO_SEM_NOME, ERRO_NAO_ENCONTRADO],
)
@extend_schema(
    methods=['PUT'],
    summary='Atualizar perfil',
    description=(
        'Atualização **parcial**: envie só os campos que mudaram. O usuário é '
        'identificado por `?nome=`, não pelo corpo.\n\n'
        'Rota **pública**: não exige autenticação.'
    ),
    parameters=[PARAM_NOME],
    request=UsuarioPerfilSerializer,
    responses={200: UsuarioPerfilSerializer, 400: ErroSerializer, 404: ErroSerializer},
    examples=[
        OpenApiExample(
            'Requisição',
            request_only=True,
            value={'nome_completo': 'Leonardo Rabelo', 'telefone': '(31) 90000-0000'},
        ),
        ERRO_SEM_NOME,
        ERRO_NAO_ENCONTRADO,
    ],
)
class UsuarioPerfilAPIView(APIView):
    """GET / PUT profile by username (query param ?nome=...)."""
    permission_classes = [AllowAny]
    serializer_class = UsuarioPerfilSerializer

    def get(self, request):
        nome = request.query_params.get('nome')
        if not nome:
            return Response({'error': 'Parâmetro "nome" é obrigatório.'}, status=400)
        try:
            user = Usuario.objects.get(nome=nome)
        except Usuario.DoesNotExist:
            return Response({'error': 'Usuário não encontrado.'}, status=404)
        serializer = UsuarioPerfilSerializer(user)
        return Response(serializer.data)

    def put(self, request):
        nome = request.query_params.get('nome')
        if not nome:
            return Response({'error': 'Parâmetro "nome" é obrigatório.'}, status=400)
        try:
            user = Usuario.objects.get(nome=nome)
        except Usuario.DoesNotExist:
            return Response({'error': 'Usuário não encontrado.'}, status=404)
        serializer = UsuarioPerfilSerializer(user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=400)


@extend_schema(
    tags=['Usuários'],
    summary='Alterar senha',
    description=(
        'Troca a senha do usuário informado em `nome`, conferindo antes a senha atual.\n\n'
        '**Códigos**\n'
        '- `400` — falta o campo `nome`, ou a nova senha tem menos de 6 caracteres\n'
        '- `403` — a senha atual não confere\n'
        '- `404` — usuário inexistente\n\n'
        'Rota **pública**: não exige autenticação.'
    ),
    request=TrocaSenhaRequestSerializer,
    responses={
        200: MensagemSerializer,
        400: ErroSerializer,
        403: ErroSerializer,
        404: ErroSerializer,
    },
    examples=[
        OpenApiExample(
            'Requisição',
            request_only=True,
            value={'nome': 'leo', 'senha_atual': 'segredo123', 'nova_senha': 'novaSenha456'},
        ),
        OpenApiExample(
            'Senha alterada (200)',
            response_only=True,
            status_codes=['200'],
            value={'status': 'success', 'message': 'Senha alterada com sucesso.'},
        ),
        OpenApiExample(
            'Senha atual incorreta (403)',
            response_only=True,
            status_codes=['403'],
            value={'error': 'Senha atual incorreta.'},
        ),
        ERRO_NAO_ENCONTRADO,
    ],
)
class UsuarioSenhaAPIView(APIView):
    """POST to change password. Body: {nome, senha_atual, nova_senha}."""
    permission_classes = [AllowAny]
    serializer_class = TrocaSenhaRequestSerializer

    def post(self, request):
        nome = request.data.get('nome')
        if not nome:
            return Response({'error': 'Campo "nome" é obrigatório.'}, status=400)
        try:
            user = Usuario.objects.get(nome=nome)
        except Usuario.DoesNotExist:
            return Response({'error': 'Usuário não encontrado.'}, status=404)

        serializer = UsuarioSenhaSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=400)

        if not user.check_password(serializer.validated_data['senha_atual']):
            return Response({'error': 'Senha atual incorreta.'}, status=403)

        user.set_password(serializer.validated_data['nova_senha'])
        user.save()
        return Response({'status': 'success', 'message': 'Senha alterada com sucesso.'})


@extend_schema(
    tags=['Usuários'],
    summary='Enviar foto de perfil',
    description=(
        'Grava a foto de perfil do usuário. A imagem vai como **string base64** no '
        'corpo da requisição — não é upload multipart.\n\n'
        'Rota **pública**: não exige autenticação.'
    ),
    request=FotoPerfilRequestSerializer,
    responses={200: MensagemSerializer, 400: ErroSerializer, 404: ErroSerializer},
    examples=[
        OpenApiExample(
            'Requisição',
            request_only=True,
            value={'nome': 'leo', 'foto_perfil': 'data:image/png;base64,iVBORw0KGgoAAA...'},
        ),
        OpenApiExample(
            'Foto atualizada (200)',
            response_only=True,
            status_codes=['200'],
            value={'status': 'success', 'message': 'Foto atualizada com sucesso.'},
        ),
        OpenApiExample(
            'Campos faltando (400)',
            response_only=True,
            status_codes=['400'],
            value={'error': 'Campos "nome" e "foto_perfil" são obrigatórios.'},
        ),
        ERRO_NAO_ENCONTRADO,
    ],
)
class UsuarioFotoAPIView(APIView):
    """POST to upload profile photo as base64. Body: {nome, foto_perfil}."""
    permission_classes = [AllowAny]
    serializer_class = FotoPerfilRequestSerializer

    def post(self, request):
        nome = request.data.get('nome')
        foto = request.data.get('foto_perfil')
        if not nome or not foto:
            return Response({'error': 'Campos "nome" e "foto_perfil" são obrigatórios.'}, status=400)
        try:
            user = Usuario.objects.get(nome=nome)
        except Usuario.DoesNotExist:
            return Response({'error': 'Usuário não encontrado.'}, status=404)
        user.foto_perfil = foto
        user.save(update_fields=['foto_perfil'])
        return Response({'status': 'success', 'message': 'Foto atualizada com sucesso.'})
