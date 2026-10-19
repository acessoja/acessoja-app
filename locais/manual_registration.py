"""Explicit manual writes with per-owner receipts and cross-worker duplicate lock."""

import hashlib
import json

from django.db import OperationalError, transaction
from drf_spectacular.utils import extend_schema
from rest_framework import serializers
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from acessoja.api_schema import ErroSerializer
from .external_serializers import FiniteFloat
from .models import Local, ManualPlaceRegistration, ManualRegistrationGuard
from .serializers import LocalSerializer
from .services.categories import CATEGORIES
from .services.matching import same_attributes


class ManualRegistrationSerializer(serializers.Serializer):
    request_id = serializers.UUIDField()
    nome = serializers.CharField(max_length=255)
    endereco = serializers.CharField(max_length=255)
    categoria = serializers.ChoiceField(choices=list(CATEGORIES))
    latitude = FiniteFloat(min_value=-90, max_value=90)
    longitude = FiniteFloat(min_value=-180, max_value=180)
    point_confirmed = serializers.BooleanField()
    distinct_reason = serializers.CharField(min_length=10, max_length=500, required=False)

    def validate(self, attrs):
        if set(self.initial_data) - set(self.fields):
            raise serializers.ValidationError("Campo desconhecido.")
        if self.initial_data.get("point_confirmed") is not True:
            raise serializers.ValidationError("Confirme explicitamente o ponto do estabelecimento.")
        return attrs


class ManualRegistrationAPIView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(
        tags=["Locais"],
        summary="Cadastrar local com ponto confirmado e UUID de tentativa",
        request=ManualRegistrationSerializer,
        responses={
            200: LocalSerializer,
            201: LocalSerializer,
            400: ErroSerializer,
            401: ErroSerializer,
            409: ErroSerializer,
            410: ErroSerializer,
            503: ErroSerializer,
        },
    )
    def post(self, request):
        serializer = ManualRegistrationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = dict(serializer.validated_data)
        request_id = data.pop("request_id")
        digest = hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()
        try:
            with transaction.atomic():
                # Seeded by migration. One global guard covers different owners/UUIDs.
                ManualRegistrationGuard.objects.select_for_update().get(pk=1)
                receipt = ManualPlaceRegistration.objects.filter(user=request.user, request_id=request_id).first()
                if receipt:
                    if receipt.payload_hash != digest:
                        return Response({"detail": "Tentativa já utilizada com outros dados."}, status=409)
                    if receipt.local_id is None:
                        return Response({"detail": "O local desta tentativa foi removido."}, status=410)
                    return Response(LocalSerializer(receipt.local, context={"request": request}).data)
                reason = data.pop("distinct_reason", "")
                data.pop("point_confirmed")
                candidates = [
                    local
                    for local in Local.objects.filter(
                        latitude__range=(data["latitude"] - 0.0003, data["latitude"] + 0.0003)
                    )
                    if same_attributes(data, local)
                ]
                if candidates and not reason:
                    return Response(
                        {
                            "detail": "Possível duplicata. Revise o existente ou justifique local distinto.",
                            "code": "possible_duplicate",
                            "candidates": LocalSerializer(candidates, many=True, context={"request": request}).data,
                        },
                        status=409,
                    )
                local = Local.objects.create(**data, distancia=0)
                ManualPlaceRegistration.objects.create(
                    user=request.user, request_id=request_id, payload_hash=digest, local=local, distinct_reason=reason
                )
                return Response(LocalSerializer(local, context={"request": request}).data, status=201)
        except OperationalError as exc:
            if "locked" not in str(exc).lower():
                raise
            return Response(
                {"detail": "Cadastro ocupado. Repita a mesma tentativa."}, status=503, headers={"Retry-After": "2"}
            )
