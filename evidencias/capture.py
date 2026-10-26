"""Capture only changed resource values; a new OSM import is not a confirmation."""

from contextlib import contextmanager
from contextvars import ContextVar
from datetime import datetime
import hashlib
import json
import uuid

from django.db import transaction
from django.utils import timezone
from django.utils.dateparse import parse_datetime

from acessoja.accessibility_catalog import RESOURCE_IDS
from .models import EvidenceRevision, ExternalEvidenceGuard, ResourceEvidence, ReviewRevision

NAMESPACE = uuid.UUID("f57861b2-d946-47f0-b105-254b320786dc")
ANSWER_STATES = {
    "yes": "presence_reported",
    "no": "absence_reported",
    "unknown": "unknown",
    "not_applicable": "not_applicable",
}
ACTOR = ContextVar("evidence_actor", default=None)


@contextmanager
def evidence_actor(user):
    token = ACTOR.set(user if user and user.is_authenticated else None)
    try:
        yield
    finally:
        ACTOR.reset(token)


def stamp(value):
    if isinstance(value, datetime):
        return value if timezone.is_aware(value) else None
    if isinstance(value, str):
        try:
            result = parse_datetime(value)
            return result if result and timezone.is_aware(result) else None
        except (ValueError, TypeError):
            return None
    return None


def fingerprint(values):
    return hashlib.sha256(
        json.dumps(
            {key: values.get(key) for key in ("state", "note", "observed_at", "observed_on")},
            sort_keys=True,
            default=str,
            ensure_ascii=True,
            separators=(",", ":"),
        ).encode()
    ).hexdigest()


def lock_external_sources(pairs):
    keys = sorted(
        {hashlib.sha256(f"{identity}:{resource}".encode()).hexdigest() for identity, resource in pairs}
    )
    if keys:
        ExternalEvidenceGuard.objects.bulk_create(
            [ExternalEvidenceGuard(key=key) for key in keys], ignore_conflicts=True
        )
        list(ExternalEvidenceGuard.objects.filter(key__in=keys).order_by("key").select_for_update())


@transaction.atomic
def capture_batch(specifications):
    """Fixed query batches; caller holds source/author lock for mutable content."""
    specs = {item["key"]: item for item in specifications}
    if not specs:
        return []
    lock_external_sources(
        (item.get("external_id"), item["resource"]) for item in specs.values() if item["kind"] == "osm"
    )
    roots = [
        ResourceEvidence(id=uuid.uuid5(NAMESPACE, key), key=key, resource=item["resource"], kind=item["kind"])
        for key, item in specs.items()
    ]
    ResourceEvidence.objects.bulk_create(roots, ignore_conflicts=True)
    rows = list(
        ResourceEvidence.objects.filter(key__in=specs)
        .order_by("key")
        .select_related("current_revision")
        .select_for_update(of=("self",))
    )
    revoked = set(
        EvidenceRevision.objects.filter(evidence_id__in=[row.pk for row in rows], is_valid=False).values_list(
            "evidence_id", "fingerprint"
        )
    )
    osm_ids = {spec.get("external_id") for spec in specs.values() if spec["kind"] == "osm"}
    denied_osm = (
        set(
            EvidenceRevision.objects.filter(
                evidence__kind="osm", evidence__external_id__in=osm_ids, is_valid=False
            ).values_list("evidence__external_id", "evidence__resource", "fingerprint")
        )
        if osm_ids
        else set()
    )
    revisions = []
    for root in rows:
        spec = specs[root.key]
        value = {
            "state": spec["state"],
            "note": spec.get("note", ""),
            "observed_at": stamp(spec.get("observed_at")),
            "observed_on": spec.get("observed_on"),
        }
        signature = fingerprint(value)
        previous = root.current_revision
        if previous is None or previous.fingerprint != signature:
            revision = EvidenceRevision(
                evidence=root,
                number=previous.number + 1 if previous else 1,
                fingerprint=signature,
                **value,
                received_at=(
                    timezone.now() if previous and root.kind != "osm" else stamp(spec.get("received_at"))
                ),
                actor_id=spec.get("owner_id"),
                source_metadata=spec.get("source_metadata", {}),
                is_valid=not (
                    root.kind == "osm"
                    and (
                        (root.pk, signature) in revoked
                        or (spec.get("external_id"), root.resource, signature) in denied_osm
                    )
                ),
            )
            revisions.append(revision)
            root.current_revision = revision
            root.source = spec.get("source", "not_recorded")
            root.owner_id = spec.get("owner_id")
        root.local_id = spec.get("local_id")
        root.external_id = spec.get("external_id", "")
        root.review_id = spec.get("review_id")
        root.source_metadata = spec.get("source_metadata", {})
        root.withdrawn = False
    EvidenceRevision.objects.bulk_create(revisions)
    ResourceEvidence.objects.bulk_update(
        rows,
        [
            "current_revision",
            "source",
            "owner",
            "local",
            "external_id",
            "review",
            "source_metadata",
            "withdrawn",
        ],
    )
    return rows


def review_payload(review):
    return {
        "estrelas": review.estrelas,
        "comentario": review.comentario,
        "questionnaire_version": review.questionnaire_version,
        "answers": review.answers,
        "answer_dates": review.answer_dates,
        **{f"pergunta_{index}": getattr(review, f"pergunta_{index}") for index in range(1, 5)},
    }


def capture_review(review):
    # Read persisted fields: save(update_fields=...) must not capture other dirty attributes.
    from modal_avaliacao.models import ModalAvaliacao

    review = ModalAvaliacao.objects.get(pk=review.pk)
    ReviewRevision.objects.get_or_create(
        id=review.content_revision,
        defaults={
            "review": review,
            "owner_id": review.user_id,
            "payload": review_payload(review),
            "recorded_at": timezone.now(),
            "original_submission_at": review.data_resposta,
        },
    )
    specs = []
    if review.questionnaire_version == 2:
        for resource, code in (review.answers or {}).items():
            if resource in RESOURCE_IDS and code in ANSWER_STATES:
                specs.append(
                    {
                        "key": f"review:{review.pk}:{resource}",
                        "kind": "review",
                        "source": "user",
                        "resource": resource,
                        "state": ANSWER_STATES[code],
                        "local_id": review.local_id,
                        "review_id": review.pk,
                        "owner_id": review.user_id,
                        "received_at": (review.answer_dates or {}).get(resource),
                    }
                )
    capture_batch(specs)
    ResourceEvidence.objects.filter(review=review, kind="review").exclude(
        key__in=[item["key"] for item in specs]
    ).update(withdrawn=True)


def capture_registration(local):
    user = ACTOR.get()
    specs = []
    for resource, value in (local.accessibility_information or {}).items():
        if (
            resource not in RESOURCE_IDS
            or not isinstance(value, dict)
            or value.get("state") not in {"presence_reported", "absence_reported", "unknown"}
        ):
            continue
        source = (
            ("administrative" if user.is_staff and user.is_superuser else "user")
            if user
            else ("administrative" if value.get("source") == "acessoja_staff_update" else "not_recorded")
        )
        specs.append(
            {
                "key": f"registration:{local.pk}:{resource}",
                "kind": "registration",
                "source": source,
                "local_id": local.pk,
                "resource": resource,
                **{key: value.get(key) for key in ("state", "observed_at", "received_at")},
                "note": value.get("note", ""),
                "owner_id": user.pk if user else None,
            }
        )
    capture_batch(specs)
    ResourceEvidence.objects.filter(local=local, kind="registration").exclude(
        key__in=[item["key"] for item in specs]
    ).update(withdrawn=True)


def catalog_specs(entries):
    from locais.accessibility import osm_information

    for entry in entries:
        for resource, value in osm_information(entry.tags).items():
            yield {
                "key": f"catalog:{entry.poi.external_id}:{resource}",
                "kind": "osm",
                "source": "openstreetmap",
                "resource": resource,
                "state": value["state"],
                "external_id": entry.poi.external_id,
                "local_id": entry.poi.local_id,
                "received_at": entry.observed_in.finished_at,
                "source_metadata": {
                    "channel": "municipal_catalog",
                    "external_id": entry.poi.external_id,
                    "snapshot_at": iso(entry.observed_in.snapshot_at),
                    "imported_at": iso(entry.observed_in.finished_at),
                    "osm_modified_at": iso(entry.osm_timestamp),
                    "osm_version": entry.osm_version,
                    "batch": str(entry.observed_in_id),
                    "source_status": entry.source_status,
                },
            }


def iso(value):
    return value.isoformat() if value else None


def sync_catalog_batch(batch):
    from locais.catalog_models import CatalogEntry

    entries = (
        CatalogEntry.objects.filter(batch=batch)
        .select_related("poi", "batch", "observed_in")
        .order_by("poi_id")
    )
    chunk = []
    for entry in entries.iterator(chunk_size=250):
        chunk.append(entry)
        if len(chunk) == 250:
            sync_catalog_entries(chunk)
            chunk = []
    if chunk:
        sync_catalog_entries(chunk)


def sync_catalog_entries(entries):
    specs = list(catalog_specs(entries))
    capture_batch(specs)
    keys = [item["key"] for item in specs]
    identities = [entry.poi.external_id for entry in entries]
    ResourceEvidence.objects.filter(
        kind="osm", external_id__in=identities, key__startswith="catalog:"
    ).exclude(key__in=keys).update(withdrawn=True)


def sync_remote_places(places):
    from locais.accessibility import osm_information

    now = timezone.now()
    specs, identities = [], []
    for place in places:
        identity = place.get("external_id")
        if not isinstance(identity, str):
            continue
        identities.append(identity)
        for resource, value in osm_information(place.get("accessibility_data")).items():
            specs.append(
                {
                    "key": f"remote:{identity}:{resource}",
                    "kind": "osm",
                    "source": "openstreetmap",
                    "resource": resource,
                    "state": value["state"],
                    "external_id": identity,
                    "received_at": now,
                    "source_metadata": {
                        "channel": "remote_osm",
                        "external_id": identity,
                        "snapshot_at": None,
                        "osm_modified_at": None,
                    },
                }
            )
    capture_batch(specs)
    ResourceEvidence.objects.filter(
        kind="osm", external_id__in=identities, key__startswith="remote:"
    ).exclude(key__in=[item["key"] for item in specs]).update(withdrawn=True)
