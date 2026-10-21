from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import LocalViewSet, VisitaRecenteViewSet
from .route_history_views import (
    RouteHistoryClearAPIView, RouteHistoryDetailAPIView, RouteHistoryListCreateAPIView, RouteHistoryOriginsAPIView,
)

from .external_views import (
    ExternalCategoriesAPIView, ExternalImportAPIView, ExternalPlacesAPIView, GeocodeAPIView,
)

from .manual_registration import ManualRegistrationAPIView
from .catalog_views import CatalogListAPIView, CatalogDetailAPIView, CatalogConfirmAPIView

router = DefaultRouter()
router.register(r'locais', LocalViewSet, basename='local')
router.register(r'visitas', VisitaRecenteViewSet, basename='visita-recente')

urlpatterns = [
    path('route-history/', RouteHistoryListCreateAPIView.as_view(), name='route-history'),
    path('route-history/clear/', RouteHistoryClearAPIView.as_view(), name='route-history-clear'),
    path('route-history/origins/', RouteHistoryOriginsAPIView.as_view(), name='route-history-origins'),
    path('route-history/<uuid:session_id>/', RouteHistoryDetailAPIView.as_view(), name='route-history-detail'),
    path('locais/cadastro-manual/', ManualRegistrationAPIView.as_view(), name='manual-registration'),
    path('locais/catalogo/', CatalogListAPIView.as_view(), name='catalog-list'),
    path('locais/catalogo/<int:poi_id>/', CatalogDetailAPIView.as_view(), name='catalog-detail'),
    path('locais/catalogo/<int:poi_id>/confirmar/', CatalogConfirmAPIView.as_view(), name='catalog-confirm'),
    path('locais/externos/', ExternalPlacesAPIView.as_view(), name='external-places'),
    path('locais/externos/categorias/', ExternalCategoriesAPIView.as_view(), name='external-categories'),
    path('locais/externos/cadastrar/', ExternalImportAPIView.as_view(), name='external-import'),
    path('locais/geocodificar/', GeocodeAPIView.as_view(), name='geocode'),
    path('', include(router.urls)),
]
