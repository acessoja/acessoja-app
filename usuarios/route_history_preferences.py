from django.db import transaction
from django.conf import settings
from django.shortcuts import get_object_or_404
from drf_spectacular.utils import extend_schema
from rest_framework import serializers
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.settings import api_settings
from rest_framework.views import APIView

from acessoja.api_schema import ErroSerializer
from .models import Usuario
from .privacy_choices import choice_enabled, record_choice
from .account_services import locked_request_user


class StrictHistorySerializer(serializers.Serializer):
    def to_internal_value(self, data):
        if not isinstance(data, dict) or set(data) - set(self.fields):
            raise ValidationError({api_settings.NON_FIELD_ERRORS_KEY: ["Campos não permitidos nesta operação."]})
        return super().to_internal_value(data)


class RouteHistoryPreferencesWriteSerializer(StrictHistorySerializer):
    save_history = serializers.BooleanField(required=False)
    save_origin = serializers.BooleanField(required=False)
    notice_version = serializers.CharField(required=False, max_length=32)

    def validate(self, attrs):
        if (attrs.get("save_history") is True or attrs.get("save_origin") is True) and (
                attrs.get("notice_version") != settings.PRIVACY_NOTICE_VERSION):
            raise ValidationError({"notice_version": ["Leia o aviso atual antes de autorizar a coleta."]})
        return attrs


class RouteHistoryPreferencesReadSerializer(serializers.Serializer):
    save_history = serializers.BooleanField()
    save_origin = serializers.BooleanField()
    revision = serializers.IntegerField()


def history_preferences(user):
    return {
        "save_history": choice_enabled(user, "route_history"),
        "save_origin": choice_enabled(user, "route_origin"),
        "revision": user.route_history_revision,
    }


class RouteHistoryPreferencesAPIView(APIView):
    permission_classes = [IsAuthenticated]
    serializer_class = RouteHistoryPreferencesWriteSerializer

    def initial(self, request, *args, **kwargs):
        super().initial(request, *args, **kwargs)
        if set(request.query_params) - {"format"}:
            raise ValidationError("A identidade vem exclusivamente da autenticação.")

    @extend_schema(
        tags=["Histórico de rotas"],
        summary="Consultar autorização privada de histórico",
        responses={200: RouteHistoryPreferencesReadSerializer, 401: ErroSerializer},
    )
    def get(self, request):
        user = get_object_or_404(Usuario, pk=request.user.pk)
        return Response(history_preferences(user), headers={"Cache-Control": "private, no-store"})

    @extend_schema(
        tags=["Histórico de rotas"],
        summary="Autorizar ou revogar gravação de histórico e origem",
        description="Desligado por padrão. Revogar não apaga registros anteriores. GPS é independente.",
        request=RouteHistoryPreferencesWriteSerializer,
        responses={200: RouteHistoryPreferencesReadSerializer, 400: ErroSerializer, 401: ErroSerializer},
    )
    def patch(self, request):
        serializer = self.validate_payload(request.data)
        with transaction.atomic():
            user = locked_request_user(request)
            values = serializer.validated_data
            enabled = values.get("save_history", choice_enabled(user, "route_history"))
            if values.get("save_origin") is True and not enabled:
                raise ValidationError({"save_origin": ["Autorize o histórico antes de salvar a origem."]})
            origin = values.get("save_origin", user.save_route_origin)
            recorded = False
            for field, purpose in (("save_history", "route_history"), ("save_origin", "route_origin")):
                if field in values:
                    recorded = record_choice(user, purpose, values[field]) or recorded
            if recorded or (enabled, origin) != (user.save_route_history, user.save_route_origin):
                user.save_route_history, user.save_route_origin = enabled, origin
                user.route_history_revision += 1
                user.save(update_fields=["save_route_history", "save_route_origin", "route_history_revision"])
        return Response(history_preferences(user), headers={"Cache-Control": "private, no-store"})

    def validate_payload(self, data):
        serializer = self.serializer_class(data=data)
        serializer.is_valid(raise_exception=True)
        return serializer
