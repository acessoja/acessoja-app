import pytest
from rest_framework.test import APIClient
from locais.models import Local


@pytest.mark.django_db
def test_community_place_creation_round_trip_and_duplicate():
    client = APIClient()
    payload = {'nome': 'Restaurante de teste', 'endereco': 'Rua de teste, 10',
               'latitude': -16.3, 'longitude': -48.9,
               'guia_visita': {'categoria': 'alimentacao',
                               'fonte': 'Relato da comunidade — não verificado',
                               'recursos': {'rampa_acesso': {'estado': 'nao_informado'},
                                            'banheiro_acessivel': {'estado': 'disponivel'}}}}
    response = client.post('/api/locais/', payload, format='json')
    assert response.status_code == 201, response.data
    local = Local.objects.get(pk=response.data['id_local'])
    assert local.distancia is None and local.aberto is None
    assert local.banheiro_acessivel is True
    assert local.guia_visita['recursos']['rampa_acesso']['estado'] == 'nao_informado'
    detail = client.get(f'/api/locais/{local.pk}/')
    assert detail.data['guia_visita']['categoria'] == 'alimentacao'
    assert client.post('/api/locais/', payload, format='json').status_code == 400
    assert Local.objects.count() == 1


@pytest.mark.django_db
@pytest.mark.parametrize('extra', [
    {'latitude': 91}, {'longitude': -181}, {'nome': ''},
    {'guia_visita': {'categoria': 'inventada'}},
    {'guia_visita': {'site': 'javascript:alert(1)'}},
])
def test_registration_rejects_invalid_fields(extra):
    response = APIClient().post(
        '/api/locais/',
        {'nome': 'Teste', 'endereco': 'Rua', **extra},
        format='json',
    )
    assert response.status_code == 400
    assert not Local.objects.exists()
