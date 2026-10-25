"""Extend the deployed Djoser contract, keeping one implementation per flow."""
from django.db import transaction
from acessoja.api_schema import LoginRequestSerializer
from djoser.views import UserViewSet
from drf_spectacular.utils import extend_schema
from rest_framework import serializers
from rest_framework.decorators import action
from rest_framework.exceptions import NotFound, NotAuthenticated, ValidationError
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .account_serializers import ResetConfirmSerializer, ResetRequestSerializer, SetPasswordSerializer
from .account_serializers import DeleteAccountSerializer
from .account_services import change_password, confirm_password_reset, login_token, request_password_reset
from .account_services import locked_request_user, revoke_credentials
from .models import Usuario
from .privacy_services import delete_account
from .security_throttles import SecurityThrottle


class AuthTokenSerializer(serializers.Serializer):
    auth_token = serializers.CharField(read_only=True)


class AccountTokenLoginView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [SecurityThrottle]
    security_scope = "login"

    @extend_schema(tags=["Autenticação"], request=LoginRequestSerializer,
                   responses={200: AuthTokenSerializer}, summary="Login pelo contrato de token do Djoser")
    def post(self, request):
        serializer = LoginRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        result = login_token(serializer.validated_data["nome"], serializer.validated_data["password"])
        if result is None:
            raise ValidationError({"detail": "Nome de usuário ou senha incorretos."})
        return Response({"auth_token": result[1].key})


class AccountUserViewSet(UserViewSet):
    """Djoser still supplies registration, user serializers and its route names."""

    def initialize_request(self, request, *args, **kwargs):
        if self.action_map.get(request.method.lower()) in {"create", "reset_password", "reset_password_confirm"}:
            # A stale token in a browser must never block these public actions.
            self.authentication_classes = []
        return super().initialize_request(request, *args, **kwargs)

    def get_throttles(self):
        self.security_scope = {"reset_password": "reset_request", "reset_password_confirm": "reset_confirm",
                               "set_password": "password_change", "destroy": "delete", "create": "login"}.get(
                                   self.action)
        if self.action == "me" and self.request.method == "DELETE":
            self.security_scope = "delete"
        return [SecurityThrottle()] if self.security_scope else super().get_throttles()

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False) or not self.request.user.is_authenticated:
            return Usuario.objects.none()
        return Usuario.objects.filter(pk=self.request.user.pk)

    def get_serializer_class(self):
        return {"reset_password": ResetRequestSerializer, "reset_password_confirm": ResetConfirmSerializer,
                "set_password": SetPasswordSerializer, "destroy": DeleteAccountSerializer}.get(
                    self.action) or super().get_serializer_class()

    @extend_schema(tags=["Autenticação"], request=ResetRequestSerializer, responses={204: None},
                   summary="Solicitar recuperação sem identificar contas",
                   description="Aceita na fila: não confirma existência da conta ou entrega. Limites por IP e e-mail.")
    @action(["post"], detail=False)
    def reset_password(self, request, *args, **kwargs):
        serializer = ResetRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        request_password_reset(serializer.validated_data["email"])
        return Response(status=204)

    @extend_schema(tags=["Autenticação"], request=ResetConfirmSerializer, responses={204: None},
                   summary="Redefinir senha com link temporário e encerrar as sessões")
    @action(["post"], detail=False)
    def reset_password_confirm(self, request, *args, **kwargs):
        serializer = ResetConfirmSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        values = serializer.validated_data
        confirm_password_reset(values["uid"], values["token"], values["new_password"])
        return Response(status=204)

    @extend_schema(tags=["Autenticação"], request=SetPasswordSerializer, responses={204: None},
                   summary="Trocar senha reautenticando e revogar credenciais anteriores")
    @action(["post"], detail=False)
    def set_password(self, request, *args, **kwargs):
        serializer = SetPasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        values = serializer.validated_data
        if values["new_password"] != values["re_new_password"]:
            raise ValidationError({"re_new_password": ["As senhas não coincidem."]})
        change_password(request.user.pk, values["current_password"], values["new_password"])
        return Response(status=204)

    @extend_schema(tags=["Privacidade"], request=DeleteAccountSerializer, responses={204: None, 202: None},
                   summary="Excluir somente minha conta, com senha atual e confirmação explícita")
    def destroy(self, request, *args, **kwargs):
        if self.action != "me" and str(kwargs.get(self.lookup_field)) != str(request.user.pk):
            raise NotFound()
        serializer = DeleteAccountSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            published = delete_account(request.user.pk, serializer.validated_data["current_password"])
        except Usuario.DoesNotExist:
            raise NotAuthenticated() from None
        return Response(status=204) if published else Response({
            "detail": "A conta foi desativada e os dados foram removidos do banco ativo. "
                      "A proteção da exclusão nos backups está pendente de confirmação operacional.",
            "code": "deletion_pending_journal",
        }, status=202)

    # Username recovery/activation was not used by this product and otherwise
    # introduces alternate account mutation with password-reset token semantics.
    @extend_schema(exclude=True)
    @action(["post"], detail=False, url_path="set_nome")
    def set_username(self, request, *args, **kwargs):
        raise NotFound()

    @extend_schema(exclude=True)
    @action(["post"], detail=False, url_path="reset_nome")
    def reset_username(self, request, *args, **kwargs):
        raise NotFound()

    @extend_schema(exclude=True)
    @action(["post"], detail=False, url_path="reset_nome_confirm")
    def reset_username_confirm(self, request, *args, **kwargs):
        raise NotFound()

    @extend_schema(exclude=True)
    @action(["post"], detail=False)
    def activation(self, request, *args, **kwargs):
        raise NotFound()

    @extend_schema(exclude=True)
    @action(["post"], detail=False)
    def resend_activation(self, request, *args, **kwargs):
        raise NotFound()

    def update(self, request, *args, **kwargs):
        with transaction.atomic():
            user = locked_request_user(request)
            if self.action != "me" and str(kwargs.get(self.lookup_field)) != str(user.pk):
                raise NotFound()
            serializer = self.get_serializer(user, data=request.data, partial=kwargs.get("partial", False))
            serializer.is_valid(raise_exception=True)
            serializer.save()
            return Response(serializer.data)


class AccountTokenLogoutView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(tags=["Autenticação"], request=None, responses={204: None},
                   summary="Revogar tokens e sessões pelo contrato Djoser")
    def post(self, request):
        revoke_credentials(request.user)
        return Response(status=204)
