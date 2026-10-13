from django.conf import settings
from django.db import transaction
from django.db.models import Sum

from usuarios.models import Usuario
from modal_avaliacao.models import ModalAvaliacao
from modal_avaliacao.questionnaire import complete
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
ACTIONS = ("review", "survey", "useful_comment")


def eligible_reviews(user):
    return ModalAvaliacao.objects.filter(
        user=user, is_current=True, is_valid=True, verified_author=True, estrelas__range=(1, 5)
    )


def _achievement_counts(user):
    reviews = eligible_reviews(user)
    return {
        "reviews": reviews.count(),
        "surveys": sum(_survey_complete(review) for review in reviews),
        "categories": reviews.exclude(local__categoria="").values("local__categoria").distinct().count(),
    }


@transaction.atomic
def achievement_data(user, persist=False):
    user = Usuario.objects.select_for_update().get(pk=user.pk)
    counts = _achievement_counts(user)
    for code, _, _, metric, target in ACHIEVEMENTS:
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
            "progress": min(counts[metric], target),
            "target": target,
            "unlocked": code in earned and earned[code].active,
            "unlocked_at": earned[code].unlocked_at if code in earned else None,
        }
        for code, name, description, metric, target in ACHIEVEMENTS
    ]


def _survey_complete(review):
    return review.survey_completed and complete(
        review.questionnaire_version, review.answers, [getattr(review, f"pergunta_{i}") for i in range(1, 5)]
    )


def _criteria(review):
    eligible = bool(
        review and review.verified_author and review.is_current and review.is_valid and 1 <= review.estrelas <= 5
    )
    return {
        "review": eligible,
        "survey": eligible and _survey_complete(review),
        "useful_comment": eligible and review.comment_verified and bool(review.comentario.strip()),
    }


def _revocation_reason(review, action, hint=None):
    if review is None:
        return "review_removed"
    if not review.is_current:
        return "review_archived"
    if not review.verified_author:
        return "author_unverified"
    if not review.is_valid or not 1 <= review.estrelas <= 5:
        return "review_invalidated"
    if action == "survey":
        return "survey_incomplete"
    return "comment_changed" if hint == "comment_changed" else "comment_unapproved"


def _place_plan(user, local_id, hint=None, origin_id=None):
    # Derive eligibility from committed source rows, never from a stale signal.
    review = ModalAvaliacao.objects.filter(user=user, local_id=local_id, is_current=True).first()
    criteria = _criteria(review)
    events = {
        event.action: event
        for event in ContributionPointEvent.objects.filter(user=user, local_id=local_id).select_related("evaluation")
    }
    plans = []
    for action in ACTIONS:
        active = criteria[action]
        event = events.get(action)
        if event is None and not active:
            continue
        points = settings.CONTRIBUTION_POINTS[action]
        ledger = PointActivity.objects.filter(event=event) if event else PointActivity.objects.none()
        ledger_total = ledger.aggregate(total=Sum("delta"))["total"] or 0
        expected = points if active else 0
        old_balance = event.points if event and event.active else 0
        state_changed = bool(event and event.active != active)
        points_changed = bool(event and event.points != points)
        source_changed = bool(event and active and event.evaluation_id != review.pk)
        delta = expected - ledger_total
        if event and not (state_changed or points_changed or source_changed or delta):
            continue
        if event is None:
            operation, reason = "granted", f"{action}_eligible"
        elif state_changed:
            operation = "restored" if active else "revoked"
            source = review or event.evaluation
            reason = "eligibility_restored" if active else _revocation_reason(source, action, hint)
        else:
            operation = "reconciled"
            reason = "points_reconciled" if points_changed else "ledger_reconciled"
        source_id = review.pk if review else event.evaluation_id if event else None
        if source_id is None:
            source_id = ledger.exclude(source_evaluation_id=None).values_list("source_evaluation_id", flat=True).first()
        if source_id is None:
            source_id = origin_id
        plans.append(
            {
                "local_id": local_id,
                "action": action,
                "active": active,
                "points": points,
                "delta": delta,
                "balance_delta": expected - old_balance,
                "operation": operation,
                "reason": reason,
                "source_evaluation_id": source_id,
                "record_activity": event is None or state_changed or points_changed or bool(delta),
                "_event": event,
                "_review": review,
            }
        )
    return plans


def _apply_plan(user, plans):
    for plan in plans:
        event = plan["_event"]
        key = f"{user.pk}:{plan['local_id']}:{plan['action']}"
        if event is None:
            event = ContributionPointEvent.objects.create(
                user=user,
                local_id=plan["local_id"],
                evaluation=plan["_review"],
                action=plan["action"],
                points=plan["points"],
                active=plan["active"],
                idempotency_key=key,
            )
        else:
            event.active = plan["active"]
            event.points = plan["points"]
            if plan["active"]:
                event.evaluation = plan["_review"]
            if plan["record_activity"]:
                # Repair an outdated counter without replacing the audit trail.
                revisions = [event.revision]
                prefix = f"{event.idempotency_key}:"
                for value in PointActivity.objects.filter(event=event).values_list("idempotency_key", flat=True):
                    suffix = value.removeprefix(prefix)
                    if value.startswith(prefix) and suffix.isdigit():
                        revisions.append(int(suffix))
                event.revision = max(revisions) + 1
            event.save(update_fields=["active", "points", "evaluation", "revision"])
        if plan["record_activity"]:
            PointActivity.objects.create(
                event=event,
                delta=plan["delta"],
                idempotency_key=f"{event.idempotency_key}:{event.revision}",
                operation=plan["operation"],
                reason=plan["reason"],
                source_evaluation_id=plan["source_evaluation_id"],
            )


@transaction.atomic
def sync_evaluation(evaluation, deleted=False):
    user = Usuario.objects.select_for_update().get(pk=evaluation.user_id)
    plans = _place_plan(
        user,
        evaluation.local_id,
        hint=getattr(evaluation, "_contribution_reason", None),
        origin_id=evaluation.pk if deleted else None,
    )
    _apply_plan(user, plans)
    achievement_data(user, persist=True)
    return plans


@transaction.atomic
def reconcile_user(user_id, apply=False):
    user = Usuario.objects.select_for_update().get(pk=user_id)
    places = set(ModalAvaliacao.objects.filter(user=user).values_list("local_id", flat=True))
    places.update(ContributionPointEvent.objects.filter(user=user).values_list("local_id", flat=True))
    plans = [plan for local_id in sorted(places) for plan in _place_plan(user, local_id)]
    counts = _achievement_counts(user)
    stored = {row.code: row.active for row in UserAchievement.objects.filter(user=user)}
    badges_changed = sum(
        stored.get(code, False) != (counts[metric] >= target) for code, _, _, metric, target in ACHIEVEMENTS
    )
    before = ContributionPointEvent.objects.filter(user=user, active=True).aggregate(total=Sum("points"))["total"] or 0
    if apply:
        _apply_plan(user, plans)
        achievement_data(user, persist=True)
    return {
        "user_id": user_id,
        "points_before": before,
        "points_after": before + sum(plan["balance_delta"] for plan in plans),
        "events_changed": len(plans),
        "achievements_changed": badges_changed,
        "changes": [{key: value for key, value in plan.items() if not key.startswith("_")} for plan in plans],
        "unknown_actions": list(
            ContributionPointEvent.objects.filter(user=user)
            .exclude(action__in=ACTIONS)
            .values_list("action", flat=True)
        ),
    }


@transaction.atomic
def impact(user):
    user = Usuario.objects.select_for_update().get(pk=user.pk)
    events = ContributionPointEvent.objects.filter(user=user, active=True)
    points = events.aggregate(total=Sum("points"))["total"] or 0
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
        "contributions_count": events.count(),
        "history_count": PointActivity.objects.filter(event__user=user).count(),
        "achievements_count": sum(a["unlocked"] for a in achievements),
        "achievements": achievements,
        "profile": {"name": user.nome_completo or user.nome, "photo": user.foto_perfil},
        "reliability": "Participação elegível; não certifica precisão nem acessibilidade.",
        "rules": settings.CONTRIBUTION_POINTS,
    }
