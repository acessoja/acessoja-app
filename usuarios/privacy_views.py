from django.conf import settings
from django.http import HttpResponse
from drf_spectacular.utils import extend_schema
from rest_framework import serializers
from rest_framework.exceptions import NotAuthenticated, ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .account_serializers import ReauthenticationSerializer, DeleteAccountSerializer
from .account_views import AccountUserViewSet
from .models import Usuario
from .privacy_choices import choices_document
from .privacy_services import export_account
from .security_throttles import SecurityThrottle


class PrivacyDocumentSerializer(serializers.Serializer):
    notice_version = serializers.CharField()
    choices = serializers.ListField(child=serializers.DictField())
    contact_email = serializers.CharField()
    retention = serializers.CharField()
    preference_information = serializers.CharField()


class PersonalDataExportSerializer(serializers.Serializer):
    format_version = serializers.CharField()
    generated_at = serializers.DateTimeField()
    categories = serializers.DictField()
    not_included = serializers.ListField(child=serializers.DictField())


class OwnAccountAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def initial(self, request, *args, **kwargs):
        super().initial(request, *args, **kwargs)
        if set(request.query_params) - {"format"}:
            raise ValidationError("A conta vem exclusivamente da autenticação. Não envie ID ou nome.")


class PrivacyDocumentAPIView(OwnAccountAPIView):
    @extend_schema(tags=["Privacidade"], responses=PrivacyDocumentSerializer,
                   summary="Consultar minhas escolhas e o aviso de privacidade")
    def get(self, request):
        user = Usuario.objects.get(pk=request.user.pk)
        return Response({**choices_document(user), "contact_email": settings.PRIVACY_CONTACT_EMAIL,
                         "preference_information": "As preferências de acessibilidade são privadas e opcionais; "
                         "não exigimos diagnóstico. A permissão de GPS é controlada no dispositivo e não autoriza "
                         "guardar histórico. As opções antigas de visibilidade não publicam suas rotas ou posição.",
                         "retention": "Os dados da conta permanecem até sua exclusão ou limpeza individual. "
                         "Histórico de consentimentos: até 180 dias, preservando a decisão vigente. "
                         "Logs mínimos: até 14 dias. Backups privados: até 14 dias. O registro técnico de exclusão "
                         "fica por pelo menos 35 dias e é aplicado antes de liberar uma restauração."})


class AccountExportAPIView(OwnAccountAPIView):
    throttle_classes = [SecurityThrottle]
    security_scope = "export"

    @extend_schema(tags=["Privacidade"], request=ReauthenticationSerializer, responses=PersonalDataExportSerializer,
                   summary="Baixar meus dados em JSON privado após confirmar a senha",
                   description="Limite imediato de 10000 registros e 8 MiB. Sem arquivo permanente no servidor.")
    def post(self, request):
        serializer = ReauthenticationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            content = export_account(request.user.pk, serializer.validated_data["current_password"])
        except Usuario.DoesNotExist:
            raise NotAuthenticated() from None
        response = HttpResponse(content, content_type="application/json; charset=utf-8")
        response["Content-Disposition"] = 'attachment; filename="acessoja-meus-dados.json"'
        response["Cache-Control"] = "private, no-store"
        response["X-Content-Type-Options"] = "nosniff"
        return response


class AccountDeleteAPIView(OwnAccountAPIView):
    throttle_classes = [SecurityThrottle]
    security_scope = "delete"

    @extend_schema(tags=["Privacidade"], request=DeleteAccountSerializer, responses={204: None, 202: None},
                   summary="Confirmar identidade e excluir minha conta e meus dados")
    def post(self, request):
        # Same service/contract as DELETE /auth/users/me/; no weaker alternate path.
        view = AccountUserViewSet()
        view.action = "me"
        return view.destroy(request)
