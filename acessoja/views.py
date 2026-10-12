from django.contrib.auth import authenticate
from datetime import timedelta
from django.conf import settings
from django.utils import timezone
from rest_framework.authtoken.models import Token
from django.shortcuts import render
from drf_spectacular.utils import OpenApiExample, extend_schema
from rest_framework.views import APIView
from rest_framework.throttling import AnonRateThrottle
from rest_framework.response import Response
from rest_framework.permissions import AllowAny

from .api_schema import ErroMessageSerializer, LoginRequestSerializer, LoginSucessoSerializer


class LoginThrottle(AnonRateThrottle):
    rate = "10/min"


@extend_schema(
    tags=["Autenticação"],
    summary="Fazer login",
    description=(
        "Valida as credenciais pelo campo `nome` (não pelo e-mail) e devolve o "
        "perfil do usuário para o app guardar em memória.\n\n"
        "Devolve token de sessão com expiração; use Authorization: Token <token>. "
        "A autoria das avaliações vem da sessão autenticada."
    ),
    request=LoginRequestSerializer,
    responses={200: LoginSucessoSerializer, 401: ErroMessageSerializer},
    examples=[
        OpenApiExample(
            "Requisição",
            request_only=True,
            value={"nome": "leo", "password": "segredo123"},
        ),
        OpenApiExample(
            "Login aceito (200)",
            response_only=True,
            status_codes=["200"],
            value={
                "status": "success",
                "token": "<token da sessão>",
                "message": "Bem-vindo, leo!",
                "user": {
                    "id_usuario": 1,
                    "nome": "leo",
                    "email": "leo@example.com",
                    "nome_completo": "Leonardo Rabelo",
                    "telefone": "(31) 90000-0000",
                    "foto_perfil": None,
                },
            },
        ),
        OpenApiExample(
            "Credenciais inválidas (401)",
            response_only=True,
            status_codes=["401"],
            value={"status": "error", "message": "Nome de usuário ou senha incorretos."},
        ),
    ],
)
class LoginAPIView(APIView):
    permission_classes = [AllowAny]  # Permite acesso público
    serializer_class = LoginRequestSerializer
    throttle_classes = [LoginThrottle]

    def post(self, request):
        serializer = LoginRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        nome = serializer.validated_data["nome"]
        password = serializer.validated_data["password"]

        # Autentica o usuário
        user = authenticate(request, nome=nome, password=password)

        if user is not None:
            token, _ = Token.objects.get_or_create(user=user)
            if token.created + timedelta(seconds=settings.AUTH_TOKEN_TTL) <= timezone.now():
                token.delete()
                token = Token.objects.create(user=user)
            # Login bem-sucedido
            return Response(
                {
                    "status": "success",
                    "token": token.key,
                    "message": f"Bem-vindo, {user.nome}!",
                    "user": {
                        "id_usuario": user.id_usuario,
                        "nome": user.nome,
                        "email": user.email,
                        "nome_completo": user.nome_completo,
                        "telefone": user.telefone,
                        "foto_perfil": user.foto_perfil,
                    },
                }
            )
        else:
            # Falha na autenticação
            return Response({"status": "error", "message": "Nome de usuário ou senha incorretos."}, status=401)


def home(request):
    return render(request, "home.html")  # Página simples para redirecionamento
