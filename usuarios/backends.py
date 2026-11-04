from django.contrib.auth.backends import BaseBackend
from django.core.exceptions import PermissionDenied
from .models import Usuario


class UsuarioBackend(BaseBackend):
    def authenticate(self, request, nome=None, password=None, **kwargs):
        nome = nome or kwargs.get("username")
        password = password or kwargs.get("password")
        if not nome or not password:
            return None
        try:
            usuario = Usuario.objects.get(nome=nome)
        except Usuario.DoesNotExist:
            Usuario().set_password(password)
            raise PermissionDenied() from None

        if usuario.check_password(password) and usuario.is_active:
            return usuario
        raise PermissionDenied()

    def get_user(self, user_id):
        try:
            return Usuario.objects.get(pk=user_id, is_active=True)
        except Usuario.DoesNotExist:
            return None

    def check_password(self, raw_password):
        from django.contrib.auth.hashers import check_password

        return check_password(raw_password, self.password)
