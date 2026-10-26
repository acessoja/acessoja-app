from django.db.models import Q
from drf_spectacular.utils import extend_schema
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.generics import ListAPIView, RetrieveAPIView
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from usuarios.security_throttles import SecurityThrottle
from .models import (
    ContentReport,
    EvidenceRevision,
    GUIDANCE,
    ModerationDecision,
    ResourceEvidence,
    ReviewRevision,
)
from .projection import confirmation_stats, detail_document
from .serializers import (
    ChangeEvidenceSerializer,
    ConfirmationResultSerializer,
    EvidenceQuerySerializer,
    EvidenceReadSerializer,
    ObservationSerializer,
    ReportReadSerializer,
    ReportWriteSerializer,
    RevisionRequestSerializer,
)
from .services import (
    change_evidence,
    confirm_evidence,
    create_report,
    current_public_query,
    public_target,
    reports_related,
    target_status,
)

ERROR_RESPONSE = {
    "type": "object",
    "additionalProperties": True,
    "description": "Erro com detail ou mensagens de validação por campo; sem protocolo de sucesso.",
}
READ_ERRORS = {400: ERROR_RESPONSE, 401: ERROR_RESPONSE, 404: ERROR_RESPONSE}
WRITE_ERRORS = {
    **READ_ERRORS,
    403: ERROR_RESPONSE,
    409: ERROR_RESPONSE,
    429: ERROR_RESPONSE,
    503: ERROR_RESPONSE,
}

PRIVATE = {"Cache-Control": "private, no-store", "Vary": "Authorization, Cookie"}


class EvidencePagination(PageNumberPagination):
    page_size = 20


def can_moderate(user):
    return bool(
        user
        and user.is_authenticated
        and user.is_active
        and (user.is_superuser or user.has_perm("evidencias.moderate_content"))
    )


class PrivateResponseMixin:
    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        for key, value in PRIVATE.items():
            response[key] = value
        return response


class EvidenceListView(PrivateResponseMixin, ListAPIView):
    permission_classes = [AllowAny]
    serializer_class = EvidenceReadSerializer
    pagination_class = EvidencePagination

    @extend_schema(
        tags=["Proveniência"],
        parameters=[EvidenceQuerySerializer],
        responses={200: EvidenceReadSerializer(many=True), **READ_ERRORS},
    )
    def get(self, request):
        serializer = EvidenceQuerySerializer(
            data={key: value for key, value in request.query_params.items() if key != "format"}
        )
        serializer.is_valid(raise_exception=True)
        values = serializer.validated_data
        ids = [values["local_id"]] if "local_id" in values else []
        external = [values["external_id"]] if "external_id" in values else []
        from locais.models import Local

        if ids:
            local = Local.objects.filter(pk=ids[0]).first()
            if local is None:
                raise NotFound()
            if local.osm_id:
                external.append(local.osm_id)
        elif external:
            ids.extend(Local.objects.filter(osm_id=external[0]).values_list("pk", flat=True))
        rows = current_public_query(ids, external).filter(resource=values["resource"]).order_by("key")
        page = self.paginate_queryset(rows)
        statistics = confirmation_stats(page)
        documents = [detail_document(row, statistics, request.user) for row in page]
        return self.get_paginated_response(EvidenceReadSerializer(documents, many=True).data)


class EvidenceDetailView(PrivateResponseMixin, APIView):
    permission_classes = [AllowAny]

    @extend_schema(tags=["Proveniência"], responses={200: EvidenceReadSerializer, **READ_ERRORS})
    def get(self, request, evidence_id):
        row = public_target(evidence_id)
        return Response(
            EvidenceReadSerializer(detail_document(row, confirmation_stats([row]), request.user)).data
        )


class EvidenceConfirmView(PrivateResponseMixin, APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [SecurityThrottle]
    security_scope = "evidence_confirm"

    @extend_schema(
        tags=["Proveniência"],
        request=ObservationSerializer,
        responses={200: ConfirmationResultSerializer, **WRITE_ERRORS},
    )
    def post(self, request, evidence_id):
        serializer = ObservationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return Response(
            ConfirmationResultSerializer(
                confirm_evidence(request, evidence_id, serializer.validated_data)
            ).data
        )


class EvidenceChangeView(PrivateResponseMixin, APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [SecurityThrottle]
    security_scope = "evidence_change"

    @extend_schema(
        tags=["Proveniência"],
        request=ChangeEvidenceSerializer,
        responses={200: EvidenceReadSerializer, **WRITE_ERRORS},
    )
    def post(self, request, evidence_id):
        serializer = ChangeEvidenceSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        row = change_evidence(request, evidence_id, serializer.validated_data)
        return Response(EvidenceReadSerializer(detail_document(row, user=request.user)).data)


class ReportListCreateView(PrivateResponseMixin, ListAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = ReportReadSerializer
    pagination_class = EvidencePagination

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return ContentReport.objects.none()
        if set(self.request.query_params) - {"format", "page"}:
            raise ValidationError("Consulte somente seus protocolos, sem selecionar outra conta.")
        return reports_related(ContentReport.objects.filter(reporter=self.request.user)).order_by(
            "-created_at", "protocol"
        )

    @extend_schema(tags=["Denúncias"], responses={200: ReportReadSerializer(many=True), **READ_ERRORS})
    def list(self, request, *args, **kwargs):
        page = self.paginate_queryset(self.get_queryset())
        for report in page:
            report.target_status = target_status(report)
        return self.get_paginated_response(ReportReadSerializer(page, many=True).data)

    def get_throttles(self):
        self.security_scope = "report_create"
        return [SecurityThrottle()] if self.request.method == "POST" else []

    @extend_schema(
        tags=["Denúncias"],
        request=ReportWriteSerializer,
        responses={201: ReportReadSerializer, 200: ReportReadSerializer, **WRITE_ERRORS},
    )
    def post(self, request):
        serializer = ReportWriteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        report, created = create_report(request, serializer.validated_data)
        return Response(ReportReadSerializer(report).data, status=201 if created else 200)


class OwnReportDetailView(PrivateResponseMixin, RetrieveAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = ReportReadSerializer
    lookup_field = "protocol"

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return ContentReport.objects.none()
        return reports_related(ContentReport.objects.filter(reporter=self.request.user))

    @extend_schema(tags=["Denúncias"], responses={200: ReportReadSerializer, **READ_ERRORS})
    def retrieve(self, request, *args, **kwargs):
        report = self.get_object()
        report.target_status = target_status(report)
        return Response(self.get_serializer(report).data)


class EvidenceHistoryView(PrivateResponseMixin, ListAPIView):
    permission_classes = [IsAuthenticated]
    pagination_class = EvidencePagination

    @extend_schema(
        tags=["Proveniência"],
        responses={
            200: {
                "type": "object",
                "description": "Histórico autorizado paginado: count, next, previous, results.",
            },
            **READ_ERRORS,
        },
    )
    def get(self, request, evidence_id):
        root = ResourceEvidence.objects.filter(pk=evidence_id).first()
        if root is None or root.owner_id != request.user.pk and not can_moderate(request.user):
            raise NotFound()
        page = self.paginate_queryset(EvidenceRevision.objects.filter(evidence=root).order_by("-number"))
        return self.get_paginated_response(
            [
                {
                    "revision": row.pk,
                    "number": row.number,
                    "state": row.state,
                    "note": row.note,
                    "observed_at": row.observed_at,
                    "observed_on": row.observed_on,
                    "received_at": row.received_at,
                    "is_valid": row.is_valid,
                }
                for row in page
            ]
        )


class ReviewHistoryView(PrivateResponseMixin, ListAPIView):
    permission_classes = [IsAuthenticated]
    pagination_class = EvidencePagination

    @extend_schema(
        tags=["Proveniência"],
        responses={
            200: {
                "type": "object",
                "description": "Histórico autorizado paginado: count, next, previous, results.",
            },
            **READ_ERRORS,
        },
    )
    def get(self, request, review_id):
        from modal_avaliacao.models import ModalAvaliacao

        review = ModalAvaliacao.objects.filter(pk=review_id).first()
        if review is None or review.user_id != request.user.pk and not can_moderate(request.user):
            raise NotFound()
        page = self.paginate_queryset(
            ReviewRevision.objects.filter(review=review).order_by("-captured_at", "id")
        )
        return self.get_paginated_response(
            [
                {
                    "revision": row.pk,
                    "recorded_at": row.recorded_at,
                    "original_submission_at": row.original_submission_at,
                    "content": row.payload,
                }
                for row in page
            ]
        )


class OwnRevisionRequestsView(PrivateResponseMixin, ListAPIView):
    permission_classes = [IsAuthenticated]
    pagination_class = EvidencePagination
    serializer_class = RevisionRequestSerializer

    @extend_schema(tags=["Denúncias"], responses={200: RevisionRequestSerializer(many=True), **READ_ERRORS})
    def get(self, request):
        if set(request.query_params) - {"page", "format"}:
            raise ValidationError("A identidade vem da sessão.")
        decisions = (
            ModerationDecision.objects.filter(action="request_review", report__state="revision_requested")
            .filter(Q(report__review_revision__owner=request.user) | Q(report__evidence__owner=request.user))
            .select_related(
                "report__review_revision__review__user",
                "report__evidence__owner",
                "report__evidence__current_revision",
            )
            .order_by("-created_at", "id")
        )
        page = self.paginate_queryset(decisions)
        return self.get_paginated_response(
            RevisionRequestSerializer(
                [
                    {
                        "request_id": row.pk,
                        "target_kind": row.report.target_kind,
                        "target_revision": row.target_revision,
                        "message": GUIDANCE.get(row.author_message, {}),
                        "created_at": row.created_at,
                        "target_status": target_status(row.report),
                    }
                    for row in page
                ],
                many=True,
            ).data
        )
