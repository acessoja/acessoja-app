from django.urls import path
from .views import UsuarioPerfilAPIView, UsuarioSenhaAPIView, UsuarioFotoAPIView

urlpatterns = [
    path('perfil/', UsuarioPerfilAPIView.as_view(), name='usuario-perfil'),
    path('alterar-senha/', UsuarioSenhaAPIView.as_view(), name='usuario-alterar-senha'),
    path('foto/', UsuarioFotoAPIView.as_view(), name='usuario-foto'),
]
