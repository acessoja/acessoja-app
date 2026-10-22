from django.shortcuts import render
from drf_spectacular.utils import OpenApiExample, extend_schema
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny

from .api_schema import ErroMessageSerializer, LoginRequestSerializer, LoginSucessoSerializer


from usuarios.account_services import login_token
from usuarios.security_throttles import SecurityThrottle


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
    authentication_classes = []
    throttle_classes = [SecurityThrottle]
    security_scope = "login"

    def post(self, request):
        serializer = LoginRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        nome = serializer.validated_data["nome"]
        password = serializer.validated_data["password"]

        result = login_token(nome, password)
        if result is not None:
            user, token = result
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
