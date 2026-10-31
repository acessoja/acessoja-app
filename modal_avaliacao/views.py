from django.db import transaction
from django.db.models import Q
from drf_spectacular.utils import OpenApiExample, OpenApiParameter, extend_schema, extend_schema_view
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import APIException, NotAuthenticated, PermissionDenied, ValidationError
from rest_framework.permissions import IsAuthenticatedOrReadOnly
from rest_framework.throttling import UserRateThrottle
from rest_framework.response import Response
from usuarios.models import Usuario
from locais.models import Local
from locais.serializers import LocalSerializer
from .models import ModalAvaliacao
from .serializers import ContributionFeedbackSerializer, ModalAvaliacaoSerializer
from .questionnaire import QUESTION_IDS, catalog
from .result_serializers import QuestionnaireCatalogSerializer, AccessibilitySummarySerializer
from .operations import ReviewOperationRead, begin, document, record


class ReviewThrottle(UserRateThrottle):
    rate = "30/min"


class DuplicateReview(APIException):
    status_code = status.HTTP_409_CONFLICT
    default_detail = "Você já avaliou este local. Edite a avaliação existente."


@extend_schema_view(
    create=extend_schema(
        examples=[
            OpenApiExample(
                "Questionário de recursos v2",
                request_only=True,
                value={
                    "local": 7,
                    "estrelas": 4,
                    "comentario": "",
                    "questionnaire_version": 2,
                    "answers": dict.fromkeys(QUESTION_IDS, "unknown"),
                },
            )
        ]
    ),
    partial_update=extend_schema(
        examples=[
            OpenApiExample(
                "Atualizar e limpar um recurso",
                request_only=True,
                value={"answers": {"mesa_acessivel": "yes", "rampa_acesso": None}},
            )
        ]
    ),
    list=extend_schema(
        parameters=[
            OpenApiParameter("local_id", int),
            OpenApiParameter("ordering", str),
            OpenApiParameter("mine", str, description="1: apenas a avaliação do usuário autenticado."),
            OpenApiParameter(
                "include_history",
                str,
                description="1: incluir somente seu histórico arquivado além dos relatos públicos atuais.",
            ),
        ]
    ),
)
@extend_schema(tags=["Avaliações"])
class ModalAvaliacaoViewSet(viewsets.ModelViewSet):
    queryset = ModalAvaliacao.objects.select_related("user", "local").all()
    serializer_class = ModalAvaliacaoSerializer
    permission_classes = [IsAuthenticatedOrReadOnly]
    throttle_classes = [ReviewThrottle]

    def get_throttles(self):
        return super().get_throttles() if self.action in ["create", "update", "partial_update", "destroy"] else []

    @extend_schema(responses=ReviewOperationRead)
    @action(detail=False, methods=["get"], url_path=r"operacoes/(?P<operation_id>[0-9a-fA-F-]{36})")
    def operation(self, request, operation_id=None):
        from rest_framework import serializers
        from .models import ReviewOperation
        from rest_framework.exceptions import NotFound

        if not request.user.is_authenticated:
            raise NotAuthenticated()
        identifier = serializers.UUIDField().run_validation(operation_id)
        op = ReviewOperation.objects.filter(owner=request.user, operation_id=identifier).first()
        if op is None:
            raise NotFound()
        return Response(document(op), headers={"Cache-Control": "private, no-store"})

    def get_queryset(self):
        qs = self.queryset
        if self.request.query_params.get("mine") == "1":
            if not self.request.user.is_authenticated:
                raise NotAuthenticated("Entre para consultar sua avaliação.")
            qs = qs.filter(user=self.request.user)
        history = self.request.query_params.get("include_history") == "1"
        if not history:
            qs = qs.filter(is_current=True)
        if self.action in ["list", "retrieve"]:
            public = Q(is_current=True, is_valid=True, user__mostrar_avaliacoes=True, user__is_active=True)
            if self.request.user.is_authenticated:
                public |= Q(user=self.request.user)
            qs = qs.filter(public)
        if self.request.query_params.get("local_id"):
            try:
                local_id = int(self.request.query_params["local_id"])
            except (ValueError, TypeError):
                raise ValidationError({"local_id": "Informe um ID interno válido."})
            qs = qs.filter(local_id=local_id)
        order = "data_resposta" if self.request.query_params.get("ordering") == "oldest" else "-data_resposta"
        return qs.order_by(order, "-pk")

    def get_serializer(self, *args, **kwargs):
        if kwargs.get("many") and args:
            from locais.services.accessibility import populate_accessibility_context

            items = list(args[0])
            context = kwargs.pop("context", None) or self.get_serializer_context()
            populate_accessibility_context({row.local_id: row.local for row in items}.values(), context)
            kwargs["context"] = context
            args = (items, *args[1:])
        return super().get_serializer(*args, **kwargs)

    def _authorize(self, evaluation):
        user = self.request.user
        if evaluation.user_id != user.pk:
            raise PermissionDenied("Somente o autor pode editar ou excluir. A moderação utiliza a fila de decisões.")

    @transaction.atomic
    def perform_create(self, serializer):
        user = Usuario.objects.select_for_update().get(pk=self.request.user.pk)
        local = serializer.validated_data["local"]
        if ModalAvaliacao.objects.filter(user=user, local=local, is_current=True).exists():
            raise DuplicateReview()
        evaluation = serializer.save(user=user, verified_author=True)
        self._last_evaluation = evaluation

    @transaction.atomic
    def perform_update(self, serializer):
        self._authorize(serializer.instance)
        Usuario.objects.select_for_update().get(pk=serializer.instance.user_id)
        locked = ModalAvaliacao.objects.select_for_update().get(pk=serializer.instance.pk)
        serializer.instance = locked
        changed_comment = serializer.validated_data.get("comentario", locked.comentario) != locked.comentario
        evaluation = serializer.save(comment_verified=False if changed_comment else locked.comment_verified)
        self._last_evaluation = evaluation

    @transaction.atomic
    def perform_destroy(self, instance):
        self._authorize(instance)
        Usuario.objects.select_for_update().get(pk=instance.user_id)
        instance.delete()

    @extend_schema(responses=QuestionnaireCatalogSerializer)
    @action(detail=False, methods=["get"], url_path="questionario")
    def questionnaire(self, request):
        return Response(catalog())

    @extend_schema(
        parameters=[OpenApiParameter("local_id", int, required=True)],
        responses=AccessibilitySummarySerializer,
    )
    @action(detail=False, methods=["get"], url_path="recursos")
    def accessibility(self, request):
        try:
            local_id = int(request.query_params.get("local_id", ""))
            if local_id < 1:
                raise ValueError
        except (ValueError, TypeError):
            raise ValidationError({"local_id": "Informe um ID interno válido."})
        from evidencias.query_projection import annotate_quality, unpack_quality

        local = annotate_quality(Local.objects.filter(pk=local_id)).first()
        if local is None:
            from rest_framework.exceptions import NotFound

            raise NotFound("Local não encontrado.")
        visible = Q(is_valid=True, user__mostrar_avaliacoes=True, user__is_active=True)
        rows = (
            ModalAvaliacao.objects.filter(local_id=local_id, is_current=True)
            .filter(visible)
            .order_by("-data_resposta", "-pk")
            .values("user_id", "is_current", "is_valid", "questionnaire_version", "answers", "answer_dates")
        )
        from evidencias.questionnaire_projection import public_questionnaire

        return Response(public_questionnaire(local_id, list(rows), quality=unpack_quality(local._quality_rows)))

    def _contribution_result(self, evaluation, operation, before, after):
        delta = after - before
        restored = any(change["operation"] == "restored" for change in getattr(evaluation, "_contribution_changes", []))
        outcome = (
            "points_restored"
            if delta > 0 and restored
            else "points_granted" if delta > 0 else "points_adjusted" if delta < 0 else "no_new_points"
        )
        return {"operation": operation, "outcome": outcome, "points_delta": delta, "points": after}

    @transaction.atomic
    def create(self, request, *args, **kwargs):
        from contribuicoes.services import impact
        from usuarios.account_services import locked_request_user

        locked_request_user(request)
        identifier, digest, replay = begin(self, request)
        if replay is not None:
            return replay
        before = impact(request.user)["points"]
        response = super().create(request, *args, **kwargs)
        after = impact(request.user)["points"]
        result = self._contribution_result(self._last_evaluation, "created", before, after)
        response.data["points_delta"] = result["points_delta"]
        response.data["contribution_result"] = result
        record(request.user, identifier, digest, self._last_evaluation, result)
        return response

    @transaction.atomic
    def update(self, request, *args, **kwargs):
        from contribuicoes.services import impact
        from usuarios.account_services import locked_request_user

        locked_request_user(request)
        identifier, digest, replay = begin(self, request)
        if replay is not None:
            return replay
        evaluation = self.get_object()
        self._authorize(evaluation)
        author = Usuario.objects.select_for_update().get(pk=evaluation.user_id)
        before = impact(author)["points"]
        response = super().update(request, *args, **kwargs)
        after = impact(author)["points"]
        result = self._contribution_result(self._last_evaluation, "updated", before, after)
        response.data["points_delta"] = result["points_delta"]
        response.data["contribution_result"] = result
        record(request.user, identifier, digest, self._last_evaluation, result)
        return response

    @extend_schema(
        parameters=[OpenApiParameter("feedback", str, description="Use 1 para receber o resultado confirmado.")],
        responses={200: ContributionFeedbackSerializer, 204: None},
    )
    @transaction.atomic
    def destroy(self, request, *args, **kwargs):
        from contribuicoes.services import impact

        evaluation = self.get_object()
        self._authorize(evaluation)
        author = Usuario.objects.select_for_update().get(pk=evaluation.user_id)
        before = impact(author)["points"]
        response = super().destroy(request, *args, **kwargs)
        if request.query_params.get("feedback") != "1":
            return response
        result = self._contribution_result(evaluation, "deleted", before, impact(author)["points"])
        return Response({"points_delta": result["points_delta"], "contribution_result": result})


class LocalViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Local.objects.all()
    serializer_class = LocalSerializer
