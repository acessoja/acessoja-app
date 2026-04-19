from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import ModalAvaliacaoViewSet

# Registrar apenas uma vez no DefaultRouter
router = DefaultRouter()
router.register(r'modal-avaliacoes', ModalAvaliacaoViewSet, basename='modal-avaliacao')

urlpatterns = [
    path('', include(router.urls)),  # Inclui as rotas automaticamente geradas
]
