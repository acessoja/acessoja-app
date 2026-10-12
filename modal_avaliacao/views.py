from django.db import transaction
from django.db.models import Q
from drf_spectacular.utils import OpenApiParameter, extend_schema, extend_schema_view
from rest_framework import status, viewsets
from rest_framework.exceptions import APIException, PermissionDenied, ValidationError
from rest_framework.permissions import IsAuthenticatedOrReadOnly
from rest_framework.throttling import UserRateThrottle
from rest_framework.response import Response
from usuarios.models import Usuario
from locais.models import Local
from locais.serializers import LocalSerializer
from .models import ModalAvaliacao
from .serializers import ContributionFeedbackSerializer, ModalAvaliacaoSerializer


class ReviewThrottle(UserRateThrottle):
    rate = "30/min"


class DuplicateReview(APIException):
    status_code = status.HTTP_409_CONFLICT
    default_detail = "Você já avaliou este local. Edite a avaliação existente."


@extend_schema_view(
    list=extend_schema(parameters=[OpenApiParameter("local_id", int), OpenApiParameter("ordering", str)])
)
@extend_schema(tags=["Avaliações"])
class ModalAvaliacaoViewSet(viewsets.ModelViewSet):
    queryset = ModalAvaliacao.objects.select_related("user", "local").all()
    serializer_class = ModalAvaliacaoSerializer
    permission_classes = [IsAuthenticatedOrReadOnly]
    throttle_classes = [ReviewThrottle]

    def get_throttles(self):
        return super().get_throttles() if self.action in ["create", "update", "partial_update", "destroy"] else []

    def get_queryset(self):
        qs = self.queryset.filter(is_current=True)
        if self.action in ["list", "retrieve"]:
            public = Q(is_valid=True, user__mostrar_avaliacoes=True)
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

    def _authorize(self, evaluation):
        user = self.request.user
        if evaluation.user_id != user.pk and not (user.is_staff and user.is_superuser):
            raise PermissionDenied("Somente o autor ou um administrador pode alterar esta avaliação.")

    @transaction.atomic
    def perform_create(self, serializer):
        user = Usuario.objects.select_for_update().get(pk=self.request.user.pk)
        local = serializer.validated_data["local"]
        if ModalAvaliacao.objects.filter(user=user, local=local, is_current=True).exists():
            raise DuplicateReview()
        complete = all(f"pergunta_{i}" in serializer.validated_data for i in range(1, 5))
        answers = {f"pergunta_{i}": serializer.validated_data.get(f"pergunta_{i}", "Não sei") for i in range(1, 5)}
        evaluation = serializer.save(user=user, verified_author=True, survey_completed=complete, **answers)
        self._last_evaluation = evaluation
        self._update_flags(evaluation)

    @transaction.atomic
    def perform_update(self, serializer):
        self._authorize(serializer.instance)
        Usuario.objects.select_for_update().get(pk=serializer.instance.user_id)
        locked = ModalAvaliacao.objects.select_for_update().get(pk=serializer.instance.pk)
        serializer.instance = locked
        changed_comment = serializer.validated_data.get("comentario", locked.comentario) != locked.comentario
        complete = locked.survey_completed or all(f"pergunta_{i}" in serializer.validated_data for i in range(1, 5))
        evaluation = serializer.save(
            comment_verified=False if changed_comment else locked.comment_verified, survey_completed=complete
        )
        self._last_evaluation = evaluation
        self._update_flags(evaluation)

    @transaction.atomic
    def perform_destroy(self, instance):
        self._authorize(instance)
        Usuario.objects.select_for_update().get(pk=instance.user_id)
        instance.delete()

    def _update_flags(self, evaluation):
        flags = ["rampa_acesso", "banheiro_acessivel", "mesa_acessivel", "cao_guia"]
        updates = {flag: True for i, flag in enumerate(flags, 1) if getattr(evaluation, f"pergunta_{i}") == "Sim"}
        if updates:
            Local.objects.filter(pk=evaluation.local_id).update(**updates)

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

        Usuario.objects.select_for_update().get(pk=request.user.pk)
        before = impact(request.user)["points"]
        response = super().create(request, *args, **kwargs)
        after = impact(request.user)["points"]
        result = self._contribution_result(self._last_evaluation, "created", before, after)
        response.data["points_delta"] = result["points_delta"]
        response.data["contribution_result"] = result
        return response

    @transaction.atomic
    def update(self, request, *args, **kwargs):
        from contribuicoes.services import impact

        evaluation = self.get_object()
        self._authorize(evaluation)
        author = Usuario.objects.select_for_update().get(pk=evaluation.user_id)
        before = impact(author)["points"]
        response = super().update(request, *args, **kwargs)
        after = impact(author)["points"]
        result = self._contribution_result(self._last_evaluation, "updated", before, after)
        response.data["points_delta"] = result["points_delta"]
        response.data["contribution_result"] = result
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
