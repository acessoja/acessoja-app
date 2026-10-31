from django.http import FileResponse
from django.db.models import F, Q
from acessoja.api_schema import ErroSerializer
from drf_spectacular.types import OpenApiTypes
from usuarios.account_serializers import ReauthenticationSerializer
from django.shortcuts import get_object_or_404
from drf_spectacular.utils import extend_schema, OpenApiParameter
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.generics import ListAPIView
from rest_framework.pagination import PageNumberPagination
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from evidencias.moderation import allowed
from evidencias.views import PrivateResponseMixin
from usuarios.security_throttles import SecurityThrottle
from .models import ImageAsset, ImageOperation
from .permissions import can_read_asset, public_photos, visible_photos
from .serializers import (
    AvatarInput,
    AvatarRead,
    AvatarUpload,
    ImageOperationRead,
    PhotoDescription,
    PhotoMutation,
    PhotoRead,
    PhotoUpload,
)
from .services import (
    change_description,
    operation_document,
    remove_avatar,
    remove_photo,
    upload_image,
)
from .storage import image_storage

MEDIA_ERRORS = {code: ErroSerializer for code in (400, 401, 403, 404, 409, 413, 422, 429, 503)}


def avatar_document(user):
    asset = user.avatar_asset
    return {
        "version": user.avatar_version,
        "has_avatar": bool(user.foto_perfil),
        "foto_perfil": user.foto_perfil or "",
        "image_url": f"/api/midia/arquivos/{asset.pk}/image/" if asset else None,
        "thumb_url": f"/api/midia/arquivos/{asset.pk}/thumb/" if asset else None,
    }


def photo_document(photo, user):
    version, own = (
        photo.current_revision,
        user.is_authenticated and photo.owner_id == user.pk,
    )
    return {
        "id": photo.pk,
        "review_id": photo.review_id,
        "local_id": photo.review.local_id,
        "revision": version.pk,
        "state": version.state,
        "description": version.description,
        "submitted_at": version.submitted_at,
        "mime_type": version.asset.mime_type,
        "width": version.asset.width,
        "height": version.asset.height,
        "image_url": f"/api/midia/arquivos/{version.asset_id}/image/",
        "thumb_url": f"/api/midia/arquivos/{version.asset_id}/thumb/",
        "can_delete": own,
        "rejection_reason": (
            (
                version.decisions.filter(action="reject")
                .order_by("-created_at")
                .values_list("author_reason", flat=True)
                .first()
                or "context"
            )
            if own and version.state == "rejected"
            else None
        ),
        "can_moderate": allowed(user),
        "can_report": not own
        and version.state == "approved"
        and version.asset.state == "ready"
        and photo.review.is_current
        and photo.review.is_valid
        and photo.review.user.is_active
        and photo.review.user.mostrar_avaliacoes,
    }


class AvatarView(PrivateResponseMixin, APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    throttle_classes = [SecurityThrottle]
    security_scope = "avatar_change"

    def get_throttles(self):
        return [] if self.request.method in {"GET", "HEAD"} else super().get_throttles()

    @extend_schema(tags=["Mídia"], responses={200: AvatarRead, **MEDIA_ERRORS})
    def get(self, request):
        return Response(AvatarRead(avatar_document(request.user)).data)

    @extend_schema(
        tags=["Mídia"],
        request=AvatarUpload,
        responses={200: ImageOperationRead, 202: ImageOperationRead, **MEDIA_ERRORS},
    )
    def put(self, request):
        data = AvatarUpload(data=request.data)
        data.is_valid(raise_exception=True)
        op = upload_image(request, data.validated_data, "avatar")
        return Response(
            ImageOperationRead(operation_document(op)).data,
            status=200 if op.state == "committed" else 202,
        )

    @extend_schema(
        tags=["Mídia"],
        request=AvatarInput,
        responses={200: ImageOperationRead, **MEDIA_ERRORS},
    )
    def delete(self, request):
        data = AvatarInput(data=request.data)
        data.is_valid(raise_exception=True)
        return Response(ImageOperationRead(operation_document(remove_avatar(request, data.validated_data))).data)


class PhotoUploadView(PrivateResponseMixin, APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]
    throttle_classes = [SecurityThrottle]
    security_scope = "image_upload"

    @extend_schema(
        tags=["Mídia"],
        request=PhotoUpload,
        responses={201: ImageOperationRead, 202: ImageOperationRead, **MEDIA_ERRORS},
    )
    def post(self, request):
        data = PhotoUpload(data=request.data)
        data.is_valid(raise_exception=True)
        op = upload_image(request, data.validated_data, "photo")
        return Response(
            ImageOperationRead(operation_document(op)).data,
            status=201 if op.state == "committed" else 202,
        )


class OperationView(PrivateResponseMixin, APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(tags=["Mídia"], responses={200: ImageOperationRead, **MEDIA_ERRORS})
    def get(self, request, operation_id):
        op = get_object_or_404(ImageOperation, operation_id=operation_id, owner=request.user)
        return Response(ImageOperationRead(operation_document(op)).data)


class PhotoPagination(PageNumberPagination):
    page_size = 20


class PhotoListView(PrivateResponseMixin, ListAPIView):
    permission_classes = [AllowAny]
    serializer_class = PhotoRead
    pagination_class = PhotoPagination

    @extend_schema(
        tags=["Mídia"],
        parameters=[
            OpenApiParameter("review_id", int),
            OpenApiParameter("local_id", int),
        ],
        responses={200: PhotoRead(many=True), **MEDIA_ERRORS},
    )
    def get(self, request):
        if set(request.query_params) - {"review_id", "local_id", "page", "format"}:
            raise ValidationError("Filtros não permitidos.")
        if ("review_id" in request.query_params) == ("local_id" in request.query_params):
            raise ValidationError("Informe avaliação ou local, sem combinar os dois.")
        field = "review_id" if "review_id" in request.query_params else "local_id"
        try:
            identifier = int(request.query_params[field])
            if identifier < 1:
                raise ValueError
        except ValueError:
            raise ValidationError("Identificador inválido.") from None
        rows = (
            visible_photos(request.user)
            if field == "review_id"
            else public_photos().select_related("review__user", "current_revision__asset")
        )
        rows = rows.filter(**{field if field == "review_id" else "review__local_id": identifier}).order_by(
            "-created_at", "pk"
        )
        page = self.paginate_queryset(rows)
        return self.get_paginated_response(
            PhotoRead([photo_document(row, request.user) for row in page], many=True).data
        )


class PhotoView(PrivateResponseMixin, APIView):
    permission_classes = [IsAuthenticated]

    def get_permissions(self):
        return [AllowAny()] if self.request.method in {"GET", "HEAD"} else super().get_permissions()

    @extend_schema(tags=["Mídia"], responses={200: PhotoRead, **MEDIA_ERRORS})
    def get(self, request, photo_id):
        photo = get_object_or_404(visible_photos(request.user), pk=photo_id)
        return Response(PhotoRead(photo_document(photo, request.user)).data)

    @extend_schema(
        tags=["Mídia"],
        request=PhotoDescription,
        responses={200: ImageOperationRead, **MEDIA_ERRORS},
    )
    def patch(self, request, photo_id):
        data = PhotoDescription(data=request.data)
        data.is_valid(raise_exception=True)
        return Response(
            ImageOperationRead(operation_document(change_description(request, photo_id, data.validated_data))).data
        )

    @extend_schema(
        tags=["Mídia"],
        request=PhotoMutation,
        responses={200: ImageOperationRead, **MEDIA_ERRORS},
    )
    def delete(self, request, photo_id):
        data = PhotoMutation(data=request.data)
        data.is_valid(raise_exception=True)
        return Response(
            ImageOperationRead(operation_document(remove_photo(request, photo_id, data.validated_data))).data
        )


class ImageFileView(PrivateResponseMixin, APIView):
    from acessoja.authentication import ExpiringTokenAuthentication
    from rest_framework.authentication import SessionAuthentication

    authentication_classes = [ExpiringTokenAuthentication, SessionAuthentication]
    permission_classes = [AllowAny]

    @extend_schema(
        tags=["Mídia"],
        responses={
            (200, "image/jpeg"): OpenApiTypes.BINARY,
            401: ErroSerializer,
            404: ErroSerializer,
        },
    )
    def get(self, request, asset_id, variant):
        if variant not in {"image", "thumb"} or request.query_params:
            raise NotFound()
        asset = get_object_or_404(ImageAsset, pk=asset_id)
        if not can_read_asset(asset, request.user):
            raise NotFound()
        key = asset.image_key if variant == "image" else asset.thumb_key
        try:
            source = image_storage().open(key, "rb")
        except OSError:
            raise NotFound("Imagem temporariamente indisponível.") from None
        response = FileResponse(source, content_type="image/jpeg", filename="imagem.jpg")
        response["X-Content-Type-Options"] = "nosniff"
        response["Content-Security-Policy"] = "default-src 'none'; sandbox"
        return response

    def head(self, request, asset_id, variant):
        return self.get(request, asset_id, variant)


class ImagesExportView(PrivateResponseMixin, APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [SecurityThrottle]
    security_scope = "export"

    @extend_schema(
        tags=["Privacidade"],
        request=ReauthenticationSerializer,
        responses={(200, "application/zip"): OpenApiTypes.BINARY, **MEDIA_ERRORS},
    )
    def post(self, request):
        import json
        import tempfile
        import zipfile
        from django.conf import settings
        from django.db import transaction
        from usuarios.account_services import locked_request_user, reauthenticate

        data = ReauthenticationSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        with transaction.atomic():
            user = locked_request_user(request)
            reauthenticate(user, data.validated_data["current_password"])
            assets = list(
                ImageAsset.objects.filter(owner=user, state="ready")
                .filter(
                    Q(
                        photo_revisions__photo__owner=user,
                        photo_revisions__photo__deleted_at=None,
                        photo_revisions__photo__current_revision=F("photo_revisions__id"),
                    )
                    | Q(pk=user.avatar_asset_id)
                )
                .distinct()
            )
        archive = tempfile.SpooledTemporaryFile(max_size=1024 * 1024)
        try:
            total, manifest = 0, []
            with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
                storage = image_storage()
                for asset in assets:
                    if not can_read_asset(asset, request.user):
                        raise NotFound()
                    for variant, key in [
                        ("image", asset.image_key),
                        ("thumb", asset.thumb_key),
                    ]:
                        with storage.open(key, "rb") as source:
                            content = source.read(settings.PRIVACY_EXPORT_MAX_BYTES + 1)
                        total += len(content)
                        if total > settings.PRIVACY_EXPORT_MAX_BYTES:
                            raise ValidationError(
                                "Arquivos excedem a exportação imediata. Solicite exportação assistida."
                            )
                        bundle.writestr(f"{asset.pk}/{variant}.jpg", content)
                    manifest.append(
                        {
                            "asset": str(asset.pk),
                            "purpose": asset.purpose,
                            "sha256": asset.sha256,
                        }
                    )
                bundle.writestr(
                    "manifest.json",
                    json.dumps({"format": "acessoja.own-images.v1", "images": manifest}),
                )
            with transaction.atomic():
                user = locked_request_user(request)
                reauthenticate(user, data.validated_data["current_password"])
                for asset in assets:
                    asset.refresh_from_db()
                    if not can_read_asset(asset, user):
                        raise NotFound()
            archive.seek(0)
            return FileResponse(
                archive,
                content_type="application/zip",
                as_attachment=True,
                filename="acessoja-minhas-imagens.zip",
            )
        except Exception:
            archive.close()
            raise
