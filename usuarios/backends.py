from django.contrib.auth.backends import BaseBackend
from django.contrib.auth.hashers import check_password
from .models import Usuario

class UsuarioBackend(BaseBackend):
    def authenticate(self, request, nome=None, password=None, **kwargs):
        print(f"Autenticando usuário: nome={nome}, senha={password}")  # Log para depuração
        try:
            usuario = Usuario.objects.get(nome=nome)
            print(f"Usuário encontrado: {usuario.nome}")
        except Usuario.DoesNotExist:
            print("Usuário não encontrado.")
            return None

        if usuario.check_password(password):
            print("Senha correta.")
            return usuario
        else:
            print("Senha incorreta.")
            return None

    def get_user(self, user_id):
        try:
            return Usuario.objects.get(pk=user_id)
        except Usuario.DoesNotExist:
            return None

    def get_user(self, user_id):
        try:
            return Usuario.objects.get(pk=user_id)
        except Usuario.DoesNotExist:
            return None
        
    def check_password(self, raw_password):
        from django.contrib.auth.hashers import check_password
        return check_password(raw_password, self.password)