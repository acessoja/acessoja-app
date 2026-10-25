"""P01–P09: only synthetic records in isolated databases/directories."""
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from unittest.mock import patch
import json
import threading
import uuid

from django.core.cache import cache
from django.core.management import call_command
from django.db import close_old_connections, connection
from django.utils import timezone
import pytest
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient

from avaliacao.models import Local as LegacyLocal, AvaliacaoLocal
from contribuicoes.models import ContributionPointEvent, PointActivity
from favoritos.models import Favorito
from locais.models import Local, ManualPlaceRegistration, RouteHistorySession, VisitaRecente
from modal_avaliacao.models import ModalAvaliacao
from usuarios.deletion_journal import journal_identity, read_receipts, write_receipt
from usuarios.models import AccountDeletionReceipt, AccountMailJob, PrivacyConsent, Usuario
from usuarios.privacy_services import erase_relations

pytestmark = pytest.mark.django_db
PASSWORD = 'Synthetic-private!6392'
PRIVACY = '/api/usuarios/me/privacy/'
EXPORT = '/api/usuarios/me/data-export/'
DELETE = '/api/usuarios/me/delete-account/'
PREF = '/api/usuarios/me/route-history-preferences/'


@pytest.fixture(autouse=True)
def isolated_state(settings, tmp_path):
    settings.DELETION_JOURNAL_DIR = tmp_path / 'independent-receipts'
    journal_identity(initialize=True)
    cache.clear()
    yield
    cache.clear()


@pytest.fixture
def accounts():
    owner = Usuario.objects.create_user('privacy-synthetic', password=PASSWORD, email='owner@example.test',
                                        telefone='OWNER_PHONE', foto_perfil='OWNER_PHOTO',
                                        accessibility_preferences=['rampa_acesso'])
    other = Usuario.objects.create_user('other-synthetic', password=PASSWORD, email='other@example.test',
                                        telefone='THIRD_PARTY_PHONE')
    place = Local.objects.create(nome='Shared catalog', endereco='Synthetic address', distancia=0)
    client = APIClient()
    token = Token.objects.create(user=owner)
    client.credentials(HTTP_AUTHORIZATION=f'Token {token.key}')
    return owner, other, place, client, token


def populate(owner, other, place):
    Favorito.objects.create(user=owner, local=place)
    Favorito.objects.create(user=other, local=place)
    VisitaRecente.objects.create(user=owner, local=place)
    RouteHistorySession.objects.create(user=owner, session_id=uuid.uuid4(), destination_name='Synthetic route')
    ManualPlaceRegistration.objects.create(user=owner, request_id=uuid.uuid4(), payload_hash='x',
                                           local=place, distinct_reason='Owner contribution')
    first = ModalAvaliacao.objects.create(user=owner, local=place, estrelas=5, comentario='Owner review',
                                          verified_author=True)
    second = ModalAvaliacao.objects.create(user=other, local=place, estrelas=3, comentario='Other review',
                                           verified_author=True)
    return first, second


def test_p01_owner_choices_are_recorded_idempotently_revoked_and_separate(accounts):
    owner, other, place, client, _ = accounts
    initial = client.get(PRIVACY).json()
    assert all(item['state'] == 'not_recorded' and not item['enabled'] for item in initial['choices'])
    assert client.patch(PREF, {'notice_version': '2026-10-21', 'save_history': True,
                        'save_origin': True}, format='json').status_code == 200
    assert PrivacyConsent.objects.filter(user=owner, granted=True).count() == 2
    count = PrivacyConsent.objects.count()
    client.patch(PREF, {'notice_version': '2026-10-21', 'save_history': True, 'save_origin': True}, format='json')
    assert PrivacyConsent.objects.count() == count
    client.patch(PREF, {'save_history': False}, format='json')
    assert PrivacyConsent.objects.filter(user=owner, purpose='route_history').latest('pk').granted is False
    body = {'event': 'started', 'session_id': str(uuid.uuid4()), 'consent_revision': 2,
            'destination_name': place.nome, 'destination_source': 'acessoja',
            'local_id': place.pk, 'latitude': 0, 'longitude': 0,
            'estimated_distance': 1, 'estimated_duration': 1}
    response = client.post('/api/route-history/', body, format='json')
    assert response.status_code == 403
    owner.refresh_from_db()
    assert owner.save_route_origin and owner.perfil_publico and owner.historico_visivel
    assert not PrivacyConsent.objects.filter(user=other).exists()


def test_p02_legacy_choices_are_honest_and_pause_new_collection(accounts):
    owner, _, _, client, _ = accounts
    Usuario.objects.filter(pk=owner.pk).update(save_route_history=True, save_route_origin=True)
    doc = client.get(PRIVACY).json()
    assert all(item['legacy_choice'] and item['state'] == 'not_recorded' and not item['enabled']
               and item['recorded_at'] is None for item in doc['choices'])
    assert not PrivacyConsent.objects.exists()
    assert client.get(PREF).json()['save_history'] is False
    assert client.patch(PREF, {'notice_version': '2026-10-21', 'save_history': True},
                        format='json').json()['save_history'] is True
    assert PrivacyConsent.objects.get().notice_version == '2026-10-21'


def test_p03_export_has_actual_categories_dates_and_no_credentials_or_other_account(accounts):
    owner, other, place, client, token = accounts
    populate(owner, other, place)
    client.patch(PREF, {'notice_version': '2026-10-21', 'save_history': True}, format='json')
    response = client.post(EXPORT, {'current_password': PASSWORD}, format='json')
    assert response.status_code == 200
    assert response['Cache-Control'] == 'private, no-store'
    assert 'attachment;' in response['Content-Disposition']
    doc = json.loads(response.content)
    assert doc['format_version'] == 'acessoja.personal-data.v1' and doc['generated_at']
    categories = doc['categories']
    assert categories['profile']['email'] == owner.email
    for category in ['favorites', 'visits', 'route_history', 'reviews', 'points', 'point_activity', 'consents',
                     'manual_registrations']:
        assert categories[category]
    text = response.content.decode()
    for secret in [PASSWORD, owner.password, token.key, other.email, other.telefone, 'Other review',
                   'credential_revision', 'privacy_id', 'idempotency_key']:
        assert secret not in text
    assert 'criado_em' in text and 'data_resposta' in text and 'recorded_at' in text
    assert {item['category'] for item in doc['not_included']} == {
        'security_credentials', 'operational_logs_and_backups', 'device_and_external_providers'}


@pytest.mark.parametrize('path', [EXPORT, DELETE])
def test_p04_owner_is_only_from_authentication_and_unknown_fields_are_rejected(accounts, path):
    owner, other, _, client, _ = accounts
    body = {'current_password': PASSWORD, **({'confirm': True} if path == DELETE else {})}
    assert APIClient().post(path, body, format='json').status_code == 401
    assert client.post(path + f'?id={other.pk}', body, format='json').status_code == 400
    assert client.post(path, {**body, 'user': other.pk}, format='json').status_code == 400
    assert Usuario.objects.filter(pk=other.pk).exists() and Usuario.objects.filter(pk=owner.pk).exists()
    assert client.get(path).status_code == 405


@pytest.mark.parametrize('path', [DELETE, '/auth/users/me/'])
def test_p05_deletion_requires_current_password_and_explicit_confirmation(accounts, path):
    _, _, _, client, _ = accounts
    method = client.delete if path.startswith('/auth/') else client.post
    assert method(path, {'current_password': 'incorrect', 'confirm': True}, format='json').status_code == 400
    assert method(path, {'current_password': PASSWORD}, format='json').status_code == 400
    assert method(path, {'current_password': PASSWORD, 'confirm': False}, format='json').status_code == 400
    assert Usuario.objects.count() == 2 and not AccountDeletionReceipt.objects.exists()


@pytest.mark.parametrize('path', [DELETE, '/auth/users/me/'])
def test_p06_p07_deletion_preserves_shared_catalog_other_reviews_and_point_integrity(accounts, path):
    owner, other, place, client, token = accounts
    first, second = populate(owner, other, place)
    legacy = LegacyLocal.objects.create(user=owner, nome='Shared legacy', endereco='Synthetic', distancia=0)
    preserved_review = AvaliacaoLocal.objects.create(user=other, local=legacy, estrelas=4)
    before = list(ContributionPointEvent.objects.filter(user=other).values_list('pk', 'active', 'points'))
    assert place.media_estrelas == 4
    method = client.delete if path.startswith('/auth/') else client.post
    response = method(path, {'current_password': PASSWORD, 'confirm': True}, format='json')
    assert response.status_code == 204
    assert not Usuario.objects.filter(pk=owner.pk).exists()
    assert Usuario.objects.filter(pk=other.pk).exists() and Local.objects.filter(pk=place.pk).exists()
    assert not ModalAvaliacao.objects.filter(pk=first.pk).exists()
    assert ModalAvaliacao.objects.filter(pk=second.pk).exists() and place.media_estrelas == 3
    assert before == list(ContributionPointEvent.objects.filter(user=other).values_list('pk', 'active', 'points'))
    assert not Favorito.objects.filter(user_id=owner.pk).exists() and Favorito.objects.filter(user=other).exists()
    assert not RouteHistorySession.objects.filter(user_id=owner.pk).exists()
    assert not VisitaRecente.objects.filter(user_id=owner.pk).exists()
    assert not ManualPlaceRegistration.objects.filter(user_id=owner.pk).exists()
    assert not ContributionPointEvent.objects.filter(user_id=owner.pk).exists()
    assert not PointActivity.objects.filter(event__user_id=owner.pk).exists()
    assert not AccountMailJob.objects.filter(user_id=owner.pk).exists()
    legacy.refresh_from_db()
    assert legacy.user_id is None and AvaliacaoLocal.objects.filter(pk=preserved_review.pk).exists()
    assert not Token.objects.filter(key=token.key).exists()
    assert client.post(EXPORT, {'current_password': PASSWORD}, format='json').status_code == 401
    assert client.post(DELETE, {'current_password': PASSWORD, 'confirm': True}, format='json').status_code == 401
    assert read_receipts()[0]['state'] == 'committed'
    receipt = AccountDeletionReceipt.objects.get()
    assert receipt.published and receipt.privacy_id == owner.privacy_id


def test_p06_djoser_id_cannot_delete_someone_else_even_with_own_password(accounts):
    owner, other, _, client, _ = accounts
    assert client.delete(f'/auth/users/{other.pk}/', {'current_password': PASSWORD, 'confirm': True},
                         format='json').status_code == 404
    assert Usuario.objects.count() == 2


def test_p08_database_failure_rolls_back_and_cancels_external_intent(accounts):
    owner, other, place, client, _ = accounts
    populate(owner, other, place)

    def fail_after_delete(user):
        erase_relations(user)
        raise RuntimeError('simulated failure')

    with patch('usuarios.privacy_services.erase_relations', side_effect=fail_after_delete):
        assert client.post(DELETE, {'current_password': PASSWORD, 'confirm': True}, format='json').status_code == 503
    assert Usuario.objects.filter(pk=owner.pk).exists() and ModalAvaliacao.objects.filter(user=owner).exists()
    assert not AccountDeletionReceipt.objects.exists() and read_receipts()[0]['state'] == 'cancelled'


def test_p08_external_storage_failure_does_not_claim_completion(accounts):
    owner, _, _, client, _ = accounts
    with patch('usuarios.privacy_services.write_receipt', side_effect=OSError):
        response = client.post(DELETE, {'current_password': PASSWORD, 'confirm': True}, format='json')
    assert response.status_code == 503 and Usuario.objects.filter(pk=owner.pk).exists()


def test_p09_commit_publication_failure_is_pending_and_recoverable(accounts):
    owner, _, _, client, _ = accounts
    actual = write_receipt

    def publish(receipt, state):
        if state == 'committed':
            raise OSError('simulated independent-volume failure')
        return actual(receipt, state)

    with patch('usuarios.privacy_services.write_receipt', side_effect=publish):
        response = client.post(DELETE, {'current_password': PASSWORD, 'confirm': True}, format='json')
    assert response.status_code == 202 and response.json()['code'] == 'deletion_pending_journal'
    assert not Usuario.objects.filter(pk=owner.pk).exists() and read_receipts()[0]['state'] == 'pending'
    call_command('sync_privacy_deletions', authoritative_live_database=True)
    assert read_receipts()[0]['state'] == 'committed' and AccountDeletionReceipt.objects.get().published


def test_export_wrong_password_size_limit_and_rate_limit(accounts, settings):
    owner, other, place, client, _ = accounts
    assert client.post(EXPORT, {'current_password': 'incorrect'}, format='json').status_code == 400
    settings.PRIVACY_EXPORT_MAX_ROWS = 0
    Favorito.objects.create(user=owner, local=place)
    assert client.post(EXPORT, {'current_password': PASSWORD}, format='json').status_code == 400
    settings.PRIVACY_EXPORT_MAX_ROWS = 10000
    settings.PRIVACY_EXPORT_MAX_BYTES = 20
    assert client.post(EXPORT, {'current_password': PASSWORD}, format='json').status_code == 400
    assert client.post(EXPORT, {'current_password': PASSWORD}, format='json').status_code == 429


def test_retention_prunes_history_but_preserves_current_decision(accounts):
    owner, _, _, client, _ = accounts
    old = timezone.now() - timedelta(days=181)
    obsolete = PrivacyConsent.objects.create(user=owner, purpose='route_history', notice_version='old',
                                             granted=True, recorded_at=old)
    current = PrivacyConsent.objects.create(user=owner, purpose='route_history', notice_version='old',
                                            granted=False, recorded_at=old + timedelta(seconds=1))
    AccountMailJob.objects.create(user=owner, kind='reset', created_at=old)
    call_command('prune_account_state')
    assert not PrivacyConsent.objects.filter(pk=obsolete.pk).exists()
    assert PrivacyConsent.objects.filter(pk=current.pk).exists() and not AccountMailJob.objects.exists()


@pytest.mark.django_db(transaction=True)
def test_p08_postgresql_concurrent_deletion_is_atomic_and_repeatable(accounts):
    if connection.vendor != 'postgresql':
        pytest.skip('Requires real PostgreSQL row locks.')
    owner, _, _, _, token = accounts
    barrier = threading.Barrier(2)

    def remove():
        close_old_connections()
        try:
            client = APIClient()
            client.credentials(HTTP_AUTHORIZATION=f'Token {token.key}')
            barrier.wait(timeout=10)
            return client.post(DELETE, {'current_password': PASSWORD, 'confirm': True}, format='json').status_code
        finally:
            close_old_connections()

    with ThreadPoolExecutor(max_workers=2) as pool:
        outcomes = sorted(pool.map(lambda _: remove(), range(2)))
    assert outcomes == [204, 401]
    assert AccountDeletionReceipt.objects.count() == 1 and len(read_receipts()) == 1
