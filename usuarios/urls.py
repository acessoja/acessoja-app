from django.urls import path
from . import views
from .views import UsuarioPerfilAPIView, UsuarioSenhaAPIView, UsuarioFotoAPIView
from .accessibility_preferences import AccessibilityPreferencesAPIView
from .route_history_preferences import RouteHistoryPreferencesAPIView

urlpatterns = [
    path('me/route-history-preferences/', RouteHistoryPreferencesAPIView.as_view(), name='route-history-preferences'),
    path('me/accessibility-preferences/', AccessibilityPreferencesAPIView.as_view(), name='accessibility-preferences'),
    path('logout/', views.LogoutAPIView.as_view(), name='logout'),
    path('perfil/', UsuarioPerfilAPIView.as_view(), name='usuario-perfil'),
    path('alterar-senha/', UsuarioSenhaAPIView.as_view(), name='usuario-alterar-senha'),
    path('foto/', UsuarioFotoAPIView.as_view(), name='usuario-foto'),
]
