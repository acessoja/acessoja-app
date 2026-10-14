import math
from drf_spectacular.utils import OpenApiExample, OpenApiParameter, extend_schema, extend_schema_view
from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.permissions import BasePermission, IsAuthenticated, SAFE_METHODS
from .models import Local, VisitaRecente
from .serializers import ArrivalRequestSerializer, LocalSerializer, VisitaRecenteSerializer
from acessoja.accessibility_catalog import catalog
from .accessibility import matching_resources, parse_filters
from .accessibility_serializers import ResourceCatalogSerializer
from .services.accessibility import local_accessibility, populate_accessibility_context


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
        return self.queryset.order_by("id_local")

    @extend_schema(
        summary="Consultar locais com estados explícitos e filtros AND",
        description="Categorias e origens combinam por OR; todos os recursos são exigidos (AND). "
                    "Desconhecimento é opcional; ausência, divergência, não aplicabilidade "
                    "e acesso parcial são excluídos. "
                    "Booleanos legados continuam na resposta, sem comprovar presença ou ausência.",
        parameters=[
            OpenApiParameter("recursos", str, description="IDs do catálogo separados por vírgula (AND)."),
            OpenApiParameter("categorias", str, description="Categorias separadas por vírgula (OR)."),
            OpenApiParameter("origens", str,
                             description="acessoja,openstreetmap (OR); este endpoint só lista cadastrados."),
            OpenApiParameter("incluir_desconhecidos", bool,
                             description="Padrão false. Só admite unknown adicionalmente."),
            OpenApiParameter("search", str, description="Nome ou endereço; máximo 180 caracteres."),
        ],
        examples=[OpenApiExample("Recursos informados", response_only=True, value={
            "accessibility_information": {}, "accessibility": {
                "rampa_acesso": {"state": "unknown", "evidence": [], "community_state": "not_evaluated",
                                 "legacy_not_comparable": 0}}, "missing_resources": [],
        })],
    )
    def list(self, request, *args, **kwargs):
        try:
            filters = parse_filters(request.query_params)
        except ValueError as exc:
            raise ValidationError({"filters": str(exc)}) from None
        # Reject repeated parameters rather than silently accepting the last value.
        if any(len(request.query_params.getlist(key)) != 1 for key in request.query_params):
            raise ValidationError({"filters": "Envie cada parâmetro uma vez; listas usam vírgula."})
        qs = self.get_queryset()
        if filters["categories"]:
            qs = qs.filter(categoria__in=filters["categories"])
        if filters["search"]:
            from django.db.models import Q
            qs = qs.filter(Q(nome__icontains=filters["search"]) | Q(endereco__icontains=filters["search"]))
        if filters["sources"] == ["openstreetmap"]:
            qs = qs.exclude(osm_id__isnull=True).exclude(osm_id="")
        locals_ = list(qs)
        context = populate_accessibility_context(locals_, self.get_serializer_context())
        context["missing_resources"] = {}
        matched = []
        for local in locals_:
            accepted, missing = matching_resources(
                local_accessibility(local, context), filters["resources"], filters["include_unknown"]
            )
            if accepted:
                matched.append(local)
                context["missing_resources"][local.pk] = missing
        return Response(self.get_serializer(matched, many=True, context=context).data)

    @extend_schema(summary="Catálogo compartilhado de recursos", responses=ResourceCatalogSerializer)
    @action(detail=False, methods=["get"], url_path="recursos")
    def resources(self, request):
        return Response(catalog())


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
