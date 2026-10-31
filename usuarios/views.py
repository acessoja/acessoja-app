from django.shortcuts import get_object_or_404
from django.db import transaction
from drf_spectacular.utils import extend_schema
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from acessoja.api_schema import FotoPerfilRequestSerializer, MensagemSerializer, TrocaSenhaRequestSerializer
from .account_services import change_password, locked_request_user, revoke_credentials
from .security_throttles import SecurityThrottle
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
    @transaction.atomic
    def put(self, request):
        own_user(request, request.query_params.get("nome"))
        user = locked_request_user(request)
        serializer = UsuarioPerfilSerializer(user, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


class UsuarioSenhaAPIView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [SecurityThrottle]
    security_scope = "password_change"
    serializer_class = TrocaSenhaRequestSerializer

    @extend_schema(tags=["Usuários"], request=TrocaSenhaRequestSerializer, responses=MensagemSerializer)
    def post(self, request):
        user = own_user(request, request.data.get("nome"))
        data = UsuarioSenhaSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        try:
            change_password(user.pk, data.validated_data["senha_atual"], data.validated_data["nova_senha"])
        except ValidationError as exc:
            if isinstance(exc.detail, dict) and "current_password" in exc.detail:
                return Response({"error": "Senha atual incorreta."}, status=403)
            raise
        return Response({"status": "success", "message": "Senha alterada. Entre novamente."})


class UsuarioFotoAPIView(APIView):
    permission_classes = [IsAuthenticated]
    serializer_class = FotoPerfilRequestSerializer

    @extend_schema(tags=["Usuários"], request=FotoPerfilRequestSerializer, responses=MensagemSerializer)
    def post(self, request):
        own_user(request, request.data.get("nome"))
        from midia.legacy import update_legacy_avatar
        from midia.services import operation_document
        op = update_legacy_avatar(request)
        return Response({"status": "success" if op.state == 'committed' else 'processing',
                         "message": "Foto atualizada." if op.state == 'committed' else 'Processamento em andamento.',
                         **operation_document(op)}, status=200 if op.state == 'committed' else 202)


class LogoutAPIView(APIView):
    permission_classes = [IsAuthenticated]
    serializer_class = MensagemSerializer

    @extend_schema(tags=["Autenticação"], request=None, responses=MensagemSerializer)
    def post(self, request):
        revoke_credentials(request.user)
        return Response({"status": "success", "message": "Sessão encerrada."})
