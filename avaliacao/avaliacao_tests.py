"""
Testes automatizados — app: avaliacao
"""
import pytest
from django.contrib.auth import get_user_model
from avaliacao.models import Local, AvaliacaoLocal

User = get_user_model()


@pytest.fixture
def usuario(db):
    return User.objects.create_user(
        nome="carlosferreira", email="carlos@acessoja.com", password="senha@123"
    )


@pytest.fixture
def outro_usuario(db):
    return User.objects.create_user(
        nome="anapaula", email="ana@acessoja.com", password="senha@123"
    )


@pytest.fixture
def local(db, usuario):
    return Local.objects.create(
        user=usuario,
        nome="Padaria Central",
        endereco="Rua A, 10",
        distancia=0.4,
    )


class TestLocalModel:
    def test_criacao_local(self, local):
        assert local.id is not None
        assert local.nome == "Padaria Central"
        assert local.aberto is True

    def test_media_estrelas_sem_avaliacoes(self, local):
        assert local.media_estrelas == 0

    def test_media_estrelas_com_avaliacoes(self, local, usuario, outro_usuario):
        AvaliacaoLocal.objects.create(local=local, user=usuario, estrelas=4)
        AvaliacaoLocal.objects.create(local=local, user=outro_usuario, estrelas=2)
        assert local.media_estrelas == 3.0

    def test_str_retorna_nome(self, local):
        assert str(local) == "Padaria Central"


class TestAvaliacaoLocalModel:
    def test_criacao_avaliacao(self, local, usuario):
        avaliacao = AvaliacaoLocal.objects.create(
            local=local, user=usuario, comentario="Ótimo atendimento", estrelas=5
        )
        assert avaliacao.pk is not None
        assert avaliacao.estrelas == 5

    def test_usuario_nao_pode_avaliar_mesmo_local_duas_vezes(self, local, usuario):
        """unique_together = ('local', 'user') deve impedir avaliação duplicada."""
        from django.db import IntegrityError

        AvaliacaoLocal.objects.create(local=local, user=usuario, estrelas=5)
        with pytest.raises(IntegrityError):
            AvaliacaoLocal.objects.create(local=local, user=usuario, estrelas=1)

    def test_str_retorna_descricao_legivel(self, local, usuario):
        avaliacao = AvaliacaoLocal.objects.create(local=local, user=usuario, estrelas=5)
        assert str(avaliacao) == f"Avaliação de {local.nome} por {usuario.nome}"
