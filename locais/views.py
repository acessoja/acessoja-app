import math
from drf_spectacular.utils import extend_schema, extend_schema_view
from rest_framework import viewsets
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.permissions import BasePermission, IsAuthenticated, SAFE_METHODS
from .models import Local, VisitaRecente
from .serializers import ArrivalRequestSerializer, LocalSerializer, VisitaRecenteSerializer


class LocalWritePermission(BasePermission):
    def has_permission(self, request, view):
        return request.method in SAFE_METHODS or (
            request.user.is_authenticated
            and (request.method == "POST" or (request.user.is_staff and request.user.is_superuser))
        )


@extend_schema(tags=["Locais"])
class LocalViewSet(viewsets.ModelViewSet):
    queryset = Local.objects.all()
    serializer_class = LocalSerializer
    permission_classes = [LocalWritePermission]

    def get_queryset(self):
        qs = self.queryset
        for field in ["cao_guia", "mesa_acessivel", "banheiro_acessivel", "rampa_acesso", "cardapio_braille"]:
            if self.request.query_params.get(field) == "true":
                qs = qs.filter(**{field: True})
        return qs


@extend_schema(
    tags=["Visitas"], description="Histórico privado do próprio usuário. Chegada declarada por GPS, não verificada."
)
@extend_schema_view(create=extend_schema(request=ArrivalRequestSerializer))
class VisitaRecenteViewSet(viewsets.ModelViewSet):
    queryset = VisitaRecente.objects.all()
    serializer_class = VisitaRecenteSerializer
    permission_classes = [IsAuthenticated]
    http_method_names = ["get", "post", "delete", "head", "options"]

    def get_queryset(self):
        return self.queryset.filter(user=self.request.user)

    def perform_create(self, serializer):
        user = self.request.user
        if not user.historico_visivel or not user.compartilhar_localizacao:
            raise PermissionDenied("Registro de chegada desativado nas preferências.")
        local = serializer.validated_data["local"]
        data = self.request.data
        try:
            lat, lon, accuracy = (float(data[k]) for k in ["latitude", "longitude", "accuracy"])
            if not all(math.isfinite(x) for x in [lat, lon, accuracy]) or abs(lat) > 90 or abs(lon) > 180:
                raise ValueError
            if not 0 < accuracy <= 50 or local.latitude is None or local.longitude is None:
                raise ValueError
            dlat = math.radians(local.latitude - lat)
            dlon = math.radians(local.longitude - lon)
            a = (
                math.sin(dlat / 2) ** 2
                + math.cos(math.radians(lat)) * math.cos(math.radians(local.latitude)) * math.sin(dlon / 2) ** 2
            )
            meters = 6371000 * 2 * math.asin(min(1, math.sqrt(a)))
            if meters > 50:
                raise ValueError
        except (KeyError, ValueError, TypeError):
            raise ValidationError("Chegada exige coordenadas próximas e GPS preciso.")
        serializer.save(user=user, arrival_confirmed=True)
