from django.conf import settings
from django.core.files.uploadhandler import FileUploadHandler, TemporaryFileUploadHandler
from django.http import JsonResponse
from .exceptions import ImageTooLarge


class ImageByteLimitHandler(FileUploadHandler):
    def new_file(self, *args, **kwargs):
        super().new_file(*args, **kwargs)
        self.received = 0

    def receive_data_chunk(self, raw_data, start):
        self.received += len(raw_data)
        if self.received > settings.IMAGE_MAX_BYTES:
            raise ImageTooLarge()
        return raw_data

    def file_complete(self, file_size):
        return None


class ImageUploadPolicyMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.path.startswith(("/api/midia/", "/api/usuarios/me/avatar/")) and request.method in {
            "PUT",
            "POST",
        }:
            try:
                size = int(request.META.get("CONTENT_LENGTH") or 0)
            except ValueError:
                size = settings.IMAGE_REQUEST_MAX_BYTES + 1
            if size > settings.IMAGE_REQUEST_MAX_BYTES:
                return JsonResponse({"detail": "Requisição de imagem excede 6 MB."}, status=413)
            request.upload_handlers = [ImageByteLimitHandler(request), TemporaryFileUploadHandler(request)]
        return self.get_response(request)
