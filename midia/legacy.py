"""Validated compatibility for the old base64 endpoint; no remote URL fetching."""

import base64
import hashlib
import uuid
from django.core.files.uploadedfile import SimpleUploadedFile
from django.db import transaction
from rest_framework.exceptions import ValidationError
from evidencias.exceptions import RevisionConflict
from usuarios.account_services import locked_request_user
from .models import ImageOperation
from .services import upload_image


def update_legacy_avatar(request):
    with transaction.atomic():
        locked_request_user(request)
    raw = request.data.get("foto_perfil")
    if not isinstance(raw, str) or not raw or len(raw) > 2_000_000:
        raise ValidationError(
            "Avatar base64 inválido ou maior que o limite legado de 2 milhões de caracteres."
        )
    if raw.startswith("data:"):
        if not raw.startswith(
            ("data:image/jpeg;base64,", "data:image/png;base64,", "data:image/webp;base64,")
        ):
            raise ValidationError("Formato não suportado.")
        raw = raw.split(",", 1)[1]
    try:
        content = base64.b64decode(raw, validate=True)
    except (ValueError, TypeError):
        raise ValidationError("Base64 inválido.") from None
    if content.startswith(b"\xff\xd8\xff"):
        extension, mime = "jpg", "image/jpeg"
    elif content.startswith(b"\x89PNG\r\n\x1a\n"):
        extension, mime = "png", "image/png"
    elif content.startswith(b"RIFF") and content[8:12] == b"WEBP":
        extension, mime = "webp", "image/webp"
    else:
        raise ValidationError("Use uma imagem JPEG, PNG ou WebP válida.")
    with transaction.atomic():
        user = locked_request_user(request)
        op_id = uuid.uuid5(
            uuid.NAMESPACE_URL, f"legacy-avatar:{user.privacy_id}:{hashlib.sha256(content).hexdigest()}"
        )
        old = ImageOperation.objects.filter(owner=user, operation_id=op_id, state="committed").first()
        if old:
            if old.result_revision != user.avatar_version:
                raise RevisionConflict(
                    "Esta tentativa antiga foi substituída. Use o editor de avatar atualizado."
                )
            return old
        version = user.avatar_version
    values = {
        "operation_id": op_id,
        "expected_version": version,
        "file": SimpleUploadedFile(f"image.{extension}", content, content_type=mime),
    }
    return upload_image(request, values, "avatar")
