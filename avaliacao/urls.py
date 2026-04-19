from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import AvaliacaoLocalViewSet

router = DefaultRouter()
router.register(r'avaliacoes', AvaliacaoLocalViewSet, basename='avaliacao-local')

urlpatterns = [
    path('api/', include(router.urls)),
]
