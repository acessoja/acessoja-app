from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework.exceptions import APIException, PermissionDenied, ValidationError
from rest_framework.generics import ListCreateAPIView
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from acessoja.api_schema import ErroSerializer
from usuarios.models import Usuario
from usuarios.privacy_choices import choice_enabled
from usuarios.route_history_preferences import RouteHistoryPreferencesReadSerializer, history_preferences
from .models import Local, RouteHistorySession
from .route_history_serializers import (
    RouteHistoryEventSerializer,
    RouteHistoryReadSerializer,
    RouteHistoryStartSerializer,
)


class HistoryConflict(APIException):
    status_code = 409
    default_detail = "Autorização ou evento desatualizado. Consulte o estado atual."


class HistoryGone(APIException):
    status_code = 410
    default_detail = "Esta sessão foi apagada e não pode ser recriada."


def locked_owner(request):
    return get_object_or_404(Usuario.objects.select_for_update(), pk=request.user.pk)


def authorize_write(owner, values):
    if not choice_enabled(owner, "route_history"):
        raise PermissionDenied("A gravação do histórico está desativada.")
    if values["consent_revision"] != owner.route_history_revision:
        raise HistoryConflict()
    if "origin_latitude" in values and not choice_enabled(owner, "route_origin"):
        raise ValidationError({"origin_latitude": ["A gravação da origem não foi autorizada."]})


def approximate_origin(values):
    # A 0.01-degree grid is roughly 1.1 km in latitude. Never retain the input fix.
    if "origin_latitude" in values:
        values["origin_latitude"] = round(values["origin_latitude"], 2)
        values["origin_longitude"] = round(values["origin_longitude"], 2)
    return values


def erase_values():
    # Tombstones contain owner, UUID and deletion time only; no location or route times.
    return {
        "deleted_at": timezone.now(),
        "destination_name": "",
        "destination_source": "",
        "local": None,
        "external_id": "",
        "latitude": None,
        "longitude": None,
        "origin_latitude": None,
        "origin_longitude": None,
        "estimated_distance": None,
        "estimated_duration": None,
        "started_at": None,
        "ended_at": None,
        "status": "",
        "last_event": "",
        "event_index": 0,
        "consent_revision": 0,
    }


class PrivateHistoryMixin:
    permission_classes = [IsAuthenticated]

    def initial(self, request, *args, **kwargs):
        super().initial(request, *args, **kwargs)
        allowed = {"format", "page", "page_size"} if request.method == "GET" else {"format"}
        if set(request.query_params) - allowed:
            raise ValidationError("Use somente paginação; o proprietário vem da autenticação.")

    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        response["Cache-Control"] = "private, no-store"
        return response


class HistoryPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 50


class RouteHistoryListCreateAPIView(PrivateHistoryMixin, ListCreateAPIView):
    serializer_class = RouteHistoryReadSerializer
    pagination_class = HistoryPagination

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return RouteHistorySession.objects.none()
        return RouteHistorySession.objects.filter(user=self.request.user, deleted_at=None).order_by(
            "-started_at", "-id"
        )

    @extend_schema(
        tags=["Histórico de rotas"],
        summary="Consultar minhas sessões privadas de navegação",
        description="Paginado. Visitas e cálculos de prévia não criam sessões.",
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)

    @extend_schema(
        tags=["Histórico de rotas"],
        summary="Registrar início real da navegação autorizada",
        description="UUID idempotente por conta. Tempos de servidor; origem opcional aproximada a 0,01 grau.",
        request=RouteHistoryStartSerializer,
        responses={
            200: RouteHistoryReadSerializer,
            201: RouteHistoryReadSerializer,
            400: ErroSerializer,
            403: ErroSerializer,
            409: ErroSerializer,
            410: ErroSerializer,
        },
    )
    def post(self, request, *args, **kwargs):
        serializer = RouteHistoryStartSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        values = dict(serializer.validated_data)
        with transaction.atomic():
            owner = locked_owner(request)
            authorize_write(owner, values)
            previous = (
                RouteHistorySession.objects.select_for_update()
                .filter(user=owner, session_id=values["session_id"])
                .first()
            )
            if previous is not None:
                if previous.deleted_at is not None:
                    raise HistoryGone()
                immutable = [
                    "destination_name",
                    "destination_source",
                    "latitude",
                    "longitude",
                    "local_id",
                    "external_id",
                ]
                if any(
                    getattr(previous, key) != values.get(key, "" if key == "external_id" else None) for key in immutable
                ):
                    raise HistoryConflict("Uma sessão existente não pode receber outro destino.")
                return Response(RouteHistoryReadSerializer(previous).data)
            local_id = values.get("local_id")
            if local_id is not None:
                get_object_or_404(Local, pk=local_id)
            values.pop("event")
            record = RouteHistorySession.objects.create(
                user=owner,
                started_at=timezone.now(),
                status="in_progress",
                last_event="started",
                **approximate_origin(values)
            )
        return Response(RouteHistoryReadSerializer(record).data, status=201)


class RouteHistoryDetailAPIView(PrivateHistoryMixin, APIView):
    serializer_class = RouteHistoryReadSerializer

    def own_record(self, request, session_id, locking=False):
        rows = RouteHistorySession.objects.select_for_update() if locking else RouteHistorySession.objects
        record = get_object_or_404(rows, user=request.user, session_id=session_id)
        if record.deleted_at is not None:
            raise HistoryGone()
        return record

    @extend_schema(
        tags=["Histórico de rotas"],
        summary="Consultar uma sessão própria",
        responses={200: RouteHistoryReadSerializer, 404: ErroSerializer, 410: ErroSerializer},
    )
    def get(self, request, session_id):
        return Response(RouteHistoryReadSerializer(self.own_record(request, session_id)).data)

    @extend_schema(
        tags=["Histórico de rotas"],
        summary="Registrar evento da mesma sessão",
        description="Recálculo preserva UUID. Eventos fora de ordem e regressão de estados finais são recusados.",
        request=RouteHistoryEventSerializer,
        responses={
            200: RouteHistoryReadSerializer,
            400: ErroSerializer,
            403: ErroSerializer,
            404: ErroSerializer,
            409: ErroSerializer,
            410: ErroSerializer,
        },
    )
    def patch(self, request, session_id):
        serializer = RouteHistoryEventSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        values = dict(serializer.validated_data)
        event = values.pop("event")
        index = values.pop("event_index")
        values.pop("arrival_confirmed")
        with transaction.atomic():
            owner = locked_owner(request)
            authorize_write(owner, values)
            record = self.own_record(request, session_id, locking=True)
            if index == record.event_index and event == record.last_event:
                return Response(RouteHistoryReadSerializer(record).data)
            if index <= record.event_index:
                raise HistoryConflict()
            next_status = {
                ("in_progress", "recalculated"): "in_progress",
                ("interrupted", "recalculated"): "interrupted",
                ("in_progress", "interrupted"): "interrupted",
                ("interrupted", "resumed"): "in_progress",
                ("in_progress", "arrived"): "completed",
                ("in_progress", "cancelled"): "cancelled",
                ("interrupted", "cancelled"): "cancelled",
            }.get((record.status, event))
            if next_status is None:
                raise HistoryConflict("Transição de navegação inválida.")
            values.pop("consent_revision")
            for field, value in approximate_origin(values).items():
                setattr(record, field, value)
            record.status, record.event_index, record.last_event = next_status, index, event
            record.ended_at = timezone.now() if next_status in {"completed", "cancelled"} else None
            record.save()
        return Response(RouteHistoryReadSerializer(record).data)

    @extend_schema(
        tags=["Histórico de rotas"],
        summary="Apagar uma sessão e impedir restauração tardia",
        request=None,
        responses={204: None, 404: ErroSerializer, 410: ErroSerializer},
    )
    def delete(self, request, session_id):
        with transaction.atomic():
            locked_owner(request)
            record = self.own_record(request, session_id, locking=True)
            for field, value in erase_values().items():
                setattr(record, field, value)
            record.save()
        return Response(status=204)


class RouteHistoryClearAPIView(PrivateHistoryMixin, APIView):
    serializer_class = RouteHistoryPreferencesReadSerializer

    @extend_schema(
        tags=["Histórico de rotas"],
        summary="Apagar meu histórico e invalidar gravações pendentes",
        request=None,
        responses={200: RouteHistoryPreferencesReadSerializer},
    )
    def delete(self, request):
        with transaction.atomic():
            owner = locked_owner(request)
            RouteHistorySession.objects.filter(user=owner, deleted_at=None).update(**erase_values())
            owner.route_history_revision += 1
            owner.save(update_fields=["route_history_revision"])
        return Response(history_preferences(owner))


class RouteHistoryOriginsAPIView(PrivateHistoryMixin, APIView):
    serializer_class = RouteHistoryPreferencesReadSerializer

    @extend_schema(
        tags=["Histórico de rotas"],
        summary="Remover origens salvas sem apagar os destinos",
        request=None,
        responses={200: RouteHistoryPreferencesReadSerializer},
    )
    def delete(self, request):
        with transaction.atomic():
            owner = locked_owner(request)
            RouteHistorySession.objects.filter(user=owner, deleted_at=None).update(
                origin_latitude=None, origin_longitude=None
            )
            owner.route_history_revision += 1
            owner.save(update_fields=["route_history_revision"])
        return Response(history_preferences(owner))
