import json
from datetime import timedelta
from concurrent.futures import ThreadPoolExecutor
from io import StringIO
from threading import Barrier
from types import SimpleNamespace
from unittest.mock import patch

import pytest
from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.db import IntegrityError, close_old_connections, connection, transaction
from django.utils import timezone
from rest_framework.exceptions import PermissionDenied
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient

from evidencias.models import ContentReport, ModerationDecision, ReviewRevision
from evidencias.exceptions import RevisionConflict
from locais.models import Local, VisitaRecente
from modal_avaliacao.models import ModalAvaliacao
from .models import ContributionPointEvent, PointActivity, ReportRewardAttribution, UserAchievement
from .services import (
    impact,
    process_report_reward_for_decision,
    reconcile_user,
    set_report_reward_status,
    sync_evaluation,
)

User = get_user_model()
URL = "/api/avaliacoes/modal-avaliacoes/"


@pytest.fixture(autouse=True)
def clear_throttles():
    from django.core.cache import cache

    cache.clear()
    yield
    cache.clear()


@pytest.fixture
def author(db):
    return User.objects.create_user(nome="autor", email="autor@test.com", password="securepass")


@pytest.fixture
def place(db):
    return Local.objects.create(
        nome="Biblioteca", endereco="Centro", latitude=-16.3267, longitude=-48.9528, categoria="library", distancia=0
    )


@pytest.fixture
def client(author):
    client = APIClient()
    client.force_authenticate(author)
    return client


def payload(place, **extra):
    return {
        "local": place.pk,
        "estrelas": 4,
        "pergunta_1": "Sim",
        "pergunta_2": "Não",
        "pergunta_3": "Não sei",
        "pergunta_4": "Sim",
        "comentario": "Entrada com rampa.",
        **extra,
    }


def submit(client, place, **extra):
    return client.post(URL, payload(place, **extra), format="json")


@pytest.mark.parametrize(
    ("action", "effect_applied"),
    [
        ("start", False),
        ("keep", False),
        ("request_review", False),
        ("unavailable", False),
        ("invalidate", False),
    ],
)
@pytest.mark.django_db
def test_non_effective_moderation_decisions_cannot_award(action, effect_applied):
    decision = SimpleNamespace(
        action=action,
        effect_applied=effect_applied,
        report=SimpleNamespace(target_kind="review"),
    )
    assert process_report_reward_for_decision(decision) is None


@pytest.mark.django_db
def test_effective_non_review_report_cannot_award():
    decision = SimpleNamespace(
        action="invalidate",
        effect_applied=True,
        report=SimpleNamespace(target_kind="photo"),
    )
    assert process_report_reward_for_decision(decision) is None


def test_zero_points_and_private_summary(client, author):
    response = client.get("/api/contribuicoes/meu-impacto/")
    assert response.status_code == 200
    assert response.data["points"] == 0
    assert response.data["remaining_points"] == 30
    assert response.data["achievements_count"] == 0
    assert APIClient().get("/api/contribuicoes/meu-impacto/").status_code == 401


def test_report_upheld_awards_only_the_first_eligible_reporter(author, place):
    later_reporter = User.objects.create_user(
        nome="denunciante2",
        email="denuncia2@test.com",
        password="test-password",
    )
    reporter = User.objects.create_user(nome="denunciante", email="denuncia@test.com", password="securepass")
    review = ModalAvaliacao.objects.create(
        user=author,
        local=place,
        estrelas=4,
        verified_author=True,
        survey_completed=True,
        **{f"pergunta_{i}": "Não sei" for i in range(1, 5)},
    )
    revision = review.content_revision
    review_revision = ReviewRevision.objects.create(
        review=review,
        owner=author,
        payload={"estrelas": 4, "comentario": ""},
        recorded_at=timezone.now(),
        original_submission_at=timezone.now(),
    )
    self_report = ContentReport.objects.create(
        reporter=author,
        target_kind="review",
        target_key=f"review:{review.pk}",
        target_revision=revision,
        review_revision=review_revision,
        reason="incorrect",
        description="Conteúdo falso",
    )
    ContentReport.objects.filter(pk=self_report.pk).update(
        created_at=timezone.now() - timedelta(days=3)
    )
    inactive_reporter = User.objects.create_user(
        nome="conta inativa",
        email="inativa@test.com",
        password="test-password",
        is_active=False,
    )
    inactive_report = ContentReport.objects.create(
        reporter=inactive_reporter,
        target_kind="review",
        target_key=f"review:{review.pk}",
        target_revision=revision,
        review_revision=review_revision,
        reason="incorrect",
        description="Conteúdo falso",
    )
    ContentReport.objects.filter(pk=inactive_report.pk).update(
        created_at=timezone.now() - timedelta(days=2)
    )
    report = ContentReport.objects.create(
        reporter=reporter,
        target_kind="review",
        target_key=f"review:{review.pk}",
        target_revision=revision,
        review_revision=review_revision,
        reason="incorrect",
        description="Conteúdo falso",
    )
    ContentReport.objects.filter(pk=report.pk).update(created_at=timezone.now() - timedelta(days=1))
    later_report = ContentReport.objects.create(
        reporter=later_reporter,
        target_kind="review",
        target_key=f"review:{review.pk}",
        target_revision=revision,
        review_revision=review_revision,
        reason="incorrect",
        description="Conteúdo falso",
    )
    moderator = User.objects.create_user(nome="moderador", email="mod@test.com", password="securepass")
    moderator.is_superuser = True
    moderator.is_staff = True
    moderator.save()
    from evidencias.moderation import decide
    from uuid import uuid4

    operation_id = uuid4()
    with patch(
        "contribuicoes.services.PointActivity.objects.get_or_create",
        side_effect=RuntimeError("reward ledger failure"),
    ):
        with pytest.raises(RuntimeError, match="reward ledger failure"):
            decide(
                actor_id=moderator.pk,
                protocol=later_report.pk,
                action="invalidate",
                reason="Conteúdo falso e inadequado para a comunidade.",
                expected_version=1,
                expected_target_revision=report.target_revision,
                operation_id=operation_id,
                author_message="",
            )
    review.refresh_from_db()
    report.refresh_from_db()
    assert review.is_valid and report.state == "pending"
    assert not report.decisions.exists()

    decision = decide(
        actor_id=moderator.pk,
        protocol=later_report.pk,
        action="invalidate",
        reason="Conteúdo falso e inadequado para a comunidade.",
        expected_version=1,
        expected_target_revision=report.target_revision,
        operation_id=operation_id,
        author_message="",
    )
    assert decide(
        actor_id=moderator.pk,
        protocol=later_report.pk,
        action="invalidate",
        reason="Conteúdo falso e inadequado para a comunidade.",
        expected_version=1,
        expected_target_revision=report.target_revision,
        operation_id=operation_id,
        author_message="",
    ).pk == decision.pk
    with pytest.raises(RevisionConflict):
        decide(
            actor_id=moderator.pk,
            protocol=later_report.pk,
            action="invalidate",
            reason="Justificativa diferente para a mesma operação.",
            expected_version=1,
            expected_target_revision=report.target_revision,
            operation_id=operation_id,
            author_message="",
        )

    assert impact(reporter)["points"] == 5
    assert impact(later_reporter)["points"] == 0
    assert not ContributionPointEvent.objects.filter(
        user__in=[author, inactive_reporter], action="report_upheld"
    ).exists()
    assert ContributionPointEvent.objects.filter(user=reporter, action="report_upheld").count() == 1
    assert PointActivity.objects.filter(event__action="report_upheld").count() == 1
    assert PointActivity.objects.get(event__action="report_upheld").actor == moderator
    assert reconcile_user(reporter.pk, apply=True)["events_changed"] == 0
    assert impact(reporter)["points"] == 5

    report_client = APIClient()
    report_client.force_authenticate(reporter)
    own_reports = report_client.get("/api/denuncias/")
    assert own_reports.status_code == 200
    assert own_reports.data["results"][0]["reward_status"] == "granted"
    assert "moderator" not in own_reports.data["results"][0]

    attribution = ReportRewardAttribution.objects.get(review=review)
    with pytest.raises(PermissionDenied):
        set_report_reward_status(
            attribution.pk, later_reporter, status="revoked", reason="fraud"
        )

    second_author = User.objects.create_user(
        nome="outro autor",
        email="outro-autor@test.com",
        password="test-password",
    )
    second_review = ModalAvaliacao.objects.create(
        user=second_author,
        local=place,
        estrelas=4,
        verified_author=True,
    )
    second_revision = ReviewRevision.objects.create(
        review=second_review,
        owner=second_author,
        payload={"estrelas": 4, "comentario": ""},
        recorded_at=timezone.now(),
        original_submission_at=timezone.now(),
    )
    second_report = ContentReport.objects.create(
        reporter=reporter,
        target_kind="review",
        target_key=f"review:{second_review.pk}",
        target_revision=second_review.content_revision,
        review_revision=second_revision,
        reason="incorrect",
        description="Conteúdo falso",
    )
    decide(
        actor_id=moderator.pk,
        protocol=second_report.pk,
        action="invalidate",
        reason="Conteúdo falso e inadequado para a comunidade.",
        expected_version=1,
        expected_target_revision=second_report.target_revision,
        operation_id=uuid4(),
        author_message="",
    )
    assert impact(reporter)["points"] == 5
    assert ContributionPointEvent.objects.filter(
        user=reporter, action="report_upheld"
    ).count() == 1
    assert ReportRewardAttribution.objects.filter(
        beneficiary=reporter, local=place, action="report_upheld"
    ).count() == 1

    assert set_report_reward_status(attribution.pk, moderator, status="revoked", reason="fraud")
    assert impact(reporter)["points"] == 0
    assert not set_report_reward_status(attribution.pk, moderator, status="revoked", reason="fraud")
    assert set_report_reward_status(
        attribution.pk, moderator, status="granted", reason="fraud_cleared"
    )
    assert impact(reporter)["points"] == 5
    assert not set_report_reward_status(
        attribution.pk, moderator, status="granted", reason="fraud_cleared"
    )
    ModalAvaliacao.objects.filter(pk=review.pk).update(is_valid=True)
    assert impact(reporter)["points"] == 5
    assert list(
        PointActivity.objects.filter(event__action="report_upheld")
        .order_by("created_at")
        .values_list("delta", flat=True)
    ) == [5, -5, 5]
    assert PointActivity.objects.get(
        event__action="report_upheld", operation="revoked"
    ).actor == moderator
    assert reconcile_user(reporter.pk, apply=True)["events_changed"] == 0
    reward = ContributionPointEvent.objects.get(user=reporter, action="report_upheld")
    reward.delete()
    attribution.refresh_from_db()
    assert attribution.event_id is None
    before_activity_count = PointActivity.objects.count()
    preview = reconcile_user(reporter.pk, apply=False)
    assert preview["events_changed"] == 1 and preview["points_after"] == 5
    assert not ContributionPointEvent.objects.filter(user=reporter, action="report_upheld").exists()
    assert PointActivity.objects.count() == before_activity_count
    assert reconcile_user(reporter.pk, apply=True)["events_changed"] == 1
    attribution.refresh_from_db()
    assert attribution.event_id is not None
    assert impact(reporter)["points"] == 5


def test_reconcile_command_includes_reporters_without_reviews(author, place):
    from uuid import uuid4

    reporter = User.objects.create_user(
        nome="denunciante sem avaliação",
        email="reporter-without-review@test.com",
        password="securepass",
    )
    review = ModalAvaliacao.objects.create(
        user=author,
        local=place,
        estrelas=4,
        verified_author=True,
    )
    revision = ReviewRevision.objects.create(
        review=review,
        owner=author,
        payload={"estrelas": 4, "comentario": ""},
        recorded_at=timezone.now(),
        original_submission_at=timezone.now(),
    )
    report = ContentReport.objects.create(
        reporter=reporter,
        target_kind="review",
        target_key=f"review:{review.pk}",
        target_revision=review.content_revision,
        review_revision=revision,
        reason="incorrect",
        description="Conteúdo incorreto",
    )
    attribution = ReportRewardAttribution.objects.create(
        report=report,
        review=review,
        local=place,
        beneficiary=reporter,
        status="granted",
        idempotency_key=f"command-report:{uuid4()}",
        granted_at=timezone.now(),
    )

    output = StringIO()
    call_command("reconcile_contributions", "--json", stdout=output)
    preview = json.loads(output.getvalue())
    reporter_preview = next(row for row in preview["users"] if row["user_id"] == reporter.pk)
    assert reporter_preview["events_changed"] == 1
    assert preview["mode"] == "dry_run"
    assert attribution.event_id is None
    assert not ContributionPointEvent.objects.filter(user=reporter).exists()
    assert not PointActivity.objects.filter(event__user=reporter).exists()

    output = StringIO()
    call_command("reconcile_contributions", "--apply", "--json", stdout=output)
    applied = json.loads(output.getvalue())
    assert applied["events_changed"] == 1
    attribution.refresh_from_db()
    assert attribution.event_id is not None
    assert impact(reporter)["points"] == 5

    output = StringIO()
    call_command("reconcile_contributions", "--apply", "--json", stdout=output)
    repeated = json.loads(output.getvalue())
    assert repeated["events_changed"] == 0
    assert PointActivity.objects.filter(event__user=reporter).count() == 1


@pytest.mark.django_db(transaction=True)
def test_postgresql_concurrent_report_rewards_award_once(author, place):
    if connection.vendor != "postgresql":
        pytest.skip("Concurrent report reward uniqueness requires PostgreSQL.")

    from uuid import uuid4

    from evidencias.moderation import decide

    reporter = User.objects.create_user(
        nome="denunciante concorrente",
        email="concurrent-reporter@test.com",
        password="securepass",
    )
    moderators = [
        User.objects.create_superuser(
            nome=f"moderador {index}",
            email=f"moderator-{index}@test.com",
            password="securepass",
        )
        for index in range(2)
    ]
    cases = []
    for index in range(2):
        review_author = User.objects.create_user(
            nome=f"autor {index}",
            email=f"review-author-{index}@test.com",
            password="securepass",
        )
        review = ModalAvaliacao.objects.create(
            user=review_author,
            local=place,
            estrelas=4,
            verified_author=True,
        )
        revision = ReviewRevision.objects.create(
            review=review,
            owner=review_author,
            payload={"estrelas": 4, "comentario": ""},
            recorded_at=timezone.now(),
            original_submission_at=timezone.now(),
        )
        report = ContentReport.objects.create(
            reporter=reporter,
            target_kind="review",
            target_key=f"review:{review.pk}",
            target_revision=review.content_revision,
            review_revision=revision,
            reason="incorrect",
            description="Conteúdo incorreto",
        )
        cases.append((moderators[index].pk, report.pk, report.target_revision))

    barrier = Barrier(2)
    create_event = ContributionPointEvent.objects.create

    def synchronized_create(*args, **kwargs):
        if kwargs.get("action") == "report_upheld":
            barrier.wait(timeout=10)
        return create_event(*args, **kwargs)

    def process(case):
        close_old_connections()
        try:
            moderator_id, protocol, target_revision = case
            result = decide(
                actor_id=moderator_id,
                protocol=protocol,
                action="invalidate",
                reason="Conteúdo falso e inadequado para a comunidade.",
                expected_version=1,
                expected_target_revision=target_revision,
                operation_id=uuid4(),
                author_message="",
            )
            return result.effect_applied
        finally:
            close_old_connections()

    with patch(
        "contribuicoes.services.ContributionPointEvent.objects.create",
        side_effect=synchronized_create,
    ):
        with ThreadPoolExecutor(max_workers=2) as pool:
            effects = list(pool.map(process, cases))

    assert effects == [True, True]
    assert ModerationDecision.objects.filter(action="invalidate", effect_applied=True).count() == 2
    assert ContributionPointEvent.objects.filter(user=reporter, action="report_upheld").count() == 1
    assert ReportRewardAttribution.objects.filter(beneficiary=reporter, status="granted").count() == 1
    assert impact(reporter)["points"] == 5


def test_first_review_survey_persists_and_replay_cannot_award(client, place, author):
    response = submit(client, place, nome_usuario="outra-pessoa")
    assert response.status_code == 201
    assert response.data["points_delta"] == 15
    review = ModalAvaliacao.objects.get()
    assert review.user == author and review.verified_author
    assert submit(client, place).status_code == 409
    for _ in range(3):
        sync_evaluation(review)
        assert client.patch(f"{URL}{review.pk}/", {"estrelas": 5}, format="json").status_code == 200
    assert impact(author)["points"] == 15
    assert PointActivity.objects.count() == 2
    assert UserAchievement.objects.get(code="first").unlocked_at is not None
    assert place.media_estrelas == 5


@pytest.mark.parametrize(
    "field,value",
    [
        ("points", 9000),
        ("pontos", 9000),
        ("user", 42),
        ("verified_author", True),
        ("comment_verified", True),
        ("is_current", False),
        ("is_valid", True),
    ],
)
def test_client_cannot_control_points_author_or_moderation(client, place, field, value):
    assert submit(client, place, **{field: value}).status_code == 400
    assert not ModalAvaliacao.objects.exists()
    assert not ContributionPointEvent.objects.exists()


@pytest.mark.parametrize("stars", [0, -1, 6])
def test_invalid_rating_does_not_award(client, place, stars):
    assert submit(client, place, estrelas=stars).status_code == 400
    assert not ContributionPointEvent.objects.exists()


def test_anonymous_write_and_forged_name_rejected(author, place):
    assert submit(APIClient(), place, nome_usuario=author.nome).status_code == 401
    assert not ModalAvaliacao.objects.exists()


def test_only_author_can_edit_delete_or_move_review(client, author, place):
    review_id = submit(client, place).data["id"]
    other = User.objects.create_user(nome="outro", email="outro@test.com", password="securepass")
    outsider = APIClient()
    outsider.force_authenticate(other)
    assert outsider.patch(f"{URL}{review_id}/", {"estrelas": 2}, format="json").status_code == 403
    assert outsider.delete(f"{URL}{review_id}/").status_code == 403
    other_place = Local.objects.create(nome="Outro", endereco="Rua", distancia=0)
    assert client.patch(f"{URL}{review_id}/", {"local": other_place.pk}, format="json").status_code == 400
    assert ModalAvaliacao.objects.get().local == place


def test_delete_reverses_points_and_recreate_restores_only_once(client, author, place):
    pk = submit(client, place).data["id"]
    assert client.delete(f"{URL}{pk}/").status_code == 204
    assert impact(author)["points"] == 0
    assert sum(PointActivity.objects.values_list("delta", flat=True)) == 0
    assert not UserAchievement.objects.get(code="first").active
    assert submit(client, place).data["points_delta"] == 15
    assert ContributionPointEvent.objects.count() == 2
    assert impact(author)["points"] == 15


def test_comment_points_require_moderation_and_edit_revokes(client, author, place):
    pk = submit(client, place, comentario="x" * 500).data["id"]
    assert impact(author)["points"] == 15
    review = ModalAvaliacao.objects.get(pk=pk)
    review.comment_verified = True
    review.save()
    assert impact(author)["points"] == 20
    assert client.patch(f"{URL}{pk}/", {"comentario": "Outro texto"}, format="json").status_code == 200
    assert impact(author)["points"] == 15
    review.refresh_from_db()
    review.is_valid = False
    review.save()
    assert impact(author)["points"] == 0
    assert APIClient().get(f"{URL}{pk}/").status_code == 404
    review.is_valid = True
    review.save()
    assert impact(author)["points"] == 15


def test_levels_categories_and_achievement_progress(client, author, place):
    for i, category in enumerate(["library", "restaurant", "hospital", "school", "library"]):
        p = Local.objects.create(nome=f"Lugar {i}", endereco="Rua", distancia=0, categoria=category)
        assert submit(client, p).status_code == 201
    result = impact(author)
    assert result["points"] == 75 and result["level"] == 2
    assert result["remaining_points"] == 25
    assert result["places"] == 5
    assert result["achievements_count"] == 3
    for _ in range(2):
        call_command("reconcile_contributions")
    assert impact(author)["points"] == 75


def test_historical_uncertain_author_stays_without_points(client, author, place):
    review = ModalAvaliacao.objects.create(user=author, **payload(place, local=place))
    # Pass the FK as an instance; historical rows do not validate authors.
    assert not review.verified_author
    assert impact(author)["points"] == 0
    assert client.patch(f"{URL}{review.pk}/", {"estrelas": 3}, format="json").status_code == 200
    assert impact(author)["points"] == 0


def test_privacy_community_self_and_anonymized_place_reviews(client, author, place):
    pk = submit(client, place).data["id"]
    author.perfil_publico = False
    author.save()
    anon = APIClient()
    assert anon.get("/api/contribuicoes/comunidade/").data["count"] == 0
    public = anon.get(f"{URL}{pk}/").data
    assert public["nome_usuario"] == "Colaborador AcessoJá"
    assert public["user"] is None and not public["can_edit"]
    author.mostrar_avaliacoes = False
    author.save()
    assert anon.get(f"{URL}{pk}/").status_code == 404
    assert client.get("/api/contribuicoes/minhas-avaliacoes/").data["count"] == 1
    assert client.get("/api/contribuicoes/atividade/").data["count"] == 2


def test_own_profile_and_password_cannot_be_changed_by_name(client, author):
    other = User.objects.create_user(nome="vitima", email="v@test.com", password="oldpass")
    assert client.get("/api/usuarios/perfil/?nome=vitima").status_code == 403
    assert (
        client.put("/api/usuarios/perfil/?nome=vitima", {"email": "hacked@test.com"}, format="json").status_code == 403
    )
    assert (
        client.post(
            "/api/usuarios/alterar-senha/",
            {"nome": "vitima", "senha_atual": "oldpass", "nova_senha": "hackedpass"},
            format="json",
        ).status_code
        == 403
    )
    other.refresh_from_db()
    assert other.email == "v@test.com" and other.check_password("oldpass")


def test_token_login_expiration_logout_and_password_revocation(author):
    client = APIClient()
    login = client.post("/api/login/", {"nome": author.nome, "password": "securepass"}, format="json")
    assert login.status_code == 200 and login.data["token"]
    client.credentials(HTTP_AUTHORIZATION=f"Token {login.data['token']}")
    assert client.get("/api/contribuicoes/meu-impacto/").status_code == 200
    Token.objects.filter(user=author).update(created=timezone.now() - timedelta(days=1))
    assert client.get("/api/contribuicoes/meu-impacto/").status_code == 401
    client.credentials()
    token = client.post("/api/login/", {"nome": author.nome, "password": "securepass"}, format="json").data["token"]
    client.credentials(HTTP_AUTHORIZATION=f"Token {token}")
    assert client.post("/api/usuarios/logout/").status_code == 200
    assert client.get("/api/contribuicoes/meu-impacto/").status_code == 401
    client.credentials()
    token = client.post("/api/login/", {"nome": author.nome, "password": "securepass"}, format="json").data["token"]
    client.credentials(HTTP_AUTHORIZATION=f"Token {token}")
    assert (
        client.post(
            "/api/usuarios/alterar-senha/",
            {"nome": author.nome, "senha_atual": "securepass", "nova_senha": "newsecurepass"},
            format="json",
        ).status_code
        == 200
    )
    assert not Token.objects.filter(user=author).exists()


def test_real_admin_permissions(author):
    admin = User.objects.create_superuser(nome="admin", email="admin@test.com", password="securepass")
    assert admin.is_staff and admin.is_superuser and admin.has_perm("any.permission")
    assert not author.has_perm("any.permission")
    with pytest.raises(ValueError):
        User.objects.create_superuser(nome="bad", email="bad@test.com", password="securepass", is_staff=False)


def test_database_uniqueness_and_atomic_rollback(client, author, place):
    pk = submit(client, place).data["id"]
    with pytest.raises(IntegrityError), transaction.atomic():
        ModalAvaliacao.objects.create(user=author, local=place, estrelas=2)
    assert ModalAvaliacao.objects.get(pk=pk).estrelas == 4
    place2 = Local.objects.create(nome="Falha", endereco="Rua", distancia=0)
    with patch("contribuicoes.services.PointActivity.objects.create", side_effect=RuntimeError("rollback")):
        with pytest.raises(RuntimeError):
            submit(client, place2)
    assert not ModalAvaliacao.objects.filter(local=place2).exists()
    assert impact(author)["points"] == 15


def test_discovery_filters_pagination_coordinates_and_visits(client, author, place):
    assert client.get("/api/contribuicoes/locais-para-avaliar/?estado=unreviewed").data["count"] == 1
    assert client.get("/api/contribuicoes/locais-para-avaliar/?latitude=NaN&longitude=0").status_code == 400
    assert client.get("/api/contribuicoes/locais-para-avaliar/?latitude=0").status_code == 400
    assert client.get("/api/contribuicoes/locais-para-avaliar/?raio=50000").status_code == 400
    submit(client, place)
    assert client.get("/api/contribuicoes/locais-para-avaliar/?estado=unreviewed").data["count"] == 0
    assert client.get("/api/contribuicoes/locais-para-avaliar/?estado=incomplete").data["count"] == 1
    assert client.get("/api/contribuicoes/locais-para-avaliar/?search=Biblioteca&categoria=library").data["count"] == 1
    VisitaRecente.objects.create(user=author, local=place)
    assert client.get("/api/contribuicoes/locais-para-avaliar/?estado=visited").data["count"] == 0
    VisitaRecente.objects.create(user=author, local=place, arrival_confirmed=True)
    assert client.get("/api/contribuicoes/locais-para-avaliar/?estado=visited").data["count"] == 1
    geo = client.get("/api/contribuicoes/locais-para-avaliar/?latitude=-16.3267&longitude=-48.9528")
    assert geo.data["results"][0]["distance_meters"] == 0
    assert client.get(f"{URL}?local_id=node/1").status_code == 400


def test_arrival_requires_consent_precise_location_and_owner(client, author, place):
    url = "/api/visitas/"
    data = {"local": place.pk, "latitude": place.latitude, "longitude": place.longitude, "accuracy": 5}
    author.historico_visivel = False
    author.save()
    assert client.post(url, data, format="json").status_code == 403
    author.historico_visivel = True
    author.compartilhar_localizacao = True
    author.save()
    assert client.post(url, {**data, "accuracy": 200}, format="json").status_code == 400
    assert client.post(url, {**data, "latitude": 0}, format="json").status_code == 400
    assert client.post(url, data, format="json").status_code == 201
    assert VisitaRecente.objects.get().arrival_confirmed
    assert client.get(url).data[0]["arrival_confirmed"]


@pytest.mark.django_db(transaction=True)
def test_postgresql_concurrent_replay_awards_once():
    if connection.vendor != "postgresql":
        pytest.skip("Row-lock concurrency must run on PostgreSQL, not SQLite.")
    author = User.objects.create_user(nome="concurrent", email="c@test.com", password="securepass")
    place = Local.objects.create(nome="Concorrência", endereco="Rua", distancia=0)
    barrier = Barrier(2)

    def worker():
        close_old_connections()
        client = APIClient()
        client.force_authenticate(User.objects.get(pk=author.pk))
        barrier.wait(timeout=10)
        try:
            return submit(client, place).status_code
        finally:
            close_old_connections()

    with ThreadPoolExecutor(max_workers=2) as pool:
        codes = list(pool.map(lambda _: worker(), range(2)))
    assert sorted(codes) == [201, 409]
    assert impact(author)["points"] == 15
    assert ModalAvaliacao.objects.filter(user=author).count() == 1
    assert PointActivity.objects.count() == 2
