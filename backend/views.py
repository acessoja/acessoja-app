from django.contrib.auth import authenticate
from django.shortcuts import render
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny


class LoginAPIView(APIView):
    permission_classes = [AllowAny]  # Permite acesso público

    def post(self, request):
        # Captura os dados enviados pelo cliente
        nome = request.data.get('nome')
        password = request.data.get('password')
        print(f"DEBUG: Login attempt with nome='{nome}', password='{password}'")

        # Autentica o usuário
        user = authenticate(request, nome=nome, password=password)
        print(f"DEBUG: Authenticate result: {user}")

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
