"""
Testes automatizados — app: modal_avaliacao
Cobre o modelo ModalAvaliacao e o endpoint /api/avaliacoes/modal-avaliacoes/,
incluindo a regra de negocio que atualiza os flags de acessibilidade do
Local (locais.models.Local) a partir das respostas do questionario.
"""
import pytest
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from locais.models import Local
from modal_avaliacao.models import ModalAvaliacao

User = get_user_model()


@pytest.fixture
def usuario(db):
    return User.objects.create_user(
        nome="pedrolima", email="pedro@acessoja.com", password="senha@123"
    )


@pytest.fixture
def local(db):
    return Local.objects.create(nome="Shopping Norte", endereco="Av. B, 500", distancia=1.0)


@pytest.fixture
def api_client():
    return APIClient()


class TestModalAvaliacaoModel:
    def test_criacao_modal_avaliacao(self, local, usuario):
        avaliacao = ModalAvaliacao.objects.create(
            local=local,
            user=usuario,
            pergunta_1="Sim",
            pergunta_2="Não",
            pergunta_3="Não sei",
            pergunta_4="Sim",
            estrelas=4,
        )
        assert avaliacao.pk is not None
        assert avaliacao.data_resposta is not None

    def test_str_retorna_descricao_legivel(self, local, usuario):
        avaliacao = ModalAvaliacao.objects.create(
            local=local, user=usuario,
            pergunta_1="Sim", pergunta_2="Sim", pergunta_3="Sim", pergunta_4="Sim",
        )
        assert str(avaliacao) == f"Avaliação de {local.nome} por {usuario.nome}"


@pytest.mark.django_db
class TestModalAvaliacaoAPI:
    """Testes do endpoint POST /api/avaliacoes/modal-avaliacoes/."""

    def test_criar_avaliacao_via_api(self, api_client, local, usuario):
        api_client.force_authenticate(user=usuario)
        payload = {
            "local": local.id_local,
            "pergunta_1": "Sim",
            "pergunta_2": "Sim",
            "pergunta_3": "Não",
            "pergunta_4": "Não",
            "estrelas": 5,
            "comentario": "Fácil acesso",
        }
        response = api_client.post(
            "/api/avaliacoes/modal-avaliacoes/", payload, format="json"
        )
        assert response.status_code == 201
        assert ModalAvaliacao.objects.count() == 1

    def test_respostas_sim_atualizam_flags_de_acessibilidade_do_local(
        self, api_client, local, usuario
    ):
        """Regra de negocio central do app: cada resposta 'Sim' liga um
        flag de acessibilidade correspondente no Local associado."""
        api_client.force_authenticate(user=usuario)
        payload = {
            "local": local.id_local,
            "pergunta_1": "Sim",  # -> rampa_acesso
            "pergunta_2": "Sim",  # -> banheiro_acessivel
            "pergunta_3": "Sim",  # -> mesa_acessivel
            "pergunta_4": "Sim",  # -> cao_guia
            "estrelas": 5,
        }
        api_client.post("/api/avaliacoes/modal-avaliacoes/", payload, format="json")
        local.refresh_from_db()
        assert local.rampa_acesso is True
        assert local.banheiro_acessivel is True
        assert local.mesa_acessivel is True
        assert local.cao_guia is True

    def test_respostas_nao_nao_alteram_flags(self, api_client, local, usuario):
        """Respostas diferentes de 'Sim' não devem ligar nenhum flag."""
        api_client.force_authenticate(user=usuario)
        payload = {
            "local": local.id_local,
            "pergunta_1": "Não",
            "pergunta_2": "Não sei",
            "pergunta_3": "Não",
            "pergunta_4": "Não sei",
            "estrelas": 3,
        }
        api_client.post("/api/avaliacoes/modal-avaliacoes/", payload, format="json")
        local.refresh_from_db()
        assert local.rampa_acesso is False
        assert local.banheiro_acessivel is False
        assert local.mesa_acessivel is False
        assert local.cao_guia is False

    def test_filtrar_avaliacoes_por_local_id(self, api_client, local, usuario, db):
        outro_local = Local.objects.create(nome="Farmácia Sul", endereco="Rua C, 20", distancia=0.2)
        ModalAvaliacao.objects.create(
            local=local, user=usuario,
            pergunta_1="Sim", pergunta_2="Sim", pergunta_3="Sim", pergunta_4="Sim",
        )
        ModalAvaliacao.objects.create(
            local=outro_local, user=usuario,
            pergunta_1="Não", pergunta_2="Não", pergunta_3="Não", pergunta_4="Não",
        )
        response = api_client.get(
            f"/api/avaliacoes/modal-avaliacoes/?local_id={local.id_local}"
        )
        assert response.status_code == 200
        assert len(response.data) == 1
        assert response.data[0]["local"] == local.id_local

    def test_endpoint_e_publico_permite_acesso_anonimo(self, api_client, local, usuario):
        """A view usa AllowAny — deve funcionar mesmo sem autenticação,
        atribuindo a avaliação ao primeiro usuário cadastrado."""
        payload = {
            "local": local.id_local,
            "pergunta_1": "Sim",
            "pergunta_2": "Não",
            "pergunta_3": "Não",
            "pergunta_4": "Não",
            "estrelas": 2,
        }
        response = api_client.post(
            "/api/avaliacoes/modal-avaliacoes/", payload, format="json"
        )
        assert response.status_code == 201
