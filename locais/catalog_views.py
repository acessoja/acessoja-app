from django.db import IntegrityError, transaction
from django.db.models import F
from django.http import Http404
from drf_spectacular.utils import extend_schema
from rest_framework.authentication import BasicAuthentication, SessionAuthentication
from rest_framework.exceptions import ValidationError
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.utils.urls import replace_query_param

from acessoja.api_schema import ErroSerializer
from acessoja.authentication import ExpiringTokenAuthentication
from .accessibility import parse_filters
from .catalog_models import CatalogEntry, CatalogPOI, CatalogScope
from .catalog_serializers import (
    CatalogConfirmSerializer,
    CatalogPlaceSerializer,
    CatalogQuerySerializer,
    CatalogResultsSerializer,
)
from .discovery import DiscoveryOptions, OPTIONS
from .models import Local, ManualRegistrationGuard
from .serializers import LocalSerializer
from .services.accessibility import populate_accessibility_context
from .services.catalog_query import catalog_place, catalog_queryset
from .services.catalog_import import canonical_match
from .services.catalog_rules import MUNICIPALITY

PRIVATE = {"Cache-Control": "private, no-store", "Vary": "Authorization, Cookie"}


def active_scope():
    return CatalogScope.objects.select_related("active_batch").filter(pk=MUNICIPALITY).first()


def active_entry(poi_id):
    scope = active_scope()
    entry = (
        CatalogEntry.objects.filter(batch_id=scope.active_batch_id, poi_id=poi_id)
        .select_related("poi", "poi__local", "batch", "observed_in")
        .first()
        if scope and scope.active_batch_id
        else None
    )
    if entry is None:
        raise Http404
    return entry


class CatalogListAPIView(APIView):
    permission_classes = [AllowAny]

    @extend_schema(
        operation_id="catalog_list",
        tags=["Catálogo municipal"],
        parameters=[CatalogQuerySerializer],
        description="Escopo independente: POIs OSM ainda sem Local canônico. Nunca soma totais comunitários. "
        "Filtros e ordenação em SQL antes de paginar. Rating empata itens sem avaliação por nome/ID. "
        "catalog_version fixa o contexto; uma mudança retorna 409 e exige reiniciar a consulta.",
        responses={200: CatalogResultsSerializer, 400: ErroSerializer, 409: ErroSerializer},
    )
    def get(self, request):
        params = request.query_params
        try:
            if any(len(values) != 1 for _, values in params.lists()):
                raise ValueError("Parâmetros repetidos não são permitidos.")
            options = DiscoveryOptions({"paginated": "true", "ordering": "name", **params.dict()})
            filters = parse_filters({k: v for k, v in params.items() if k not in OPTIONS | {"catalog_version"}})
        except ValueError as exc:
            raise ValidationError({"detail": str(exc)}) from None
        scope = active_scope()
        version = f"{scope.revision}:{scope.active_batch_id}" if scope else "0:None"
        if params.get("catalog_version", version) != version:
            return Response(
                {"code": "catalog_changed", "detail": "O catálogo foi atualizado. Reinicie a busca."},
                status=409,
                headers=PRIVATE,
            )
        rows = catalog_queryset(scope.active_batch_id if scope else None, options, filters)
        from evidencias.query_projection import annotate_quality
        rows = annotate_quality(rows, catalog=True)
        paginator = PageNumberPagination()
        paginator.page_size = options.page_size
        page = paginator.paginate_queryset(rows.select_related("poi", "batch", "observed_in"), request)

        def pin(url):
            return replace_query_param(url, "catalog_version", version) if url else None

        results = [catalog_place(entry, filters) for entry in page]
        from evidencias.external import project_catalog_places
        project_catalog_places(page, results)
        if (
            scope
            and not CatalogScope.objects.filter(
                pk=scope.pk, revision=scope.revision, active_batch_id=scope.active_batch_id
            ).exists()
        ):
            return Response(
                {"code": "catalog_changed", "detail": "O catálogo foi atualizado. Reinicie a busca."},
                status=409,
                headers=PRIVATE,
            )
        return Response(
            {
                "count": paginator.page.paginator.count,
                "next": pin(paginator.get_next_link()),
                "previous": pin(paginator.get_previous_link()),
                "catalog_version": version,
                "available": bool(scope and scope.active_batch_id),
                "scope": "unlinked_osm_catalog",
                "coverage_complete": bool(scope and scope.active_batch and scope.active_batch.complete),
                "ordering": "name_unreviewed" if options.ordering == "rating" else options.ordering,
                "results": results,
            },
            headers=PRIVATE,
        )


class CatalogDetailAPIView(APIView):
    permission_classes = [AllowAny]

    @extend_schema(tags=["Catálogo municipal"], responses={200: CatalogPlaceSerializer, 404: ErroSerializer})
    def get(self, request, poi_id):
        entry = active_entry(poi_id)
        local = entry.poi.local or Local.objects.filter(osm_id=entry.poi.external_id).first()
        context = populate_accessibility_context([local], {"request": request}) if local else {}
        linked = LocalSerializer(local, context=context).data if local else None
        document = catalog_place(entry, linked_local=linked)
        from evidencias.external import project_catalog_places
        project_catalog_places([entry], [document])
        return Response(document, headers=PRIVATE)


class CatalogConfirmAPIView(APIView):
    permission_classes = [IsAuthenticated]
    authentication_classes = [ExpiringTokenAuthentication, BasicAuthentication, SessionAuthentication]

    @extend_schema(
        tags=["Catálogo municipal"],
        request=CatalogConfirmSerializer,
        description="Confirma um ID persistido. Não aceita coordenadas/identidade do cliente, não consulta "
        "provedores, não cria visita, avaliação ou favorito. Repetições retornam o mesmo Local.",
        responses={
            200: LocalSerializer,
            201: LocalSerializer,
            400: ErroSerializer,
            401: ErroSerializer,
            404: ErroSerializer,
            409: ErroSerializer,
        },
    )
    def post(self, request, poi_id):
        serializer = CatalogConfirmSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        try:
            with transaction.atomic():
                ManualRegistrationGuard.objects.select_for_update().get(pk=1)
                scope = CatalogScope.objects.select_for_update().get(pk=MUNICIPALITY)
                entry = (
                    CatalogEntry.objects.filter(batch_id=scope.active_batch_id, poi_id=poi_id)
                    .select_related("poi", "observed_in", "batch")
                    .first()
                )
                if entry is None:
                    raise Http404
                poi = CatalogPOI.objects.select_for_update().get(pk=poi_id)
                local = poi.local or Local.objects.filter(osm_id=poi.external_id).first()
                if not local and entry.source_status != "available":
                    return Response(
                        {"detail": "Item não observado no snapshot atual. Reinicie a busca."},
                        status=409,
                        headers=PRIVATE,
                    )
                if not local:
                    values = {
                        "original_name": data["nome"],
                        "address": data["endereco"],
                        "category": entry.category,
                        "latitude": entry.latitude,
                        "longitude": entry.longitude,
                    }
                    local, _, ambiguous = canonical_match(poi.external_id, values)
                    if ambiguous:
                        return Response(
                            {"detail": "Há cadastros semelhantes. Revise o local antes de confirmar."},
                            status=409,
                            headers=PRIVATE,
                        )
                created = local is None
                if created:
                    local = Local.objects.create(
                        osm_id=poi.external_id,
                        nome=data["nome"],
                        endereco=data["endereco"],
                        categoria=entry.category,
                        latitude=entry.latitude,
                        longitude=entry.longitude,
                        distancia=0,
                    )
                elif not local.osm_id:
                    local.osm_id = poi.external_id
                    local.save(update_fields=["osm_id"])
                if poi.local_id != local.pk:
                    poi.local, poi.link_method = local, "explicit_confirmation"
                    poi.save(update_fields=["local", "link_method"])
                    CatalogScope.objects.filter(pk=MUNICIPALITY).update(revision=F("revision") + 1)
        except IntegrityError:
            local = Local.objects.filter(osm_id=active_entry(poi_id).poi.external_id).first()
            if local is None:
                raise
            created = False
        context = populate_accessibility_context([local], {"request": request})
        return Response(LocalSerializer(local, context=context).data, status=201 if created else 200, headers=PRIVATE)
