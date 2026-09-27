import pytest
from rest_framework.test import APIClient


@pytest.mark.django_db
@pytest.mark.parametrize('language, expected', [
    ('pt-br', 'Esta senha'),
    ('en', 'This password'),
])
def test_password_errors_follow_requested_language(language, expected):
    response = APIClient().post('/auth/users/', {
        'nome': 'teste_idioma', 'email': 'idioma@example.com', 'password': '123',
    }, format='json', HTTP_ACCEPT_LANGUAGE=language)
    assert response.status_code == 400
    assert expected in ' '.join(response.data['password'])
