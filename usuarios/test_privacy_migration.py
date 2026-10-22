from django.db import connection
from django.utils import timezone
from django.db.migrations.executor import MigrationExecutor
import pytest


@pytest.mark.django_db(transaction=True)
def test_p02_existing_users_get_distinct_privacy_ids_without_invented_consent():
    executor = MigrationExecutor(connection)
    previous = [('usuarios', '0005_usuario_route_history_revision_and_more')]
    latest = executor.loader.graph.leaf_nodes()
    try:
        executor.migrate(previous)
        old = executor.loader.project_state(previous).apps.get_model('usuarios', 'Usuario')
        for index in range(2):
            old.objects.create(nome=f'synthetic-legacy-{index}', email=f'legacy-{index}@example.test',
                               password='unusable-synthetic-fixture', data_criacao=timezone.now(),
                               save_route_history=True, save_route_origin=True)
        executor = MigrationExecutor(connection)
        target = [('usuarios', '0006_accountdeletionreceipt_usuario_credential_revision_and_more')]
        executor.migrate(target)
        state = executor.loader.project_state(target).apps
        users = state.get_model('usuarios', 'Usuario').objects.filter(nome__startswith='synthetic-legacy-')
        assert len(set(users.values_list('privacy_id', flat=True))) == 2
        assert all(users.values_list('save_route_history', flat=True))
        assert state.get_model('usuarios', 'PrivacyConsent').objects.count() == 0
    finally:
        MigrationExecutor(connection).migrate(latest)
