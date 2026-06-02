from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import LocalViewSet, VisitaRecenteViewSet

router = DefaultRouter()
router.register(r'locais', LocalViewSet, basename='local')
router.register(r'visitas', VisitaRecenteViewSet, basename='visita-recente')

urlpatterns = [
    path('', include(router.urls)),
]
