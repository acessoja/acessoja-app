"""
Testes automatizados — app: usuarios
Cobre o modelo Usuario (autenticação customizada) e os endpoints de
perfil, troca de senha e upload de foto.
"""
import pytest
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient

User = get_user_model()


@pytest.fixture
def usuario(db):
    """Cria um usuário de teste padrão."""
    return User.objects.create_user(
        nome="mariasilva",
        email="maria@acessoja.com",
        password="senha@123",
    )


@pytest.fixture
def api_client():
    return APIClient()


class TestUsuarioModel:
    """Testes do modelo Usuario e seu manager customizado."""

    def test_criacao_usuario_basico(self, db):
        """Usuario deve ser criado com os campos obrigatórios."""
        user = User.objects.create_user(
            nome="joaosouza", email="joao@acessoja.com", password="123456"
        )
        assert user.id_usuario is not None
        assert user.nome == "joaosouza"
        assert user.check_password("123456")

    def test_senha_e_armazenada_com_hash(self, usuario):
        """A senha não deve ser salva em texto plano."""
        assert usuario.password != "senha@123"
        assert usuario.check_password("senha@123")

    def test_criacao_usuario_sem_nome_levanta_erro(self, db):
        """O manager deve exigir o campo 'nome'."""
        with pytest.raises(ValueError):
            User.objects.create_user(nome="", email="x@x.com", password="123456")

    def test_valores_padrao_de_preferencias(self, usuario):
        """Preferências devem nascer com os defaults esperados."""
        assert usuario.idioma == "pt_BR"
        assert usuario.unidade_distancia == "KM"
        assert usuario.permitir_sugestoes is True
        assert usuario.perfil_publico is True

    def test_usuario_sempre_tem_permissoes_administrativas(self, usuario):
        """Propriedades is_staff/is_superuser/is_active são fixas em True
        nesta implementação (comportamento atual do modelo)."""
        assert usuario.is_staff is True
        assert usuario.is_superuser is True
        assert usuario.is_active is True

    def test_str_retorna_nome(self, usuario):
        assert str(usuario) == "mariasilva"


@pytest.mark.django_db
class TestUsuarioPerfilAPI:
    """Testes do endpoint GET/PUT /perfil/."""

    def test_get_perfil_sem_parametro_nome_retorna_400(self, api_client):
        response = api_client.get("/api/usuarios/perfil/")
        assert response.status_code == 400

    def test_get_perfil_usuario_inexistente_retorna_404(self, api_client):
        response = api_client.get("/api/usuarios/perfil/?nome=naoexiste")
        assert response.status_code == 404

    def test_get_perfil_usuario_existente(self, api_client, usuario):
        response = api_client.get(f"/api/usuarios/perfil/?nome={usuario.nome}")
        assert response.status_code == 200
        assert response.data["nome"] == "mariasilva"
        assert response.data["email"] == "maria@acessoja.com"

    def test_put_perfil_atualiza_nome_completo(self, api_client, usuario):
        response = api_client.put(
            f"/api/usuarios/perfil/?nome={usuario.nome}",
            {"nome_completo": "Maria da Silva"},
            format="json",
        )
        assert response.status_code == 200
        usuario.refresh_from_db()
        assert usuario.nome_completo == "Maria da Silva"


@pytest.mark.django_db
class TestUsuarioSenhaAPI:
    """Testes do endpoint POST /alterar-senha/."""

    def test_alterar_senha_sem_nome_retorna_400(self, api_client):
        response = api_client.post("/api/usuarios/alterar-senha/", {}, format="json")
        assert response.status_code == 400

    def test_alterar_senha_usuario_inexistente_retorna_404(self, api_client):
        response = api_client.post(
            "/api/usuarios/alterar-senha/",
            {"nome": "fantasma", "senha_atual": "x", "nova_senha": "123456"},
            format="json",
        )
        assert response.status_code == 404

    def test_alterar_senha_atual_incorreta_retorna_403(self, api_client, usuario):
        response = api_client.post(
            "/api/usuarios/alterar-senha/",
            {"nome": usuario.nome, "senha_atual": "errada", "nova_senha": "novaSenha123"},
            format="json",
        )
        assert response.status_code == 403

    def test_alterar_senha_com_sucesso(self, api_client, usuario):
        response = api_client.post(
            "/api/usuarios/alterar-senha/",
            {"nome": usuario.nome, "senha_atual": "senha@123", "nova_senha": "novaSenha123"},
            format="json",
        )
        assert response.status_code == 200
        usuario.refresh_from_db()
        assert usuario.check_password("novaSenha123")

    def test_alterar_senha_curta_retorna_400(self, api_client, usuario):
        """Nova senha com menos de 6 caracteres deve ser rejeitada pelo serializer."""
        response = api_client.post(
            "/api/usuarios/alterar-senha/",
            {"nome": usuario.nome, "senha_atual": "senha@123", "nova_senha": "123"},
            format="json",
        )
        assert response.status_code == 400


@pytest.mark.django_db
class TestUsuarioFotoAPI:
    """Testes do endpoint POST /foto/."""

    def test_upload_foto_sem_campos_retorna_400(self, api_client):
        response = api_client.post("/api/usuarios/foto/", {}, format="json")
        assert response.status_code == 400

    def test_upload_foto_usuario_inexistente_retorna_404(self, api_client):
        response = api_client.post(
            "/api/usuarios/foto/",
            {"nome": "fantasma", "foto_perfil": "base64data"},
            format="json",
        )
        assert response.status_code == 404

    def test_upload_foto_com_sucesso(self, api_client, usuario):
        response = api_client.post(
            "/api/usuarios/foto/",
            {"nome": usuario.nome, "foto_perfil": "base64imagemfake"},
            format="json",
        )
        assert response.status_code == 200
        usuario.refresh_from_db()
        assert usuario.foto_perfil == "base64imagemfake"
