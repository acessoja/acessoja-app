"""Batch evidence loading with the same visibility policy as Card 15."""
from collections import defaultdict

from django.db.models import Q

from modal_avaliacao.models import ModalAvaliacao
from locais.accessibility import resolve_information


def populate_accessibility_context(locals_, context):
    locals_ = list(locals_)
    request = context.get("request")
    user = getattr(request, "user", None)
    own_id = user.pk if user and user.is_authenticated else None
    visible = Q(is_valid=True, user__mostrar_avaliacoes=True)
    if own_id is not None:
        visible |= Q(user_id=own_id)
    grouped = defaultdict(list)
    rows = ModalAvaliacao.objects.filter(local_id__in=[local.pk for local in locals_], is_current=True).filter(
        visible
    ).order_by("local_id", "user_id", "-data_resposta", "-pk").values(
        "local_id", "user_id", "is_current", "is_valid", "questionnaire_version", "answers", "answer_dates", "estrelas",
    )
    for row in rows:
        grouped[row["local_id"]].append(row)
    states = context.setdefault("accessibility_states", {})
    stats = context.setdefault("visible_review_stats", {})
    for local in locals_:
        local_rows = grouped[local.pk]
        states[(local.pk, own_id)] = resolve_information(local.accessibility_information, local_rows)
        ratings = [row["estrelas"] for row in local_rows if row["is_valid"] and 1 <= row["estrelas"] <= 5]
        stats[(local.pk, own_id)] = {"count": len(ratings),
                                     "average": sum(ratings) / len(ratings) if ratings else None}
    return context


def local_accessibility(local, context):
    request = context.get("request")
    user = getattr(request, "user", None)
    own_id = user.pk if user and user.is_authenticated else None
    key = (local.pk, own_id)
    if key not in context.get("accessibility_states", {}):
        populate_accessibility_context([local], context)
    return context["accessibility_states"][key]
