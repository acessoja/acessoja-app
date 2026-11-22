"""Render effective per-author assertions without writing questionnaire answers or points."""

from locais.models import Local
from acessoja.accessibility_catalog import RESOURCE_IDS
from .projection import effective, public_evidence, resource_summary


def public_questionnaire(local_id, review_rows, quality=None):
    if quality is None:
        identity = Local.objects.filter(pk=local_id).values_list("osm_id", flat=True).first()
        roots = list(public_evidence([local_id], [identity] if identity else []))
        statistics = None
    else:
        roots, statistics = quality
    roots = effective([row for row in roots if row.current_revision.is_valid])
    accessibility = resource_summary(roots, statistics=statistics)
    current_reviews = [row for row in review_rows if row.get("is_current", True)]
    v3_people = {
        row["user_id"]
        for row in current_reviews
        if row.get("is_valid", True) and row.get("questionnaire_version") == 3
    }
    legacy = sum(
        row.get("is_valid", True)
        and row.get("questionnaire_version", 1) in (1, 2)
        for row in current_reviews
    )
    features = []
    for resource in RESOURCE_IDS:
        summary = accessibility[resource]
        community = next(
            (row for row in summary["evidence"] if row["source_kind"] == "user"),
            None,
        )
        counts = community["counts"] if community else dict.fromkeys(
            ("yes", "no", "unknown", "not_applicable"), 0
        )
        respondents = community["respondents"] if community else 0
        latest = community["received_at"] if community else None
        features.append({
            "id": resource,
            "counts": counts,
            "unanswered": max(0, len(v3_people) - respondents),
            "latest_at": latest,
            "state": summary["community_state"] or "not_evaluated",
            "respondents": respondents,
            "few_reviews": 0 < respondents < 3,
            "legacy_not_comparable": legacy,
            "dimension": summary["dimension"],
            "variable": summary["variable"],
        })
    return {
        "version": 3,
        "people": len(v3_people),
        "legacy_not_comparable": legacy,
        "excluded_invalid": sum(not row.get("is_valid", True) for row in current_reviews),
        "duplicates_excluded": 0,
        "features": features,
        "date_kind": "answer_received_at",
        "accessibility": accessibility,
    }
