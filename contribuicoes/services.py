from django.conf import settings
from django.db import transaction
from django.db.models import Sum

from usuarios.models import Usuario
from modal_avaliacao.models import ModalAvaliacao
from .models import ContributionPointEvent, PointActivity, UserAchievement

LEVELS = [
    (0, "Semente da Inclusão"),
    (30, "Colaborador"),
    (100, "Explorador Acessível"),
    (300, "Referência da Comunidade"),
    (750, "Guardião da Acessibilidade"),
]
ACHIEVEMENTS = [
    ("first", "Primeiro Passo", "Publique uma avaliação válida.", "reviews", 1),
    ("attentive", "Olhar Atento", "Responda cinco pesquisas de acessibilidade.", "surveys", 5),
    ("voice", "Voz da Inclusão", "Publique dez avaliações válidas.", "reviews", 10),
    ("explorer", "Explorador da Cidade", "Avalie três categorias diferentes.", "categories", 3),
    ("guardian", "Guardião da Comunidade", "Publique vinte avaliações válidas.", "reviews", 20),
]


def eligible_reviews(user):
    return ModalAvaliacao.objects.filter(
        user=user, is_current=True, is_valid=True, verified_author=True, estrelas__range=(1, 5)
    )


def achievement_data(user, persist=False):
    reviews = eligible_reviews(user)
    counts = {
        "reviews": reviews.count(),
        "surveys": reviews.filter(survey_completed=True).count(),
        "categories": reviews.exclude(local__categoria="").values("local__categoria").distinct().count(),
    }
    for code, _, _, metric, target in ACHIEVEMENTS:
        metric = "surveys" if code == "attentive" else metric
        active = counts[metric] >= target
        if persist and active:
            UserAchievement.objects.get_or_create(user=user, code=code)
        if persist:
            UserAchievement.objects.filter(user=user, code=code).update(active=active)
    earned = {a.code: a for a in UserAchievement.objects.filter(user=user)}
    return [
        {
            "code": code,
            "name": name,
            "description": description,
            "icon": code,
            "progress": min(counts["surveys" if code == "attentive" else metric], target),
            "target": target,
            "unlocked": code in earned and earned[code].active,
            "unlocked_at": earned[code].unlocked_at if code in earned else None,
        }
        for code, name, description, metric, target in ACHIEVEMENTS
    ]


@transaction.atomic
def sync_evaluation(evaluation, deleted=False):
    # One lock order for create/edit/delete/admin/signals. PostgreSQL serializes
    # competing requests by author; UNIQUE remains the final duplicate guard.
    user = Usuario.objects.select_for_update().get(pk=evaluation.user_id)
    from modal_avaliacao.models import RESPOSTAS

    answers = [value for value, _ in RESPOSTAS]
    eligible = (
        not deleted
        and evaluation.verified_author
        and evaluation.is_current
        and evaluation.is_valid
        and 1 <= evaluation.estrelas <= 5
    )
    criteria = {
        "review": eligible,
        "survey": eligible
        and evaluation.survey_completed
        and all(getattr(evaluation, f"pergunta_{i}") in answers for i in range(1, 5)),
        "useful_comment": eligible and evaluation.comment_verified and bool(evaluation.comentario.strip()),
    }
    for action, active in criteria.items():
        key = f"{user.pk}:{evaluation.local_id}:{action}"
        event = ContributionPointEvent.objects.filter(idempotency_key=key).first()
        if event is None and active:
            points = settings.CONTRIBUTION_POINTS[action]
            event = ContributionPointEvent.objects.create(
                user=user,
                local_id=evaluation.local_id,
                evaluation=evaluation,
                action=action,
                points=points,
                idempotency_key=key,
            )
            PointActivity.objects.create(event=event, delta=points, idempotency_key=f"{key}:1")
        elif event is not None:
            # An archived duplicate must not revoke the current review's award.
            if not evaluation.is_current and event.evaluation_id != evaluation.pk:
                continue
            if event.active != active:
                event.active = active
                event.revision += 1
                PointActivity.objects.create(
                    event=event,
                    delta=event.points if active else -event.points,
                    idempotency_key=f"{key}:{event.revision}",
                )
            if active:
                event.evaluation = evaluation
            event.save(update_fields=["active", "revision", "evaluation"])
    achievement_data(user, persist=True)


def impact(user):
    points = ContributionPointEvent.objects.filter(user=user, active=True).aggregate(total=Sum("points"))["total"] or 0
    index = max(i for i, (minimum, _) in enumerate(LEVELS) if points >= minimum)
    minimum, title = LEVELS[index]
    next_minimum = LEVELS[index + 1][0] if index + 1 < len(LEVELS) else None
    achievements = achievement_data(user)
    reviews = eligible_reviews(user)
    return {
        "points": points,
        "level": index + 1,
        "title": title,
        "next_level_points": next_minimum,
        "remaining_points": max(0, next_minimum - points) if next_minimum else 0,
        "progress": min(1, (points - minimum) / (next_minimum - minimum)) if next_minimum else 1,
        "reviews": reviews.count(),
        "places": reviews.values("local").distinct().count(),
        "achievements_count": sum(a["unlocked"] for a in achievements),
        "achievements": achievements,
        "profile": {"name": user.nome_completo or user.nome, "photo": user.foto_perfil},
        "reliability": "Participação elegível; não certifica precisão nem acessibilidade.",
        "rules": settings.CONTRIBUTION_POINTS,
    }
