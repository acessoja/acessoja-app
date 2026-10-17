from rest_framework.routers import DefaultRouter
from .views import FavoritoViewSet

router = DefaultRouter()
router.register("", FavoritoViewSet, basename="favorito")
urlpatterns = router.urls
