import pytest
from django.core.management import call_command
from locais.models import Local
from locais.serializers import LocalSerializer


@pytest.mark.django_db
def test_import_is_idempotent_and_preserves_later_edits():
    call_command('cadastrar_unievangelica')
    local = Local.objects.get()
    assert local.aberto is None and local.distancia is None
    assert local.latitude == -16.293057
    guide = LocalSerializer(local).data['guia_visita']
    assert len(guide['areas']) == 3
    assert set(guide['recursos']) == {'atendimento_acessivel'}
    assert not local.rampa_acesso
    local.guia_visita['descricao'] = 'Informação posterior preservada'
    local.save()
    call_command('cadastrar_unievangelica')
    assert Local.objects.count() == 1
    local.refresh_from_db()
    assert local.guia_visita['descricao'] == 'Informação posterior preservada'


@pytest.mark.django_db
def test_api_list_sees_new_place_after_an_empty_request():
    from rest_framework.test import APIRequestFactory
    from locais.views import LocalViewSet
    view = LocalViewSet.as_view({'get': 'list'})
    factory = APIRequestFactory()
    assert view(factory.get('/api/locais/')).data == []
    call_command('cadastrar_unievangelica')
    response = view(factory.get('/api/locais/'))
    assert len(response.data) == 1
    assert len(response.data[0]['guia_visita']['areas']) == 3
