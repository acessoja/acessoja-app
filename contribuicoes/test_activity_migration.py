import pytest
from django.db import connection
from django.db.migrations.executor import MigrationExecutor
from django.utils import timezone


@pytest.mark.django_db(transaction=True)
def test_activity_metadata_migration_preserves_old_ledger_without_inventing_a_cause():
    executor = MigrationExecutor(connection)
    leaves = executor.loader.graph.leaf_nodes()
    previous = [target for target in leaves if target[0] != "contribuicoes"] + [("contribuicoes", "0001_initial")]
    try:
        executor.migrate(previous)
        apps = executor.loader.project_state(previous).apps
        user = apps.get_model("usuarios", "Usuario").objects.create(
            nome="legado", email="legado@test.com", password="historical-hash", data_criacao=timezone.now()
        )
        place = apps.get_model("locais", "Local").objects.create(nome="Biblioteca", endereco="Centro", distancia=0)
        event = apps.get_model("contribuicoes", "ContributionPointEvent").objects.create(
            user=user, local=place, action="review", points=10, idempotency_key="old-domain-key"
        )
        activity = apps.get_model("contribuicoes", "PointActivity").objects.create(
            event=event, delta=10, idempotency_key="old-domain-key:1"
        )
        original = (activity.pk, activity.delta, activity.created_at, activity.idempotency_key)
        executor = MigrationExecutor(connection)
        executor.migrate(leaves)
        from .models import PointActivity

        current = PointActivity.objects.get(pk=original[0])
        assert (current.pk, current.delta, current.created_at, current.idempotency_key) == original
        assert current.operation == "recorded" and current.reason == "legacy"
        assert current.source_evaluation_id is None
    finally:
        MigrationExecutor(connection).migrate(leaves)
