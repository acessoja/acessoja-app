import pytest
from locais.models import Local
from locais.serializers import LocalSerializer


@pytest.mark.django_db
def test_guide_round_trip_with_independent_areas():
    serializer = LocalSerializer(data={
        'nome': 'Campus de teste', 'endereco': 'Rua Teste', 'distancia': 0,
        'guia_visita': {
            'horarios': 'Segunda a sexta, 8h às 18h',
            'site': 'https://example.org',
            'recursos': {'elevador': {'estado': 'nao_informado'},
                         'rampa_acesso': {'estado': 'disponivel'}},
            'areas': [{'nome': 'Biblioteca', 'recursos': {
                'elevador': {'estado': 'nao_se_aplica', 'fonte': 'Vistoria de teste',
                             'atualizado_em': '2026-09-26'}
            }}],
        },
    })
    assert serializer.is_valid(), serializer.errors
    local = serializer.save()
    local.refresh_from_db()
    result = LocalSerializer(local).data
    assert result['aberto'] is None
    assert result['rampa_acesso'] is True
    assert result['guia_visita']['recursos']['elevador']['estado'] == 'nao_informado'
    assert result['guia_visita']['areas'][0]['recursos']['elevador']['atualizado_em'] == '2026-09-26'


@pytest.mark.parametrize('guide', [
    {'recursos': {'elevador': {'estado': 'sim'}}},
    {'recursos': {'inventado': {'estado': 'disponivel'}}},
    {'site': 'javascript:alert(1)'},
    {'areas': [{'descricao': 'Sem nome'}]},
    {'atualizado_em': 'data inválida'},
])
def test_invalid_guide_is_rejected(guide):
    serializer = LocalSerializer(data={'nome': 'Teste', 'endereco': 'Rua',
                                     'distancia': 0, 'guia_visita': guide})
    assert not serializer.is_valid()
    assert 'guia_visita' in serializer.errors


@pytest.mark.django_db
def test_small_place_requires_no_areas_and_patch_preserves_existing_data():
    local = Local.objects.create(nome='Restaurante de teste', endereco='Rua', distancia=0,
                                guia_visita={'descricao': 'Térreo'})
    serializer = LocalSerializer(local, data={'nome': 'Novo nome'}, partial=True)
    assert serializer.is_valid(), serializer.errors
    serializer.save()
    local.refresh_from_db()
    assert local.guia_visita == {'descricao': 'Térreo'}
    assert 'areas' not in LocalSerializer(local).data['guia_visita']
