"""Independent author statements: no review, rating, or pre-existing evidence required."""

from django.db import transaction
from django.utils import timezone
from drf_spectacular.utils import extend_schema, OpenApiParameter
from rest_framework import serializers
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from acessoja.accessibility_catalog import RESOURCE_IDS
from locais.models import Local
from usuarios.account_services import locked_request_user
from usuarios.security_throttles import SecurityThrottle
from .capture import ANSWER_STATES, capture_batch, fingerprint
from .exceptions import RevisionConflict
from .models import EvidenceOperation, ResourceEvidence
from .projection import detail_document
from .serializers import ChangeEvidenceSerializer, EvidenceReadSerializer, StrictSerializer
from .views import PrivateResponseMixin, WRITE_ERRORS


class IndependentInput(ChangeEvidenceSerializer):
    revision = None
    operation_id = serializers.UUIDField()
    expected_revision = serializers.UUIDField(required=False)
    local_id = serializers.IntegerField(min_value=1)
    resource = serializers.ChoiceField(choices=RESOURCE_IDS)


class RemoveInput(StrictSerializer):
    operation_id = serializers.UUIDField()
    expected_revision = serializers.UUIDField()


class ObservationReceipt(serializers.Serializer):
    operation_id = serializers.UUIDField()
    evidence_id = serializers.UUIDField(allow_null=True)
    revision = serializers.UUIDField()
    withdrawn = serializers.BooleanField()
    state = serializers.CharField()


class OwnObservationRead(EvidenceReadSerializer):
    withdrawn = serializers.BooleanField()
    superseded = serializers.BooleanField()
    is_valid = serializers.BooleanField()


class OwnObservationList(serializers.Serializer):
    results = OwnObservationRead(many=True)


def receipt(op):
    return {
        "operation_id": op.operation_id,
        "evidence_id": op.evidence_id,
        "revision": op.result_revision,
        "withdrawn": op.withdrawn,
        "state": "committed",
    }


def repeat(user, values, action, identifier=None):
    from midia.services import signature

    digest = signature({"action": action, "evidence": identifier, **values})
    prior = EvidenceOperation.objects.filter(owner=user, operation_id=values["operation_id"]).first()
    if prior and prior.signature != digest:
        raise RevisionConflict("Identidade de operação já usada com outros dados.")
    return prior, digest


@transaction.atomic
def write_observation(request, values):
    user = locked_request_user(request)
    prior, digest = repeat(user, values, "write")
    if prior:
        return prior
    local = Local.objects.select_for_update().filter(pk=values["local_id"]).first()
    if local is None:
        raise NotFound("Selecione um local interno válido; vincule o local externo antes de contribuir.")
    key = f"observation:{user.pk}:local:{local.pk}:{values['resource']}"
    current = ResourceEvidence.objects.filter(key=key).select_related("current_revision").first()
    if current and values.get("expected_revision") != current.current_revision_id:
        raise RevisionConflict()
    if current is None and "expected_revision" in values:
        raise RevisionConflict()
    spec = {
        "key": key,
        "kind": "observation",
        "source": "user",
        "local_id": local.pk,
        "owner_id": user.pk,
        "resource": values["resource"],
        "state": ANSWER_STATES[values["value"]],
        "note": values.get("note", ""),
        "observed_at": values.get("observed_at"),
        "observed_on": values.get("observed_on"),
        "received_at": timezone.now(),
    }
    if current and not current.current_revision.is_valid and current.current_revision.fingerprint == fingerprint(spec):
        raise ValidationError("Revise o conteúdo invalidado antes de enviar uma nova versão.")
    # An explicit reassertion may supersede a survey. Merely saving unchanged
    # survey text never takes precedence over a newer independent statement.
    spec["reassert"] = bool(current and current.superseded)
    root = capture_batch([spec])[0]
    return EvidenceOperation.objects.create(
        owner=user,
        operation_id=values["operation_id"],
        signature=digest,
        evidence=root,
        result_revision=root.current_revision_id,
    )


@transaction.atomic
def remove_observation(request, identifier, values):
    user = locked_request_user(request)
    prior, digest = repeat(user, values, "remove", identifier)
    if prior:
        return prior
    root = ResourceEvidence.objects.select_for_update().filter(pk=identifier, owner=user, kind="observation").first()
    if root is None:
        raise NotFound()
    if root.current_revision_id != values["expected_revision"]:
        raise RevisionConflict()
    root.withdrawn = True
    root.save(update_fields=["withdrawn"])
    return EvidenceOperation.objects.create(
        owner=user,
        operation_id=values["operation_id"],
        signature=digest,
        evidence=root,
        result_revision=root.current_revision_id,
        withdrawn=True,
    )


class IndependentObservationsView(PrivateResponseMixin, APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [SecurityThrottle]
    security_scope = "evidence_change"

    def get_throttles(self):
        return [] if self.request.method == "GET" else super().get_throttles()

    @extend_schema(
        tags=["Proveniência"],
        parameters=[OpenApiParameter("local_id", int, required=True)],
        responses={
            200: OwnObservationList,
            **WRITE_ERRORS,
        },
    )
    def get(self, request):
        if set(request.query_params) - {"local_id", "format"}:
            raise ValidationError("Use somente local_id; a conta vem da sessão.")
        try:
            local_id = int(request.query_params["local_id"])
        except (ValueError, KeyError):
            raise ValidationError("Informe local_id.") from None
        rows = ResourceEvidence.objects.filter(
            owner=request.user, local_id=local_id, kind="observation"
        ).select_related("current_revision")
        return Response(
            {
                "results": [
                    {
                        **detail_document(row, user=request.user),
                        "withdrawn": row.withdrawn,
                        "superseded": row.superseded,
                        "is_valid": row.current_revision.is_valid,
                    }
                    for row in rows
                    if row.current_revision_id
                ]
            }
        )

    @extend_schema(tags=["Proveniência"], request=IndependentInput, responses={200: ObservationReceipt, **WRITE_ERRORS})
    def post(self, request):
        data = IndependentInput(data=request.data)
        data.is_valid(raise_exception=True)
        return Response(receipt(write_observation(request, data.validated_data)))


class OwnObservationView(PrivateResponseMixin, APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [SecurityThrottle]
    security_scope = "evidence_change"

    @extend_schema(tags=["Proveniência"], request=RemoveInput, responses={200: ObservationReceipt, **WRITE_ERRORS})
    def delete(self, request, evidence_id):
        data = RemoveInput(data=request.data)
        data.is_valid(raise_exception=True)
        return Response(receipt(remove_observation(request, evidence_id, data.validated_data)))


class ObservationOperationView(PrivateResponseMixin, APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(tags=["Proveniência"], responses={200: ObservationReceipt, **WRITE_ERRORS})
    def get(self, request, operation_id):
        op = EvidenceOperation.objects.filter(owner=request.user, operation_id=operation_id).first()
        if op is None:
            raise NotFound()
        return Response(receipt(op))
