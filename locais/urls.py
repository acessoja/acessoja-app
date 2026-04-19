from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import LocalViewSet

router = DefaultRouter()
router.register(r'locais', LocalViewSet, basename='local')

urlpatterns = [
    path('', include(router.urls)),
]
