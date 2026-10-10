import pytest
from django.contrib.auth import authenticate, get_user_model
from django.core.cache import cache
from rest_framework.test import APIClient
from locais.models import Local
from modal_avaliacao.models import ModalAvaliacao
from contribuicoes.services import impact


@pytest.mark.django_db
def test_stars_only_earn_ten_and_completing_survey_earns_five_once():
    cache.clear()
    user = get_user_model().objects.create_user(nome="optional", email="o@test.com", password="securepass")
    place = Local.objects.create(nome="Lugar", endereco="Rua", distancia=0)
    client = APIClient()
    client.force_authenticate(user)
    url = "/api/avaliacoes/modal-avaliacoes/"
    response = client.post(url, {"local": place.pk, "estrelas": 4}, format="json")
    assert response.status_code == 201
    assert response.data["points_delta"] == 10
    assert not response.data["survey_completed"]
    review = ModalAvaliacao.objects.get()
    body = {f"pergunta_{i}": "Não sei" for i in range(1, 5)}
    response = client.patch(f"{url}{review.pk}/", body, format="json")
    assert response.status_code == 200 and response.data["points_delta"] == 5
    assert response.data["survey_completed"]
    assert client.patch(f"{url}{review.pk}/", body, format="json").data["points_delta"] == 0
    assert impact(user)["points"] == 15
    assert client.patch(f"{url}{review.pk}/", {"survey_completed": True}, format="json").status_code == 400
    cache.clear()


@pytest.mark.django_db
def test_inactive_accounts_cannot_login_and_admin_username_authentication_works():
    cache.clear()
    User = get_user_model()
    user = User.objects.create_user(nome="inactive", email="i@test.com", password="securepass", is_active=False)
    assert (
        APIClient().post("/api/login/", {"nome": user.nome, "password": "securepass"}, format="json").status_code == 401
    )
    admin = User.objects.create_superuser(nome="realadmin", email="a@test.com", password="securepass")
    assert authenticate(username=admin.nome, password="securepass") == admin
    cache.clear()
