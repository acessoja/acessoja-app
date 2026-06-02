from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from .models import Usuario
from .serializers import UsuarioPerfilSerializer, UsuarioSenhaSerializer


class UsuarioPerfilAPIView(APIView):
    """GET / PUT profile by username (query param ?nome=...)."""
    permission_classes = [AllowAny]

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


class UsuarioSenhaAPIView(APIView):
    """POST to change password. Body: {nome, senha_atual, nova_senha}."""
    permission_classes = [AllowAny]

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


class UsuarioFotoAPIView(APIView):
    """POST to upload profile photo as base64. Body: {nome, foto_perfil}."""
    permission_classes = [AllowAny]

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
