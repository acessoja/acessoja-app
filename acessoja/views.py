from django.contrib.auth import authenticate
from django.shortcuts import render
from drf_spectacular.utils import OpenApiExample, extend_schema
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny

from .api_schema import ErroMessageSerializer, LoginRequestSerializer, LoginSucessoSerializer


@extend_schema(
    tags=['Autenticação'],
    summary='Fazer login',
    description=(
        'Valida as credenciais pelo campo `nome` (não pelo e-mail) e devolve o '
        'perfil do usuário para o app guardar em memória.\n\n'
        '**Não devolve token.** As rotas de escrita hoje aceitam qualquer chamada '
        '(`AllowAny`) e identificam a autoria por `nome`/`nome_usuario` no corpo. '
        'Trocar isso por token é o cartão de segurança da sprint.'
    ),
    request=LoginRequestSerializer,
    responses={200: LoginSucessoSerializer, 401: ErroMessageSerializer},
    examples=[
        OpenApiExample(
            'Requisição',
            request_only=True,
            value={'nome': 'leo', 'password': 'segredo123'},
        ),
        OpenApiExample(
            'Login aceito (200)',
            response_only=True,
            status_codes=['200'],
            value={
                'status': 'success',
                'message': 'Bem-vindo, leo!',
                'user': {
                    'id_usuario': 1,
                    'nome': 'leo',
                    'email': 'leo@example.com',
                    'nome_completo': 'Leonardo Rabelo',
                    'telefone': '(31) 90000-0000',
                    'foto_perfil': None,
                },
            },
        ),
        OpenApiExample(
            'Credenciais inválidas (401)',
            response_only=True,
            status_codes=['401'],
            value={'status': 'error', 'message': 'Nome de usuário ou senha incorretos.'},
        ),
    ],
)
class LoginAPIView(APIView):
    permission_classes = [AllowAny]  # Permite acesso público
    serializer_class = LoginRequestSerializer

    def post(self, request):
        # Captura os dados enviados pelo cliente
        nome = request.data.get('nome')
        password = request.data.get('password')

        # Autentica o usuário
        user = authenticate(request, nome=nome, password=password)

        if user is not None:
            # Login bem-sucedido
            return Response({
                'status': 'success',
                'message': f'Bem-vindo, {user.nome}!',
                'user': {
                    'id_usuario': user.id_usuario,
                    'nome': user.nome,
                    'email': user.email,
                    'nome_completo': user.nome_completo,
                    'telefone': user.telefone,
                    'foto_perfil': user.foto_perfil,
                }
            })
        else:
            # Falha na autenticação
            return Response({
                'status': 'error',
                'message': 'Nome de usuário ou senha incorretos.'
            }, status=401)


def home(request):
    return render(request, 'home.html')  # Página simples para redirecionamento
