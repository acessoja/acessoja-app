from django.shortcuts import get_object_or_404
from drf_spectacular.utils import extend_schema
from rest_framework.authtoken.models import Token
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from acessoja.api_schema import FotoPerfilRequestSerializer, MensagemSerializer, TrocaSenhaRequestSerializer
from .models import Usuario
from .serializers import UsuarioPerfilSerializer, UsuarioSenhaSerializer


def own_user(request, name):
    if not name:
        raise ValidationError({"error": "Informe o nome do usuário."})
    user = get_object_or_404(Usuario, nome=name)
    if user.pk != request.user.pk:
        raise PermissionDenied("Acesso restrito ao próprio perfil.")
    return user


class UsuarioPerfilAPIView(APIView):
    permission_classes = [IsAuthenticated]
    serializer_class = UsuarioPerfilSerializer

    @extend_schema(tags=["Usuários"], responses=UsuarioPerfilSerializer)
    def get(self, request):
        return Response(UsuarioPerfilSerializer(own_user(request, request.query_params.get("nome"))).data)

    @extend_schema(tags=["Usuários"], request=UsuarioPerfilSerializer, responses=UsuarioPerfilSerializer)
    def put(self, request):
        user = own_user(request, request.query_params.get("nome"))
        serializer = UsuarioPerfilSerializer(user, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


class UsuarioSenhaAPIView(APIView):
    permission_classes = [IsAuthenticated]
    serializer_class = TrocaSenhaRequestSerializer

    @extend_schema(tags=["Usuários"], request=TrocaSenhaRequestSerializer, responses=MensagemSerializer)
    def post(self, request):
        user = own_user(request, request.data.get("nome"))
        data = UsuarioSenhaSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        if not user.check_password(data.validated_data["senha_atual"]):
            return Response({"error": "Senha atual incorreta."}, status=403)
        user.set_password(data.validated_data["nova_senha"])
        user.save(update_fields=["password"])
        Token.objects.filter(user=user).delete()
        return Response({"status": "success", "message": "Senha alterada. Entre novamente."})


class UsuarioFotoAPIView(APIView):
    permission_classes = [IsAuthenticated]
    serializer_class = FotoPerfilRequestSerializer

    @extend_schema(tags=["Usuários"], request=FotoPerfilRequestSerializer, responses=MensagemSerializer)
    def post(self, request):
        user = own_user(request, request.data.get("nome"))
        photo = request.data.get("foto_perfil")
        if not photo:
            raise ValidationError({"error": "Informe a foto."})
        if not isinstance(photo, str) or len(photo) > 2000000:
            raise ValidationError({"error": "Foto inválida ou muito grande."})
        user.foto_perfil = photo
        user.save(update_fields=["foto_perfil"])
        return Response({"status": "success", "message": "Foto atualizada."})


class LogoutAPIView(APIView):
    permission_classes = [IsAuthenticated]
    serializer_class = MensagemSerializer

    @extend_schema(tags=["Autenticação"], request=None, responses=MensagemSerializer)
    def post(self, request):
        Token.objects.filter(user=request.user).delete()
        return Response({"status": "success", "message": "Sessão encerrada."})
