from datetime import timedelta
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from unittest.mock import patch

import pytest
from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.db import IntegrityError, close_old_connections, connection, transaction
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient

from locais.models import Local, VisitaRecente
from modal_avaliacao.models import ModalAvaliacao
from .models import ContributionPointEvent, PointActivity, UserAchievement
from .services import impact, sync_evaluation

User = get_user_model()
URL = "/api/avaliacoes/modal-avaliacoes/"


@pytest.fixture(autouse=True)
def clear_throttles():
    from django.core.cache import cache

    cache.clear()
    yield
    cache.clear()


@pytest.fixture
def author(db):
    return User.objects.create_user(nome="autor", email="autor@test.com", password="securepass")


@pytest.fixture
def place(db):
    return Local.objects.create(
        nome="Biblioteca", endereco="Centro", latitude=-16.3267, longitude=-48.9528, categoria="library", distancia=0
    )


@pytest.fixture
def client(author):
    client = APIClient()
    client.force_authenticate(author)
    return client


def payload(place, **extra):
    return {
        "local": place.pk,
        "estrelas": 4,
        "pergunta_1": "Sim",
        "pergunta_2": "Não",
        "pergunta_3": "Não sei",
        "pergunta_4": "Sim",
        "comentario": "Entrada com rampa.",
        **extra,
    }


def submit(client, place, **extra):
    return client.post(URL, payload(place, **extra), format="json")


def test_zero_points_and_private_summary(client, author):
    response = client.get("/api/contribuicoes/meu-impacto/")
    assert response.status_code == 200
    assert response.data["points"] == 0
    assert response.data["remaining_points"] == 30
    assert response.data["achievements_count"] == 0
    assert APIClient().get("/api/contribuicoes/meu-impacto/").status_code == 401


def test_first_review_survey_persists_and_replay_cannot_award(client, place, author):
    response = submit(client, place, nome_usuario="outra-pessoa")
    assert response.status_code == 201
    assert response.data["points_delta"] == 15
    review = ModalAvaliacao.objects.get()
    assert review.user == author and review.verified_author
    assert submit(client, place).status_code == 409
    for _ in range(3):
        sync_evaluation(review)
        assert client.patch(f"{URL}{review.pk}/", {"estrelas": 5}, format="json").status_code == 200
    assert impact(author)["points"] == 15
    assert PointActivity.objects.count() == 2
    assert UserAchievement.objects.get(code="first").unlocked_at is not None
    assert place.media_estrelas == 5


@pytest.mark.parametrize(
    "field,value",
    [
        ("points", 9000),
        ("pontos", 9000),
        ("user", 42),
        ("verified_author", True),
        ("comment_verified", True),
        ("is_current", False),
        ("is_valid", True),
    ],
)
def test_client_cannot_control_points_author_or_moderation(client, place, field, value):
    assert submit(client, place, **{field: value}).status_code == 400
    assert not ModalAvaliacao.objects.exists()
    assert not ContributionPointEvent.objects.exists()


@pytest.mark.parametrize("stars", [0, -1, 6])
def test_invalid_rating_does_not_award(client, place, stars):
    assert submit(client, place, estrelas=stars).status_code == 400
    assert not ContributionPointEvent.objects.exists()


def test_anonymous_write_and_forged_name_rejected(author, place):
    assert submit(APIClient(), place, nome_usuario=author.nome).status_code == 401
    assert not ModalAvaliacao.objects.exists()


def test_only_author_can_edit_delete_or_move_review(client, author, place):
    review_id = submit(client, place).data["id"]
    other = User.objects.create_user(nome="outro", email="outro@test.com", password="securepass")
    outsider = APIClient()
    outsider.force_authenticate(other)
    assert outsider.patch(f"{URL}{review_id}/", {"estrelas": 2}, format="json").status_code == 403
    assert outsider.delete(f"{URL}{review_id}/").status_code == 403
    other_place = Local.objects.create(nome="Outro", endereco="Rua", distancia=0)
    assert client.patch(f"{URL}{review_id}/", {"local": other_place.pk}, format="json").status_code == 400
    assert ModalAvaliacao.objects.get().local == place


def test_delete_reverses_points_and_recreate_restores_only_once(client, author, place):
    pk = submit(client, place).data["id"]
    assert client.delete(f"{URL}{pk}/").status_code == 204
    assert impact(author)["points"] == 0
    assert sum(PointActivity.objects.values_list("delta", flat=True)) == 0
    assert not UserAchievement.objects.get(code="first").active
    assert submit(client, place).data["points_delta"] == 15
    assert ContributionPointEvent.objects.count() == 2
    assert impact(author)["points"] == 15


def test_comment_points_require_moderation_and_edit_revokes(client, author, place):
    pk = submit(client, place, comentario="x" * 500).data["id"]
    assert impact(author)["points"] == 15
    review = ModalAvaliacao.objects.get(pk=pk)
    review.comment_verified = True
    review.save()
    assert impact(author)["points"] == 20
    assert client.patch(f"{URL}{pk}/", {"comentario": "Outro texto"}, format="json").status_code == 200
    assert impact(author)["points"] == 15
    review.refresh_from_db()
    review.is_valid = False
    review.save()
    assert impact(author)["points"] == 0
    assert APIClient().get(f"{URL}{pk}/").status_code == 404
    review.is_valid = True
    review.save()
    assert impact(author)["points"] == 15


def test_levels_categories_and_achievement_progress(client, author, place):
    for i, category in enumerate(["library", "restaurant", "hospital", "school", "library"]):
        p = Local.objects.create(nome=f"Lugar {i}", endereco="Rua", distancia=0, categoria=category)
        assert submit(client, p).status_code == 201
    result = impact(author)
    assert result["points"] == 75 and result["level"] == 2
    assert result["remaining_points"] == 25
    assert result["places"] == 5
    assert result["achievements_count"] == 3
    for _ in range(2):
        call_command("reconcile_contributions")
    assert impact(author)["points"] == 75


def test_historical_uncertain_author_stays_without_points(client, author, place):
    review = ModalAvaliacao.objects.create(user=author, **payload(place, local=place))
    # Pass the FK as an instance; historical rows do not validate authors.
    assert not review.verified_author
    assert impact(author)["points"] == 0
    assert client.patch(f"{URL}{review.pk}/", {"estrelas": 3}, format="json").status_code == 200
    assert impact(author)["points"] == 0


def test_privacy_community_self_and_anonymized_place_reviews(client, author, place):
    pk = submit(client, place).data["id"]
    author.perfil_publico = False
    author.save()
    anon = APIClient()
    assert anon.get("/api/contribuicoes/comunidade/").data["count"] == 0
    public = anon.get(f"{URL}{pk}/").data
    assert public["nome_usuario"] == "Colaborador AcessoJá"
    assert public["user"] is None and not public["can_edit"]
    author.mostrar_avaliacoes = False
    author.save()
    assert anon.get(f"{URL}{pk}/").status_code == 404
    assert client.get("/api/contribuicoes/minhas-avaliacoes/").data["count"] == 1
    assert client.get("/api/contribuicoes/atividade/").data["count"] == 2


def test_own_profile_and_password_cannot_be_changed_by_name(client, author):
    other = User.objects.create_user(nome="vitima", email="v@test.com", password="oldpass")
    assert client.get("/api/usuarios/perfil/?nome=vitima").status_code == 403
    assert (
        client.put("/api/usuarios/perfil/?nome=vitima", {"email": "hacked@test.com"}, format="json").status_code == 403
    )
    assert (
        client.post(
            "/api/usuarios/alterar-senha/",
            {"nome": "vitima", "senha_atual": "oldpass", "nova_senha": "hackedpass"},
            format="json",
        ).status_code
        == 403
    )
    other.refresh_from_db()
    assert other.email == "v@test.com" and other.check_password("oldpass")


def test_token_login_expiration_logout_and_password_revocation(author):
    client = APIClient()
    login = client.post("/api/login/", {"nome": author.nome, "password": "securepass"}, format="json")
    assert login.status_code == 200 and login.data["token"]
    client.credentials(HTTP_AUTHORIZATION=f"Token {login.data['token']}")
    assert client.get("/api/contribuicoes/meu-impacto/").status_code == 200
    Token.objects.filter(user=author).update(created=timezone.now() - timedelta(days=1))
    assert client.get("/api/contribuicoes/meu-impacto/").status_code == 401
    client.credentials()
    token = client.post("/api/login/", {"nome": author.nome, "password": "securepass"}, format="json").data["token"]
    client.credentials(HTTP_AUTHORIZATION=f"Token {token}")
    assert client.post("/api/usuarios/logout/").status_code == 200
    assert client.get("/api/contribuicoes/meu-impacto/").status_code == 401
    client.credentials()
    token = client.post("/api/login/", {"nome": author.nome, "password": "securepass"}, format="json").data["token"]
    client.credentials(HTTP_AUTHORIZATION=f"Token {token}")
    assert (
        client.post(
            "/api/usuarios/alterar-senha/",
            {"nome": author.nome, "senha_atual": "securepass", "nova_senha": "newsecurepass"},
            format="json",
        ).status_code
        == 200
    )
    assert not Token.objects.filter(user=author).exists()


def test_real_admin_permissions(author):
    admin = User.objects.create_superuser(nome="admin", email="admin@test.com", password="securepass")
    assert admin.is_staff and admin.is_superuser and admin.has_perm("any.permission")
    assert not author.has_perm("any.permission")
    with pytest.raises(ValueError):
        User.objects.create_superuser(nome="bad", email="bad@test.com", password="securepass", is_staff=False)


def test_database_uniqueness_and_atomic_rollback(client, author, place):
    pk = submit(client, place).data["id"]
    with pytest.raises(IntegrityError), transaction.atomic():
        ModalAvaliacao.objects.create(user=author, local=place, estrelas=2)
    assert ModalAvaliacao.objects.get(pk=pk).estrelas == 4
    place2 = Local.objects.create(nome="Falha", endereco="Rua", distancia=0)
    with patch("contribuicoes.services.PointActivity.objects.create", side_effect=RuntimeError("rollback")):
        with pytest.raises(RuntimeError):
            submit(client, place2)
    assert not ModalAvaliacao.objects.filter(local=place2).exists()
    assert impact(author)["points"] == 15


def test_discovery_filters_pagination_coordinates_and_visits(client, author, place):
    assert client.get("/api/contribuicoes/locais-para-avaliar/?estado=unreviewed").data["count"] == 1
    assert client.get("/api/contribuicoes/locais-para-avaliar/?latitude=NaN&longitude=0").status_code == 400
    assert client.get("/api/contribuicoes/locais-para-avaliar/?latitude=0").status_code == 400
    assert client.get("/api/contribuicoes/locais-para-avaliar/?raio=50000").status_code == 400
    submit(client, place)
    assert client.get("/api/contribuicoes/locais-para-avaliar/?estado=unreviewed").data["count"] == 0
    assert client.get("/api/contribuicoes/locais-para-avaliar/?estado=incomplete").data["count"] == 1
    assert client.get("/api/contribuicoes/locais-para-avaliar/?search=Biblioteca&categoria=library").data["count"] == 1
    VisitaRecente.objects.create(user=author, local=place)
    assert client.get("/api/contribuicoes/locais-para-avaliar/?estado=visited").data["count"] == 0
    VisitaRecente.objects.create(user=author, local=place, arrival_confirmed=True)
    assert client.get("/api/contribuicoes/locais-para-avaliar/?estado=visited").data["count"] == 1
    geo = client.get("/api/contribuicoes/locais-para-avaliar/?latitude=-16.3267&longitude=-48.9528")
    assert geo.data["results"][0]["distance_meters"] == 0
    assert client.get(f"{URL}?local_id=node/1").status_code == 400


def test_arrival_requires_consent_precise_location_and_owner(client, author, place):
    url = "/api/visitas/"
    data = {"local": place.pk, "latitude": place.latitude, "longitude": place.longitude, "accuracy": 5}
    author.historico_visivel = False
    author.save()
    assert client.post(url, data, format="json").status_code == 403
    author.historico_visivel = True
    author.compartilhar_localizacao = True
    author.save()
    assert client.post(url, {**data, "accuracy": 200}, format="json").status_code == 400
    assert client.post(url, {**data, "latitude": 0}, format="json").status_code == 400
    assert client.post(url, data, format="json").status_code == 201
    assert VisitaRecente.objects.get().arrival_confirmed
    assert client.get(url).data[0]["arrival_confirmed"]


@pytest.mark.django_db(transaction=True)
def test_postgresql_concurrent_replay_awards_once():
    if connection.vendor != "postgresql":
        pytest.skip("Row-lock concurrency must run on PostgreSQL, not SQLite.")
    author = User.objects.create_user(nome="concurrent", email="c@test.com", password="securepass")
    place = Local.objects.create(nome="Concorrência", endereco="Rua", distancia=0)
    barrier = Barrier(2)

    def worker():
        close_old_connections()
        client = APIClient()
        client.force_authenticate(User.objects.get(pk=author.pk))
        barrier.wait(timeout=10)
        try:
            return submit(client, place).status_code
        finally:
            close_old_connections()

    with ThreadPoolExecutor(max_workers=2) as pool:
        codes = list(pool.map(lambda _: worker(), range(2)))
    assert sorted(codes) == [201, 409]
    assert impact(author)["points"] == 15
    assert ModalAvaliacao.objects.filter(user=author).count() == 1
    assert PointActivity.objects.count() == 2
