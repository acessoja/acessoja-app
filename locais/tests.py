"""
Testes unitários — app: locais
Cobre o modelo Local e suas propriedades calculadas.
"""
import pytest
from django.contrib.auth import get_user_model
from locais.models import Local, VisitaRecente

User = get_user_model()


@pytest.fixture
def usuario(db):
    """Cria um usuário de teste padrão."""
    return User.objects.create_user(
        username="testuser",
        email="test@acessoja.com",
        password="senha@123"
    )


@pytest.fixture
def local_acessivel(db):
    """Cria um Local com todos os recursos de acessibilidade."""
    return Local.objects.create(
        nome="Restaurante Inclusivo",
        endereco="Rua das Flores, 100",
        distancia=0.5,
        latitude=-21.7895,
        longitude=-46.5696,
        aberto=True,
        cao_guia=True,
        mesa_acessivel=True,
        banheiro_acessivel=True,
        rampa_acesso=True,
        cardapio_braille=True,
    )


@pytest.fixture
def local_sem_acessibilidade(db):
    """Cria um Local sem recursos de acessibilidade."""
    return Local.objects.create(
        nome="Bar Comum",
        endereco="Av. Principal, 200",
        distancia=1.2,
        aberto=False,
    )


class TestLocalModel:
    """Testes do modelo Local."""

    def test_criacao_local_basico(self, db):
        """Local é criado corretamente com campos obrigatórios."""
        local = Local.objects.create(
            nome="Café Acessível",
            endereco="Rua Teste, 1",
            distancia=0.3,
        )
        assert local.id_local is not None
        assert local.nome == "Café Acessível"
        assert local.aberto is True  # default

    def test_media_estrelas_sem_avaliacoes(self, local_acessivel):
        """Sem avaliações, media_estrelas deve retornar 0.0."""
        assert local_acessivel.media_estrelas == 0.0

    def test_local_aberto_por_padrao(self, db):
        """Campo 'aberto' deve ser True por padrão."""
        local = Local.objects.create(
            nome="Local X", endereco="End X", distancia=0.1
        )
        assert local.aberto is True

    def test_local_fechado(self, local_sem_acessibilidade):
        """Local criado com aberto=False deve persistir corretamente."""
        assert local_sem_acessibilidade.aberto is False

    def test_campos_acessibilidade_padrao_false(self, db):
        """Todos os flags de acessibilidade devem ser False por padrão."""
        local = Local.objects.create(
            nome="Local Padrão", endereco="End Padrão", distancia=0.8
        )
        assert local.cao_guia is False
        assert local.mesa_acessivel is False
        assert local.banheiro_acessivel is False
        assert local.rampa_acesso is False
        assert local.cardapio_braille is False

    def test_local_totalmente_acessivel(self, local_acessivel):
        """Local com todos os recursos deve ter todos os flags True."""
        assert local_acessivel.cao_guia is True
        assert local_acessivel.mesa_acessivel is True
        assert local_acessivel.banheiro_acessivel is True
        assert local_acessivel.rampa_acesso is True
        assert local_acessivel.cardapio_braille is True

    def test_coordenadas_geograficas(self, local_acessivel):
        """Latitude e longitude devem ser armazenadas corretamente."""
        assert local_acessivel.latitude == pytest.approx(-21.7895)
        assert local_acessivel.longitude == pytest.approx(-46.5696)

    def test_distancia_float(self, local_acessivel):
        """Distância deve ser armazenada como float."""
        assert isinstance(local_acessivel.distancia, float)
        assert local_acessivel.distancia == 0.5

    def test_data_criacao_automatica(self, local_acessivel):
        """data_criacao deve ser preenchida automaticamente."""
        assert local_acessivel.data_criacao is not None

    def test_filtrar_locais_abertos(self, local_acessivel, local_sem_acessibilidade):
        """Deve ser possível filtrar somente locais abertos."""
        abertos = Local.objects.filter(aberto=True)
        fechados = Local.objects.filter(aberto=False)
        assert local_acessivel in abertos
        assert local_sem_acessibilidade in fechados

    def test_filtrar_por_cao_guia(self, local_acessivel, local_sem_acessibilidade):
        """Filtro por cao_guia deve retornar somente locais com o recurso."""
        com_cao = Local.objects.filter(cao_guia=True)
        assert local_acessivel in com_cao
        assert local_sem_acessibilidade not in com_cao


class TestVisitaRecente:
    """Testes do modelo VisitaRecente."""

    def test_criacao_visita(self, db, usuario, local_acessivel):
        """Visita deve ser criada corretamente associando usuário e local."""
        visita = VisitaRecente.objects.create(
            user=usuario,
            local=local_acessivel,
        )
        assert visita.pk is not None
        assert visita.local == local_acessivel
        assert visita.user == usuario

    def test_data_visita_automatica(self, db, usuario, local_acessivel):
        """data_visita deve ser preenchida automaticamente."""
        visita = VisitaRecente.objects.create(
            user=usuario, local=local_acessivel
        )
        assert visita.data_visita is not None

    def test_multiplas_visitas_mesmo_local(self, db, usuario, local_acessivel):
        """Mesmo usuário pode registrar múltiplas visitas ao mesmo local."""
        VisitaRecente.objects.create(user=usuario, local=local_acessivel)
        VisitaRecente.objects.create(user=usuario, local=local_acessivel)
        total = VisitaRecente.objects.filter(user=usuario, local=local_acessivel).count()
        assert total == 2
