from django.contrib.auth.backends import BaseBackend
from .models import Usuario


class UsuarioBackend(BaseBackend):
    def authenticate(self, request, nome=None, password=None, **kwargs):
        try:
            usuario = Usuario.objects.get(nome=nome)
        except Usuario.DoesNotExist:
            return None

        if usuario.check_password(password):
            return usuario
        else:
            return None

    def get_user(self, user_id):
        try:
            return Usuario.objects.get(pk=user_id)
        except Usuario.DoesNotExist:
            return None

    def check_password(self, raw_password):
        from django.contrib.auth.hashers import check_password
        return check_password(raw_password, self.password)
