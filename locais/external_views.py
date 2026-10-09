from django.core import signing
from django.db import IntegrityError, transaction
from drf_spectacular.utils import extend_schema
from rest_framework.authentication import BasicAuthentication, SessionAuthentication
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import AnonRateThrottle, UserRateThrottle
from rest_framework.views import APIView

from acessoja.api_schema import ErroSerializer
from .external_serializers import (
    CategorySerializer,
    ExternalImportSerializer,
    ExternalResultsSerializer,
    ExternalSearchSerializer,
    GeocodeQuerySerializer,
    GeocodeResultSerializer,
)
from .models import Local
from .serializers import LocalSerializer
from .services.categories import CATEGORIES
from .services.external_places_service import ExternalPlacesService, ExternalServiceError, TOKEN_SALT, geocode
from .services.matching import find_internal


class GeographicAnonThrottle(AnonRateThrottle):
    rate = "20/min"


class GeographicUserThrottle(UserRateThrottle):
    rate = "40/min"


class GeographicAPIView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [GeographicAnonThrottle, GeographicUserThrottle]

    def handle_exception(self, exc):
        if isinstance(exc, ExternalServiceError):
            return Response({"detail": exc.detail}, status=exc.status, headers={"Retry-After": str(exc.retry_after)})
        return super().handle_exception(exc)


class ExternalPlacesAPIView(GeographicAPIView):
    @extend_schema(
        tags=["Locais"],
        summary="Buscar estabelecimentos OpenStreetMap por área",
        parameters=[ExternalSearchSerializer],
        responses={
            200: ExternalResultsSerializer,
            400: ErroSerializer,
            429: ErroSerializer,
            502: ErroSerializer,
            503: ErroSerializer,
            504: ErroSerializer,
        },
    )
    def get(self, request):
        serializer = ExternalSearchSerializer(data=request.query_params)
        serializer.is_valid(raise_exception=True)
        result = ExternalPlacesService().search(**serializer.validated_data)
        # Read-time matching annotates; it never writes to the database.
        candidates = list(Local.objects.all())
        for place in result["results"]:
            match = find_internal(place, candidates)
            place["internal_id"] = match.pk if match else None
        return Response(result)


class ExternalCategoriesAPIView(APIView):
    permission_classes = [AllowAny]

    @extend_schema(tags=["Locais"], summary="Categorias do mapa", responses={200: CategorySerializer(many=True)})
    def get(self, request):
        return Response([{"id": key, "label": value["label"]} for key, value in CATEGORIES.items()])


class GeocodeAPIView(GeographicAPIView):
    @extend_schema(
        tags=["Locais"],
        summary="Pesquisa geográfica confirmada pelo usuário",
        parameters=[GeocodeQuerySerializer],
        responses={200: GeocodeResultSerializer(many=True), 400: ErroSerializer, 503: ErroSerializer},
    )
    def get(self, request):
        serializer = GeocodeQuerySerializer(data=request.query_params)
        serializer.is_valid(raise_exception=True)
        return Response(geocode(serializer.validated_data))


class ExternalImportAPIView(GeographicAPIView):
    permission_classes = [IsAuthenticated]
    authentication_classes = [BasicAuthentication, SessionAuthentication]

    @extend_schema(
        tags=["Locais"],
        summary="Confirmar cadastro de um estabelecimento externo",
        description="Exige sessão autenticada ou HTTP Basic. Token assinado expira em 15 minutos. "
        "Retorna 200 se já cadastrado ou 201 se criou. Não cria avaliações.",
        request=ExternalImportSerializer,
        responses={
            200: LocalSerializer,
            201: LocalSerializer,
            400: ErroSerializer,
            401: ErroSerializer,
            409: ErroSerializer,
        },
    )
    def post(self, request):
        serializer = ExternalImportSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        try:
            place = signing.loads(data["registration_token"], salt=TOKEN_SALT, max_age=900)
        except signing.BadSignature:
            return Response({"detail": "Dados expirados ou inválidos. Busque o local novamente."}, status=400)
        try:
            with transaction.atomic():
                # UNIQUE protects concurrent creates; row locking protects an
                # existing record when two OSM objects try to claim its link.
                match = find_internal(place) or find_internal(
                    {
                        **place,
                        "nome": data["nome"],
                        "endereco": data["endereco"],
                    }
                )
                if match:
                    match = Local.objects.select_for_update().get(pk=match.pk)
                    if match.osm_id and match.osm_id != place["external_id"]:
                        return Response(
                            {"detail": "Cadastro já vinculado a outro objeto. Revise os dados."}, status=409
                        )
                    if not match.osm_id:
                        match.osm_id = place["external_id"]
                        match.save(update_fields=["osm_id"])
                    return Response(LocalSerializer(match).data)
                local = Local.objects.create(
                    osm_id=place["external_id"],
                    nome=data["nome"],
                    endereco=data["endereco"],
                    latitude=place["latitude"],
                    longitude=place["longitude"],
                    categoria=place["categoria"],
                    # Legacy required field: zero is an unmeasured placeholder, never a GPS distance.
                    distancia=0,
                )
        except IntegrityError:
            # Another request imported the same object while this transaction was active.
            local = Local.objects.filter(osm_id=place["external_id"]).first()
            if local is None:
                raise
            return Response(LocalSerializer(local).data)
        return Response(LocalSerializer(local).data, status=201)
