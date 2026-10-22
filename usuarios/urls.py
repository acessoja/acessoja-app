from django.urls import path
from . import views
from .views import UsuarioPerfilAPIView, UsuarioSenhaAPIView, UsuarioFotoAPIView
from .accessibility_preferences import AccessibilityPreferencesAPIView
from .route_history_preferences import RouteHistoryPreferencesAPIView
from .privacy_views import PrivacyDocumentAPIView, AccountExportAPIView, AccountDeleteAPIView

urlpatterns = [
    path('me/privacy/', PrivacyDocumentAPIView.as_view(), name='my-privacy'),
    path('me/data-export/', AccountExportAPIView.as_view(), name='my-data-export'),
    path('me/delete-account/', AccountDeleteAPIView.as_view(), name='my-delete-account'),
    path('me/route-history-preferences/', RouteHistoryPreferencesAPIView.as_view(), name='route-history-preferences'),
    path('me/accessibility-preferences/', AccessibilityPreferencesAPIView.as_view(), name='accessibility-preferences'),
    path('logout/', views.LogoutAPIView.as_view(), name='logout'),
    path('perfil/', UsuarioPerfilAPIView.as_view(), name='usuario-perfil'),
    path('alterar-senha/', UsuarioSenhaAPIView.as_view(), name='usuario-alterar-senha'),
    path('foto/', UsuarioFotoAPIView.as_view(), name='usuario-foto'),
]
