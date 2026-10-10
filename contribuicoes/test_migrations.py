import pytest
from django.db import connection
from django.db.migrations.executor import MigrationExecutor
from django.utils import timezone


@pytest.mark.django_db(transaction=True)
def test_historical_duplicates_are_preserved_without_points_or_fake_admins():
    executor = MigrationExecutor(connection)
    latest = executor.loader.graph.leaf_nodes()
    old = [
        ("locais", "0006_local_categoria_local_osm_id"),
        ("usuarios", "0002_usuario_compartilhar_localizacao_usuario_foto_perfil_and_more"),
        ("modal_avaliacao", "0003_alter_modalavaliacao_comentario"),
    ]
    try:
        executor.migrate(old)
        apps = executor.loader.project_state(old).apps
        user = apps.get_model("usuarios", "Usuario").objects.create(
            nome="histórico", email="h@test.com", password="unused", data_criacao=timezone.now()
        )
        place = apps.get_model("locais", "Local").objects.create(nome="Local antigo", endereco="Rua", distancia=0)
        Review = apps.get_model("modal_avaliacao", "ModalAvaliacao")
        first = Review.objects.create(local=place, user=user, estrelas=2)
        second = Review.objects.create(local=place, user=user, estrelas=5)
        executor = MigrationExecutor(connection)
        executor.migrate(latest)
        apps = executor.loader.project_state(latest).apps
        saved = apps.get_model("modal_avaliacao", "ModalAvaliacao").objects.filter(user_id=user.pk)
        assert saved.count() == 2
        assert not saved.get(pk=first.pk).is_current
        assert saved.get(pk=second.pk).is_current
        assert not saved.filter(verified_author=True).exists()
        assert apps.get_model("contribuicoes", "ContributionPointEvent").objects.count() == 0
        user = apps.get_model("usuarios", "Usuario").objects.get(pk=user.pk)
        assert not user.is_staff and not user.is_superuser
    finally:
        executor = MigrationExecutor(connection)
        executor.migrate(executor.loader.graph.leaf_nodes())
