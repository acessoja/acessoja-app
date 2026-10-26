"""Render effective per-author assertions without writing questionnaire answers or points."""

from locais.models import Local
from modal_avaliacao.questionnaire import summarize
from .projection import effective, public_evidence, resource_summary, STATES_ANSWERS


def public_questionnaire(local_id, review_rows, quality=None):
    if quality is None:
        identity = Local.objects.filter(pk=local_id).values_list("osm_id", flat=True).first()
        roots = list(public_evidence([local_id], [identity] if identity else []))
        statistics = None
    else:
        roots, statistics = quality
    roots = effective([row for row in roots if row.current_revision.is_valid])
    users = {row["user_id"]: {**row, "answers": {}, "answer_dates": {}} for row in review_rows}
    for root in roots:
        if (
            root.source != "user"
            or root.owner_id is None
            or root.current_revision.state not in STATES_ANSWERS
        ):
            continue
        row = users.setdefault(
            root.owner_id,
            {
                "user_id": root.owner_id,
                "is_current": True,
                "is_valid": True,
                "questionnaire_version": 2,
                "answers": {},
                "answer_dates": {},
            },
        )
        row["questionnaire_version"] = 2
        row["answers"][root.resource] = STATES_ANSWERS[root.current_revision.state]
        received = root.current_revision.received_at
        if received:
            row["answer_dates"][root.resource] = received.isoformat()
    result = summarize(users.values())
    result["accessibility"] = resource_summary(roots, statistics=statistics)
    legacy = sum(row.get("questionnaire_version", 1) != 2 for row in review_rows)
    result["legacy_not_comparable"] = legacy
    for feature in result["features"]:
        feature["legacy_not_comparable"] = legacy
    return result
