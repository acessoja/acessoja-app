"""No client-supplied identity is used by this private endpoint."""
from django.db import transaction
from django.shortcuts import get_object_or_404
from drf_spectacular.utils import OpenApiExample, extend_schema, extend_schema_field
from rest_framework import serializers
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.settings import api_settings
from rest_framework.views import APIView

from acessoja.accessibility_catalog import CATALOG_VERSION, RESOURCE_IDS, validate_preferences
from acessoja.api_schema import ErroSerializer
from .models import Usuario


@extend_schema_field({"type": "array", "items": {"type": "string", "enum": list(RESOURCE_IDS)}, "maxItems": 100})
class PreferenceResourcesField(serializers.Field):
    def to_internal_value(self, value):
        try:
            return validate_preferences(value)
        except ValueError as exc:
            raise serializers.ValidationError(str(exc)) from None

    def to_representation(self, value):
        return value


class PreferencesWriteSerializer(serializers.Serializer):
    resources = PreferenceResourcesField()

    def to_internal_value(self, data):
        if not isinstance(data, dict) or set(data) - {"resources"}:
            raise serializers.ValidationError({
                api_settings.NON_FIELD_ERRORS_KEY: [
                    "Envie somente resources. A identidade vem da sessão autenticada."
                ]
            })
        return super().to_internal_value(data)


class PreferencesReadSerializer(serializers.Serializer):
    catalog_version = serializers.IntegerField()
    resources = serializers.ListField(child=serializers.CharField())
    unavailable_resources = serializers.ListField(child=serializers.CharField())


class AccessibilityPreferencesAPIView(APIView):
    permission_classes = [IsAuthenticated]
    serializer_class = PreferencesWriteSerializer

    def initial(self, request, *args, **kwargs):
        super().initial(request, *args, **kwargs)
        if set(request.query_params) - {"format"}:
            raise ValidationError("Este endpoint não aceita nome ou ID de usuário, nem filtros de identidade.")

    def respond(self, user):
        resources = list(user.accessibility_preferences)
        return Response({"catalog_version": CATALOG_VERSION, "resources": resources,
                         "unavailable_resources": [key for key in resources if key not in RESOURCE_IDS]},
                        headers={"Cache-Control": "private, no-store"})

    @extend_schema(
        tags=["Usuários"], summary="Consultar minhas preferências privadas e opcionais",
        description="Usa exclusivamente request.user. Não aparece em perfis, usuários ou avaliações públicas.",
        responses={200: PreferencesReadSerializer, 401: ErroSerializer, 403: ErroSerializer},
    )
    def get(self, request):
        user = get_object_or_404(Usuario, pk=request.user.pk)
        return self.respond(user)

    def save_preferences(self, request, partial=False):
        serializer = PreferencesWriteSerializer(data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        with transaction.atomic():
            user = Usuario.objects.select_for_update().get(pk=request.user.pk)
            if "resources" in serializer.validated_data:
                user.accessibility_preferences = serializer.validated_data["resources"]
                user.save(update_fields=["accessibility_preferences"])
        return self.respond(user)

    @extend_schema(
        tags=["Usuários"], summary="Salvar minhas preferências de busca",
        request=PreferencesWriteSerializer,
        responses={200: PreferencesReadSerializer, 400: ErroSerializer, 401: ErroSerializer, 403: ErroSerializer},
        examples=[OpenApiExample("Escolhas opcionais", request_only=True,
                                 value={"resources": ["rampa_acesso", "piso_tatil", "atendimento_libras"]})],
    )
    def put(self, request):
        return self.save_preferences(request)

    @extend_schema(
        tags=["Usuários"], summary="Editar minhas preferências; campo omitido preserva",
        request=PreferencesWriteSerializer,
        responses={200: PreferencesReadSerializer, 400: ErroSerializer, 401: ErroSerializer, 403: ErroSerializer},
    )
    def patch(self, request):
        return self.save_preferences(request, partial=True)

    @extend_schema(tags=["Usuários"], summary="Limpar minhas preferências", request=None,
                   responses={200: PreferencesReadSerializer, 401: ErroSerializer, 403: ErroSerializer})
    def delete(self, request):
        with transaction.atomic():
            user = Usuario.objects.select_for_update().get(pk=request.user.pk)
            user.accessibility_preferences = []
            user.save(update_fields=["accessibility_preferences"])
        return self.respond(user)
