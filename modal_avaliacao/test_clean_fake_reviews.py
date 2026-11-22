from io import StringIO
from pathlib import Path

import pytest
from django.conf import settings
from django.core.management import call_command
from django.core.management.base import CommandError
from django.contrib.auth import get_user_model
from django.db import connection

from evidencias.models import ResourceEvidence, ReviewRevision
from locais.models import Local
from modal_avaliacao.management.commands.clean_fake_reviews import Command
from modal_avaliacao.models import ModalAvaliacao

pytestmark = pytest.mark.django_db


def _records():
    user = get_user_model().objects.create_user(
        nome="cleanup-test", email="cleanup-test@example.test", password="securepass"
    )
    local = Local.objects.create(nome="Lugar teste", endereco="Rua", distancia=0)
    review = ModalAvaliacao.objects.create(
        user=user,
        local=local,
        estrelas=4,
        questionnaire_version=3,
        answers={"espaco_tranquilo": "yes"},
    )
    return user, local, review


def test_cleanup_defaults_to_dry_run_and_preserves_development_data():
    user, local, review = _records()
    call_command("clean_fake_reviews", stdout=StringIO())
    assert ModalAvaliacao.objects.filter(pk=review.pk).exists()
    assert ReviewRevision.objects.filter(review=review).exists()
    assert ResourceEvidence.objects.filter(review=review, kind="review").exists()
    assert Local.objects.filter(pk=local.pk).exists()
    assert get_user_model().objects.filter(pk=user.pk).exists()


def test_cleanup_refuses_non_project_test_database_without_mutation(tmp_path):
    user, local, review = _records()
    with pytest.raises(CommandError, match="requires DEBUG=True and BASE_DIR/db.sqlite3"):
        call_command(
            "clean_fake_reviews",
            execute=True,
            backup_path=str(tmp_path / "must-not-be-created.sqlite3"),
            stdout=StringIO(),
        )
    assert ModalAvaliacao.objects.filter(pk=review.pk).exists()
    assert Local.objects.filter(pk=local.pk).exists()
    assert get_user_model().objects.filter(pk=user.pk).exists()


@pytest.mark.django_db(transaction=True)
def test_cleanup_executes_only_after_verified_backup_and_is_repeatable(tmp_path, monkeypatch):
    user, local, review = _records()
    database = Path(connection.settings_dict["NAME"]).resolve()
    base = Path(settings.BASE_DIR).resolve()
    monkeypatch.setattr(Command, "_assert_development_sqlite", lambda self: (database, base))
    backup = tmp_path / "reviews-before-cleanup.sqlite3"
    output = StringIO()

    call_command("clean_fake_reviews", execute=True, backup_path=str(backup), stdout=output)

    assert backup.is_file()
    assert "Verified SQLite backup" in output.getvalue()
    assert not ModalAvaliacao.objects.filter(pk=review.pk).exists()
    assert not ResourceEvidence.objects.filter(review_id=review.pk, kind="review").exists()
    assert not ReviewRevision.objects.filter(review_id=review.pk).exists()
    assert Local.objects.filter(pk=local.pk).exists()
    assert get_user_model().objects.filter(pk=user.pk).exists()

    call_command("clean_fake_reviews", execute=True, backup_path=str(tmp_path / "unused.sqlite3"), stdout=StringIO())
    assert not (tmp_path / "unused.sqlite3").exists()
