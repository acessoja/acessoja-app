from rest_framework.routers import DefaultRouter
from .views import EstadoPessoalViewSet, FavoritoViewSet, ListaPessoalViewSet

router = DefaultRouter()
router.register("", FavoritoViewSet, basename="favorito")
router.register("listas", ListaPessoalViewSet, basename="lista-pessoal")
router.register("estados", EstadoPessoalViewSet, basename="estado-pessoal")
urlpatterns = router.urls
