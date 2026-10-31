from django.conf import settings
from django.core.files.storage import FileSystemStorage
from django.core.files.base import ContentFile


class PrivateImageStorage(FileSystemStorage):
    def get_available_name(self, name, max_length=None):
        if self.exists(name):
            raise OSError("image_key_collision")
        return name


def image_storage():
    return PrivateImageStorage(
        location=settings.PRIVATE_IMAGE_ROOT,
        base_url=None,
        file_permissions_mode=0o600,
        directory_permissions_mode=0o700,
    )


def store_derivatives(asset, result):
    storage = image_storage()
    storage.save(asset.image_key, ContentFile(result["image"]))
    storage.save(asset.thumb_key, ContentFile(result["thumb"]))
