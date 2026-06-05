from django.urls import path, include
from django.contrib import admin
from . import views
from .views import LoginAPIView

urlpatterns = [
    path('home/', views.home, name='home'),  # Página inicial
    path('admin/', admin.site.urls),
    path('auth/', include('djoser.urls')),
    path('auth/', include('djoser.urls.authtoken')),
    path('api/', include('locais.urls')),
    path('api/login/', LoginAPIView.as_view(), name='api-login'),
    path('api/usuarios/', include('usuarios.urls')),
    # URL para a tela de Modal de Avaliações
    path('api/avaliacoes/', include('modal_avaliacao.urls')),
]
