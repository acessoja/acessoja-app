from django.urls import path
from .views import (
    AvatarView,
    ImagesExportView,
    ImageFileView,
    OperationView,
    PhotoListView,
    PhotoUploadView,
    PhotoView,
)

urlpatterns = [
    path("usuarios/me/images-export/", ImagesExportView.as_view(), name="own-images-export"),
    path("usuarios/me/avatar/", AvatarView.as_view(), name="my-avatar"),
    path("midia/fotos/", PhotoListView.as_view(), name="review-photos"),
    path("midia/fotos/enviar/", PhotoUploadView.as_view(), name="photo-upload"),
    path("midia/fotos/<uuid:photo_id>/", PhotoView.as_view(), name="photo-change"),
    path("midia/operacoes/<uuid:operation_id>/", OperationView.as_view(), name="image-operation"),
    path("midia/arquivos/<uuid:asset_id>/<str:variant>/", ImageFileView.as_view(), name="protected-image"),
]
