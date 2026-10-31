"""Small durable receipts; no copied draft, comment, credentials, or image bytes."""

from rest_framework import serializers
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from evidencias.exceptions import RevisionConflict
from midia.services import signature
from .models import ReviewOperation


class ReviewOperationRead(serializers.Serializer):
    operation_id = serializers.UUIDField()
    state = serializers.CharField()
    review_id = serializers.IntegerField(allow_null=True)
    revision = serializers.UUIDField()
    contribution_result = serializers.DictField()


def document(op):
    return {
        "operation_id": op.operation_id,
        "state": "committed",
        "review_id": op.review_id,
        "revision": op.result_revision,
        "contribution_result": op.feedback,
    }


def begin(view, request):
    if "operation_id" not in request.data:
        return None, None, None
    identifier = serializers.UUIDField().run_validation(request.data["operation_id"])
    if not isinstance(request.data, dict):
        raise ValidationError("Envie um objeto JSON.")
    digest = signature({"method": request.method, "id": view.kwargs.get("pk"), "body": request.data})
    op = ReviewOperation.objects.filter(owner=request.user, operation_id=identifier).select_related("review").first()
    if op:
        if op.signature != digest:
            raise RevisionConflict("Identidade de operação já usada com outros dados.")
        if not op.review_id:
            return (
                identifier,
                digest,
                Response({"detail": "A operação foi confirmada; a avaliação foi removida."}, status=410),
            )
        data = view.get_serializer(op.review).data
        data.update(
            contribution_result=op.feedback,
            points_delta=op.feedback.get("points_delta", 0),
            operation_revision=str(op.result_revision),
            replayed=True,
        )
        return identifier, digest, Response(data)
    return identifier, digest, None


def record(owner, identifier, digest, review, feedback):
    if identifier:
        ReviewOperation.objects.create(
            owner=owner,
            operation_id=identifier,
            signature=digest,
            review=review,
            result_revision=review.content_revision,
            feedback=feedback,
        )
