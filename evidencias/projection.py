"""The same public-only evidence set drives summaries, filters and detail pages."""

from collections import defaultdict
from datetime import datetime, timezone as datetime_timezone

from django.conf import settings
from django.db.models import Count, Max, Q
from django.utils import timezone

from acessoja.accessibility_catalog import RESOURCE_IDS
from acessoja.questionnaire_v3 import BY_ID, DIMENSIONS, SCALE_IDS
from locais.accessibility import combine_states
from .models import EvidenceConfirmation, ResourceEvidence

STATES_ANSWERS = {
    "presence_reported": "yes",
    "absence_reported": "no",
    "unknown": "unknown",
    "not_applicable": "not_applicable",
}
SOURCES = {
    "user": "acessoja_community",
    "administrative": "acessoja_staff_update",
    "openstreetmap": "openstreetmap",
    "not_recorded": "not_recorded",
}


def visible_query():
    return (
        Q(
            kind="review",
            review__is_current=True,
            review__is_valid=True,
            review__user__is_active=True,
            review__user__mostrar_avaliacoes=True,
        )
        | Q(kind="observation", owner__is_active=True, owner__mostrar_avaliacoes=True)
        | Q(kind__in=["registration", "osm"])
    )


def public_evidence(local_ids=(), external_ids=(), include_invalid=False, include_inactive=False):
    scope = Q(local_id__in=list(local_ids)) | Q(external_id__in=list(external_ids))
    rows = ResourceEvidence.objects.filter(scope, visible_query(), current_revision__isnull=False)
    if not include_inactive:
        rows = rows.filter(withdrawn=False, superseded=False)
    if not include_invalid:
        rows = rows.filter(current_revision__is_valid=True)
    return rows.select_related("current_revision", "owner")


def effective(records):
    latest, independent = {}, []
    minimum = datetime.min.replace(tzinfo=datetime_timezone.utc)
    for row in records:
        if getattr(row, "superseded", False) or getattr(row, "withdrawn", False):
            continue
        if row.source != "user" or row.owner_id is None:
            independent.append(row)
            continue
        key = (row.resource, row.owner_id)
        current = latest.get(key)
        stamp = row.current_revision.received_at or minimum
        prior = current.current_revision.received_at if current else None
        if current is None or (stamp, str(row.pk)) > (prior or minimum, str(current.pk)):
            latest[key] = row
    return [*independent, *latest.values()]


def confirmation_stats(records):
    ids = [row.current_revision_id for row in records]
    return {
        row["revision_id"]: row
        for row in EvidenceConfirmation.objects.filter(revision_id__in=ids)
        .values("revision_id")
        .annotate(count=Count("user_id"), latest=Max("confirmed_at"))
    }


def freshness(revision, confirmed_at=None, now=None):
    now = now or timezone.now()
    observed = revision.observed_at or revision.observed_on
    reference = confirmed_at or observed or revision.received_at
    kind = (
        "confirmed_at"
        if confirmed_at
        else (
            "observed_at"
            if revision.observed_at
            else "observed_on" if revision.observed_on else "received_at" if revision.received_at else None
        )
    )
    days = settings.ACCESSIBILITY_FRESHNESS_DAYS
    if kind == "observed_on":
        known = reference <= now.date()
        recent = known and (now.date() - reference).days <= days
    else:
        known = reference is not None and reference <= now
        recent = known and (now - reference).total_seconds() <= days * 86400
    state = (
        "recent_confirmation"
        if recent and confirmed_at
        else (
            "recent_observation"
            if recent and observed
            else "recent_record" if recent else "no_recent_confirmation" if known else "date_unknown"
        )
    )
    return {
        "state": state,
        "reference_kind": kind if known else None,
        "reference_at": reference.isoformat() if known else None,
        "threshold_days": days,
        "evaluated_at": now.isoformat(),
        "reason": "known_reference" if known else "missing_or_future_reference",
    }


def resource_summary(records, legacy=0, statistics=None):
    records = effective(records)
    confirmations = statistics if statistics is not None else confirmation_stats(records) if records else {}
    grouped = defaultdict(list)
    for row in records:
        grouped[row.resource].append(row)
    result = {}
    for resource in RESOURCE_IDS:
        rows = grouped[resource]
        sources = defaultdict(list)
        counts = dict.fromkeys(["yes", "no", "unknown", "not_applicable"], 0)
        for row in rows:
            sources[row.source].append(row)
            answer = STATES_ANSWERS.get(row.current_revision.state)
            if row.source == "user" and answer:
                counts[answer] += 1
        evidence = []
        for source, items in sources.items():
            received = [row.current_revision.received_at for row in items if row.current_revision.received_at]
            observed = [row.current_revision.observed_at for row in items if row.current_revision.observed_at]
            observed_on = [row.current_revision.observed_on for row in items if row.current_revision.observed_on]
            confirmed = [
                confirmations[row.current_revision_id]["latest"]
                for row in items
                if row.current_revision_id in confirmations
            ]
            latest = max(
                items,
                key=lambda row: freshness(
                    row.current_revision, confirmations.get(row.current_revision_id, {}).get("latest")
                )["reference_at"]
                or "",
            )
            evidence.append(
                {
                    "source": SOURCES.get(source, "not_recorded"),
                    "source_kind": source,
                    "kind": (
                        "community" if source == "user" else "external" if source == "openstreetmap" else "registration"
                    ),
                    "state": combine_states(row.current_revision.state for row in items),
                    "received_at": max(received).isoformat() if received else None,
                    "observed_at": max(observed).isoformat() if observed else None,
                    "confirmed_at": max(confirmed).isoformat() if confirmed else None,
                    "observed_on": max(observed_on).isoformat() if observed_on else None,
                    "counts": counts if source == "user" else {},
                    "respondents": len(items),
                    "freshness": freshness(
                        latest.current_revision,
                        confirmations.get(latest.current_revision_id, {}).get("latest"),
                    ),
                }
            )
        result[resource] = {
            "state": combine_states(row.current_revision.state for row in rows),
            "evidence": evidence,
            "community_state": combine_states(row.current_revision.state for row in rows if row.source == "user"),
            "legacy_not_comparable": legacy,
            "dimension": BY_ID[resource]["dimension"],
            "variable": resource in SCALE_IDS,
            "observations": [
                {**row.source_metadata["observation"],
                 "observed_on": row.current_revision.observed_on,
                 "received_at": row.current_revision.received_at,
                 "note": row.current_revision.note}
                for row in rows if row.source == "user" and resource in SCALE_IDS
                and row.source_metadata.get("observation")
            ],
            "provenance": {
                "evidence_count": len(rows),
                "sources": sorted(sources),
                "has_divergence": any(row.current_revision.state == "presence_reported" for row in rows)
                and any(row.current_revision.state == "absence_reported" for row in rows),
                "observation_is_not_visit": True,
            },
        }
    return result


# Community badges use only current, public user evidence. Three independent
# reporters across three resources form the minimum cross-feature quorum; a
# higher highlight requires five reporters, half the catalog covered, and a
# three-reporter quorum on every positively recognized resource. These gates
# prevent a single review or repeated edits by one author from creating a seal.
COMMUNITY_RECOGNITION_REPORTERS = 3
COMMUNITY_RECOGNITION_RESOURCES = 3
COMMUNITY_RESOURCE_QUORUM = 2
COMMUNITY_HIGHLIGHT_REPORTERS = 5
COMMUNITY_HIGHLIGHT_RESOURCE_QUORUM = 3


def community_classification(records, statistics=None, now=None):
    """Return an explainable community-only accessibility projection.

    This is deliberately independent of general star ratings and excludes
    invalid, withdrawn, superseded, private, and non-user assertions.
    """
    confirmations = statistics if statistics is not None else confirmation_stats(records) if records else {}
    current = [
        row for row in effective(records)
        if row.source == "user"
        and row.owner_id is not None
        and row.current_revision.is_valid
        and row.current_revision.state in {"presence_reported", "absence_reported", "limited"}
    ]
    fresh = [
        row for row in current
        if freshness(
            row.current_revision,
            confirmations.get(row.current_revision_id, {}).get("latest"),
            now=now,
        )["state"] in {"recent_confirmation", "recent_observation", "recent_record"}
    ]
    authors = {row.owner_id for row in current}
    recent_authors = {row.owner_id for row in fresh}
    by_resource = defaultdict(list)
    for row in current:
        by_resource[row.resource].append(row)
    fresh_positive = defaultdict(set)
    for row in fresh:
        if row.current_revision.state == "presence_reported":
            fresh_positive[row.resource].add(row.owner_id)

    positive_resources = sorted(
        resource for resource, rows in by_resource.items()
        if any(row.current_revision.state == "presence_reported" for row in rows)
    )
    barrier_resources = sorted(
        resource for resource, rows in by_resource.items()
        if any(row.current_revision.state in {"absence_reported", "limited"} for row in rows)
    )
    divergent_resources = sorted(set(positive_resources).intersection(barrier_resources))
    assessed_resources = sorted(set(positive_resources).union(barrier_resources))
    has_positive = bool(positive_resources)
    has_barrier = bool(barrier_resources)
    status = "not_evaluated"
    if has_barrier:
        status = "partially_accessible" if has_positive else "barriers_identified"
    else:
        positive_quorum = [
            resource for resource in positive_resources
            if len(fresh_positive[resource]) >= COMMUNITY_RESOURCE_QUORUM
        ]
        if (
            len(recent_authors) >= COMMUNITY_RECOGNITION_REPORTERS
            and len(positive_quorum) >= COMMUNITY_RECOGNITION_RESOURCES
            and len(positive_quorum) == len(positive_resources)
        ):
            status = "well_regarded"
            half_catalog = (len(RESOURCE_IDS) + 1) // 2
            highlight_quorum = [
                resource for resource in positive_resources
                if len(fresh_positive[resource]) >= COMMUNITY_HIGHLIGHT_RESOURCE_QUORUM
            ]
            if (
                len(recent_authors) >= COMMUNITY_HIGHLIGHT_REPORTERS
                and len(positive_resources) >= half_catalog
                and len(highlight_quorum) == len(positive_resources)
                and {BY_ID[key]["dimension"] for key in highlight_quorum} == set(DIMENSIONS)
            ):
                status = "community_highlight"

    return {
        "status": status,
        "independent_assessors": len(authors),
        "recent_independent_assessors": len(recent_authors),
        "resources_assessed": len(assessed_resources),
        "resources_positive": len(positive_resources),
        "resources_with_barriers": len(barrier_resources),
        "resources_unknown": len(RESOURCE_IDS) - len(assessed_resources),
        "divergent_resources": divergent_resources,
        "is_official_certification": False,
        "dimensions": {
            dimension: {
                "positive": [key for key in positive_resources if BY_ID[key]["dimension"] == dimension],
                "barriers": [key for key in barrier_resources if BY_ID[key]["dimension"] == dimension],
                "divergent": [key for key in divergent_resources if BY_ID[key]["dimension"] == dimension],
                "state": (
                    "barriers_identified" if any(BY_ID[key]["dimension"] == dimension for key in barrier_resources)
                    else "positive_reports" if any(BY_ID[key]["dimension"] == dimension for key in positive_resources)
                    else "insufficient_information"
                ),
            } for dimension in DIMENSIONS
        },
    }


def detail_document(row, statistics=None, user=None):
    revision = row.current_revision
    stats = (statistics or {}).get(revision.pk, {})
    supported = revision.state in {"presence_reported", "absence_reported", "limited", "not_applicable"}
    return {
        "id": str(row.pk),
        "resource": row.resource,
        "revision": str(revision.pk),
        "state": revision.state,
        "source": row.source,
        "note": revision.note,
        "observation": getattr(revision, "source_metadata", row.source_metadata).get("observation", {}),
        "observed_at": revision.observed_at,
        "observed_on": revision.observed_on,
        "received_at": revision.received_at,
        "confirmed_at": stats.get("latest"),
        "confirmations": stats.get("count", 0),
        "freshness": freshness(revision, stats.get("latest")),
        "reference": row.source_metadata if row.kind == "osm" else {"channel": row.kind},
        "can_confirm": supported,
        "can_report": supported and (not user or not user.is_authenticated or row.owner_id != user.pk),
        "can_update": True,
    }
