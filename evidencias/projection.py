"""The same public-only evidence set drives summaries, filters and detail pages."""

from collections import defaultdict
from datetime import datetime, timezone as datetime_timezone

from django.conf import settings
from django.db.models import Count, Max, Q
from django.utils import timezone

from acessoja.accessibility_catalog import RESOURCE_IDS
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


def public_evidence(local_ids=(), external_ids=(), include_invalid=False):
    scope = Q(local_id__in=list(local_ids)) | Q(external_id__in=list(external_ids))
    rows = ResourceEvidence.objects.filter(
        scope, visible_query(), withdrawn=False, current_revision__isnull=False
    )
    if not include_invalid:
        rows = rows.filter(current_revision__is_valid=True)
    return rows.select_related("current_revision", "owner")


def effective(records):
    latest, independent = {}, []
    minimum = datetime.min.replace(tzinfo=datetime_timezone.utc)
    for row in records:
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
            observed_on = [
                row.current_revision.observed_on for row in items if row.current_revision.observed_on
            ]
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
                        "community"
                        if source == "user"
                        else "external" if source == "openstreetmap" else "registration"
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
            "community_state": combine_states(
                row.current_revision.state for row in rows if row.source == "user"
            ),
            "legacy_not_comparable": legacy,
            "provenance": {
                "evidence_count": len(rows),
                "sources": sorted(sources),
                "has_divergence": any(row.current_revision.state == "presence_reported" for row in rows)
                and any(row.current_revision.state == "absence_reported" for row in rows),
                "observation_is_not_visit": True,
            },
        }
    return result


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
