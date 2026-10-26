"""Use only known receipt dates. Never infer an observation or migrate consent."""

from datetime import datetime
import hashlib
import json
import uuid

from django.db import migrations
from django.utils.dateparse import parse_datetime
from django.utils import timezone

NAMESPACE = uuid.UUID("f57861b2-d946-47f0-b105-254b320786dc")
RESOURCES = {
    "rampa_acesso",
    "banheiro_acessivel",
    "vagas_reservadas",
    "mesa_acessivel",
    "cardapio_braille",
    "atendimento_libras",
    "sinalizacao_tatil",
    "cao_guia",
}
STATES = {
    "yes": "presence_reported",
    "no": "absence_reported",
    "unknown": "unknown",
    "not_applicable": "not_applicable",
}


def known_date(value):
    if isinstance(value, datetime):
        return value if timezone.is_aware(value) else None
    if isinstance(value, str):
        try:
            value = parse_datetime(value)
            return value if value and timezone.is_aware(value) else None
        except (ValueError, TypeError):
            return None
    return None


def backfill(apps, schema_editor):
    db = schema_editor.connection.alias
    Root = apps.get_model("evidencias", "ResourceEvidence")
    Revision = apps.get_model("evidencias", "EvidenceRevision")
    Snapshot = apps.get_model("evidencias", "ReviewRevision")
    Review = apps.get_model("modal_avaliacao", "ModalAvaliacao")
    Local = apps.get_model("locais", "Local")
    Entry = apps.get_model("locais", "CatalogEntry")
    Scope = apps.get_model("locais", "CatalogScope")

    def store(
        key,
        resource,
        kind,
        source,
        state,
        local_id=None,
        owner_id=None,
        review_id=None,
        external_id="",
        received=None,
        observed=None,
        note="",
        metadata=None,
    ):
        values = {"state": state, "note": note, "observed_at": known_date(observed), "observed_on": None}
        signature = hashlib.sha256(
            json.dumps(values, sort_keys=True, default=str, ensure_ascii=True, separators=(",", ":")).encode()
        ).hexdigest()
        root = Root.objects.using(db).create(
            id=uuid.uuid5(NAMESPACE, key),
            key=key,
            resource=resource,
            kind=kind,
            source=source,
            local_id=local_id,
            owner_id=owner_id,
            review_id=review_id,
            external_id=external_id,
            source_metadata=metadata or {},
        )
        revision = Revision.objects.using(db).create(
            evidence=root,
            number=1,
            fingerprint=signature,
            **values,
            received_at=known_date(received),
            actor_id=owner_id,
            source_metadata=metadata or {},
        )
        Root.objects.using(db).filter(pk=root.pk).update(current_revision=revision)

    for review in Review.objects.using(db).iterator():
        Snapshot.objects.using(db).create(
            id=review.content_revision,
            review=review,
            owner_id=review.user_id,
            recorded_at=None,
            original_submission_at=review.data_resposta,
            payload={
                key: getattr(review, key)
                for key in [
                    "estrelas",
                    "comentario",
                    "questionnaire_version",
                    "answers",
                    "answer_dates",
                    *(f"pergunta_{i}" for i in range(1, 5)),
                ]
            },
        )
        if review.questionnaire_version == 2:
            for resource, answer in (review.answers or {}).items():
                if resource in RESOURCES and answer in STATES:
                    store(
                        f"review:{review.pk}:{resource}",
                        resource,
                        "review",
                        "user",
                        STATES[answer],
                        local_id=review.local_id,
                        owner_id=review.user_id,
                        review_id=review.pk,
                        received=(review.answer_dates or {}).get(resource),
                    )
    for local in Local.objects.using(db).iterator():
        for resource, value in (local.accessibility_information or {}).items():
            if (
                resource in RESOURCES
                and isinstance(value, dict)
                and value.get("state") in {"presence_reported", "absence_reported", "unknown"}
            ):
                store(
                    f"registration:{local.pk}:{resource}",
                    resource,
                    "registration",
                    "administrative" if value.get("source") == "acessoja_staff_update" else "not_recorded",
                    value["state"],
                    local_id=local.pk,
                    received=value.get("received_at"),
                    observed=value.get("observed_at"),
                    note=value.get("note", ""),
                )
    batches = list(
        Scope.objects.using(db).exclude(active_batch=None).values_list("active_batch_id", flat=True)
    )
    for entry in (
        Entry.objects.using(db).filter(batch_id__in=batches).select_related("poi", "observed_in").iterator()
    ):
        state = {"yes": "presence_reported", "no": "absence_reported", "limited": "limited"}.get(
            (entry.tags or {}).get("toilets:wheelchair")
        )
        if state:
            store(
                f"catalog:{entry.poi.external_id}:banheiro_acessivel",
                "banheiro_acessivel",
                "osm",
                "openstreetmap",
                state,
                local_id=entry.poi.local_id,
                external_id=entry.poi.external_id,
                received=entry.observed_in.finished_at,
                metadata={
                    "channel": "municipal_catalog",
                    "external_id": entry.poi.external_id,
                    "snapshot_at": (
                        entry.observed_in.snapshot_at.isoformat() if entry.observed_in.snapshot_at else None
                    ),
                    "osm_modified_at": entry.osm_timestamp.isoformat() if entry.osm_timestamp else None,
                    "batch": str(entry.observed_in_id),
                },
            )


class Migration(migrations.Migration):
    dependencies = [("evidencias", "0001_initial")]
    operations = [migrations.RunPython(backfill, migrations.RunPython.noop)]
