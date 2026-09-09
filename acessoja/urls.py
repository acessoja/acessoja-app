from django.urls import path, include
from django.contrib import admin
from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularRedocView,
    SpectacularSwaggerView,
)
from . import views
from .views import LoginAPIView

urlpatterns = [
    path('home/', views.home, name='home'),  # Página inicial
    path('admin/', admin.site.urls),

    # ---------------------------------------------------------------
    # Documentacao viva da API — gerada a partir do codigo
    # ---------------------------------------------------------------
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
    path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
    path('api/redoc/', SpectacularRedocView.as_view(url_name='schema'), name='redoc'),

    path('auth/', include('djoser.urls')),
    path('auth/', include('djoser.urls.authtoken')),
    path('api/', include('locais.urls')),
    path('api/login/', LoginAPIView.as_view(), name='api-login'),
    path('api/usuarios/', include('usuarios.urls')),
    # URL para a tela de Modal de Avaliações
    path('api/avaliacoes/', include('modal_avaliacao.urls')),
]
