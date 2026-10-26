"""Export/import a public Anapolis OSM snapshot without cloning the application DB.

Intentional: no Local/user/review/confirmation/moderation or private data.
The source catalog snapshot stays immutable after publication. Importing into
an already populated catalog refuses to replace active editions.
"""

import hashlib
import json
import math
import re
import uuid
from datetime import datetime
from pathlib import Path
from urllib.parse import urlsplit

from django.core.management.base import CommandError
from django.db import transaction

from locais.catalog_models import CatalogBatch, CatalogEntry, CatalogPOI, CatalogScope
from locais.services.catalog_rules import ALLOWED_TAGS, MUNICIPALITY, RULES_VERSION

FORMAT = "acessoja-osm-demo-v1"
MAX_ENTRIES = 10000
MAX_FILE_BYTES = 16 * 1024 * 1024
FIELDS = (
    "original_name", "display_name", "category", "address", "latitude",
    "longitude", "geometry_type", "point_method", "crosses_boundary",
    "access_restriction", "tags", "resource_states", "search_text",
    "source_status", "osm_version", "osm_timestamp", "content_hash",
)
# All are public-source provenance. Do not copy path fields, raw import reports,
# request headers, authentication data, operator notes or review data.
MANIFEST_FIELDS = (
    "provider", "url", "sha256", "bytes", "obtained_at", "processed_at",
    "snapshot_at", "full_snapshot_attested", "attribution", "license", "license_url",
)


def _iso(value):
    return value.isoformat() if value is not None else None


def _canonical(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode("utf-8")


def _fingerprint(payload):
    return hashlib.sha256(_canonical(payload)).hexdigest()


def _source_metadata(manifest):
    return {key: manifest[key] for key in MANIFEST_FIELDS if key in manifest}


def _batch_record(batch):
    return {
        "id": str(batch.pk), "state": batch.state,
        "fingerprint": batch.fingerprint, "rules_version": batch.rules_version,
        "boundary_hash": batch.boundary_hash, "snapshot_at": _iso(batch.snapshot_at),
        "complete": batch.complete, "created_at": _iso(batch.created_at),
        "finished_at": _iso(batch.finished_at),
        "source": _source_metadata(batch.manifest or {}),
    }


def export_public_catalog():
    scope = CatalogScope.objects.select_related("active_batch").filter(pk=MUNICIPALITY).first()
    if not scope or not scope.active_batch_id:
        raise CommandError("Nenhum catalogo municipal ativo. Use o banco do Card 34 primeiro.")
    active = scope.active_batch
    if active.state not in ("published", "partial"):
        raise CommandError("O lote ativo nao esta publicado.")
    rows = list(
        CatalogEntry.objects.filter(batch=active).select_related("poi", "observed_in")
        .order_by("poi__osm_type", "poi__osm_number")
    )
    if not rows or len(rows) > MAX_ENTRIES:
        raise CommandError("Quantidade de registros inesperada para exportacao demo.")

    observed_batches = {str(active.pk): active}
    entries = []
    for row in rows:
        poi = row.poi
        if poi.source != "openstreetmap" or poi.osm_type not in ("node", "way", "relation"):
            raise CommandError("Fonte ou tipo OSM inesperado no catalogo.")
        observed_batches[str(row.observed_in_id)] = row.observed_in
        attributes = {key: getattr(row, key) for key in FIELDS}
        attributes["osm_timestamp"] = _iso(attributes["osm_timestamp"])
        attributes["tags"] = {
            k: v for k, v in (row.tags or {}).items()
            if k in ALLOWED_TAGS and isinstance(v, str) and len(v) <= 255
        }
        # Source fields only; intentionally discard poi.local_id and link_method:
        # Local belongs to a community DB and must not be transplanted.
        entries.append({
            "osm_type": poi.osm_type,
            "osm_number": poi.osm_number,
            "external_id": poi.external_id,
            "observed_in": str(row.observed_in_id),
            "first_seen": _iso(poi.first_seen),
            "last_seen": _iso(poi.last_seen),
            **attributes,
        })

    payload = {
        "format": FORMAT,
        "municipality": MUNICIPALITY,
        "active_batch_id": str(active.pk),
        "batches": [_batch_record(observed_batches[k]) for k in sorted(observed_batches)],
        "entries": entries,
        "attribution": "© OpenStreetMap contributors",
        "license": "ODbL-1.0",
        "license_url": "https://www.openstreetmap.org/copyright",
    }
    return {"sha256": _fingerprint(payload), "payload": payload}


def _valid_uuid(value):
    try:
        return str(uuid.UUID(str(value)))
    except (ValueError, TypeError, AttributeError):
        raise CommandError("UUID invalido no catalogo.") from None


def _valid_datetime(value):
    if value is None:
        return None
    if not isinstance(value, str):
        raise CommandError("Data invalida no catalogo.")
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        raise CommandError("Formato de data invalido no catalogo.") from None
    if dt.tzinfo is None:
        raise CommandError("Datas do catalogo devem conter timezone.")
    return dt


def validate_public_catalog(data):
    if not isinstance(data, dict) or set(data) != {"sha256", "payload"}:
        raise CommandError("Arquivo de catalogo invalido.")
    payload = data["payload"]
    if not isinstance(payload, dict) or _fingerprint(payload) != data["sha256"]:
        raise CommandError("Hash SHA-256 do catalogo nao confere.")
    if set(payload) != {"format", "municipality", "active_batch_id", "batches", "entries",
                        "attribution", "license", "license_url"}:
        raise CommandError("Campos inesperados no catalogo.")
    if payload["attribution"] != "© OpenStreetMap contributors" or payload["license"] != "ODbL-1.0" or \
            payload["license_url"] != "https://www.openstreetmap.org/copyright":
        raise CommandError("Atribuicao ou licenca OSM ausente.")
    if payload.get("format") != FORMAT or payload.get("municipality") != MUNICIPALITY:
        raise CommandError("Formato ou municipio nao suportado.")
    batches, entries = payload.get("batches"), payload.get("entries")
    if not isinstance(batches, list) or not isinstance(entries, list):
        raise CommandError("Listas de lotes e estabelecimentos obrigatorias.")
    if not (1 <= len(batches) <= 100) or not (1 <= len(entries) <= MAX_ENTRIES):
        raise CommandError("Tamanho do catalogo fora dos limites.")
    batch_fields = {
        "id",
        "state",
        "fingerprint",
        "rules_version",
        "boundary_hash",
        "snapshot_at",
        "complete",
        "created_at",
        "finished_at",
        "source",
    }

    ids = set()
    for b in batches:
        if not isinstance(b, dict) or set(b) != batch_fields:
            raise CommandError("Lote invalido.")
        if type(b["complete"]) is not bool:
            raise CommandError("Flag complete invalida.")
        if not isinstance(b["boundary_hash"], str) or not re.fullmatch(r"[a-f0-9]{64}", b["boundary_hash"]):
            raise CommandError("Hash do limite municipal invalido.")
        pk = _valid_uuid(b.get("id"))
        if pk in ids:
            raise CommandError("Lote duplicado.")
        ids.add(pk)
        if b.get("state") not in ("partial", "published"):
            raise CommandError("Lote nao publicado no arquivo.")
        if b.get("rules_version") != RULES_VERSION:
            raise CommandError("Regras OSM diferentes. Exige revisao do catalogo.")
        if not isinstance(b.get("fingerprint"), str) or not re.fullmatch(r"[a-f0-9]{64}", b["fingerprint"]):
            raise CommandError("Fingerprint do lote invalido.")
        for key in ("snapshot_at", "created_at", "finished_at"):
            _valid_datetime(b.get(key))
        source = b.get("source", {})
        if not isinstance(source, dict) or set(source) - set(MANIFEST_FIELDS):
            raise CommandError("Metadados nao permitidos no arquivo.")
        url = source.get("url")
        if url and url != "operator local file" and (
            not isinstance(url, str)
            or urlsplit(url).scheme not in ("https", "http")
            or not urlsplit(url).hostname
            or urlsplit(url).username or urlsplit(url).password
            or urlsplit(url).query or urlsplit(url).fragment
        ):
            raise CommandError("URL de origem com formato inseguro.")
    active = _valid_uuid(payload.get("active_batch_id"))
    if active not in ids:
        raise CommandError("Lote ativo nao encontrado na lista.")
    unique = set()
    for row in entries:
        if not isinstance(row, dict) or set(row) != set(FIELDS) | {
            "osm_type", "osm_number", "external_id", "observed_in", "first_seen", "last_seen"
        }:
            raise CommandError("Campos inesperados em registro OSM.")
        if row["osm_type"] not in ("node", "way", "relation"):
            raise CommandError("Tipo OSM invalido.")
        n = row["osm_number"]
        if type(n) is not int or n <= 0:
            raise CommandError("Numero OSM invalido.")
        k = (row["osm_type"], n)
        if k in unique or row["external_id"] != f"osm:{k[0]}:{k[1]}":
            raise CommandError("Identidade OSM duplicada ou incoerente.")
        unique.add(k)
        if _valid_uuid(row["observed_in"]) not in ids:
            raise CommandError("Lote de observacao ausente.")
        for key in ("first_seen", "last_seen", "osm_timestamp"):
            _valid_datetime(row[key])
        lat, lon = row["latitude"], row["longitude"]
        if not all(type(v) in (int, float) and math.isfinite(v) for v in (lat, lon)):
            raise CommandError("Coordenadas nao numericas.")
        if not (-90 <= lat <= 90 and -180 <= lon <= 180):
            raise CommandError("Coordenadas fora dos limites.")
        if row["source_status"] not in ("available", "not_seen"):
            raise CommandError("Estado de catalogo invalido.")
        if not isinstance(row["tags"], dict) or set(row["tags"]) - set(ALLOWED_TAGS):
            raise CommandError("Tags OSM fora da allowlist.")
        if not isinstance(row["resource_states"], dict) or len(row["resource_states"]) > 100:
            raise CommandError("Recursos de acessibilidade invalidos.")
        for k, v in row["resource_states"].items():
            if not isinstance(k, str) or len(k) > 64 or not isinstance(v, str) or \
                    v not in ("presence_reported", "absence_reported", "unknown", "limited", "not_applicable"):
                raise CommandError("Estado de acessibilidade invalido.")
        if any(not isinstance(k, str) or not isinstance(v, str) or len(v) > 255
               for k, v in row["tags"].items()):
            raise CommandError("Valor de tag invalido.")
        if len(row["search_text"]) > 2048:
            raise CommandError("Campo de busca excessivamente longo.")
        for key in ("original_name", "display_name", "category", "address", "search_text", "content_hash"):
            if not isinstance(row[key], str):
                raise CommandError("Campo textual do catalogo invalido.")
        if any(len(row[k]) > 255 for k in ("original_name", "display_name", "category", "address")):
            raise CommandError("Texto do catalogo muito longo.")
    return payload


def read_seed(path):
    file = Path(path)
    if not file.is_file():
        raise CommandError(f"Arquivo nao encontrado: {file}. Exporte primeiro no PC 1.")
    if file.stat().st_size > MAX_FILE_BYTES:
        raise CommandError("Arquivo maior que o limite de 16 MiB.")
    try:
        data = json.loads(file.read_text(encoding="utf-8"))
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise CommandError("JSON do catalogo nao pode ser lido.") from exc
    return validate_public_catalog(data)


def save_seed(path):
    file = Path(path)
    if file.exists():
        raise CommandError("Destino existente; nenhuma exportacao sobrescrita.")
    content = export_public_catalog()
    encoded = json.dumps(content, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    if len(encoded.encode("utf-8")) > MAX_FILE_BYTES:
        raise CommandError("Exportacao excede 16 MiB.")
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text(encoded, encoding="utf-8")
    return len(content["payload"]["entries"]), content["sha256"]


@transaction.atomic
def import_public_catalog(payload):
    active_id = _valid_uuid(payload["active_batch_id"])
    scope, _ = CatalogScope.objects.get_or_create(pk=MUNICIPALITY)
    scope = CatalogScope.objects.select_for_update().get(pk=scope.pk)
    if scope.lease_owner is not None:
        raise CommandError("Importacao OSM em andamento; tente depois.")
    if scope.active_batch_id:
        if str(scope.active_batch_id) == active_id:
            actual = CatalogEntry.objects.filter(batch_id=active_id).count()
            batch = CatalogBatch.objects.get(pk=active_id)
            if batch.fingerprint == next(b["fingerprint"] for b in payload["batches"]
                                         if b["id"] == active_id) and actual == len(payload["entries"]):
                expected = {row["external_id"]: row["content_hash"] for row in payload["entries"]}
                existing = dict(CatalogEntry.objects.filter(batch_id=active_id).values_list(
                    "poi__external_id", "content_hash"
                ))
                if existing == expected:
                    return {"status": "already_installed", "count": actual}
        raise CommandError("Catalogo ativo ja existe. Nao sobrescrever dados publicos ou comunitarios.")
    if CatalogBatch.objects.filter(id__in=[_valid_uuid(b["id"]) for b in payload["batches"]]).exists():
        raise CommandError("Lote ja existente sem ativacao; verifique o banco antes de importar.")
    # Abort entirely on unexpected POIs instead of mutating an existing published catalog.
    identities = [row["external_id"] for row in payload["entries"]]
    if CatalogPOI.objects.filter(external_id__in=identities).exists():
        raise CommandError("Identidade OSM ja existente; nenhuma alteracao foi feita.")
    batches = {}
    for src in payload["batches"]:
        batch = CatalogBatch.objects.create(
            id=_valid_uuid(src["id"]), scope=scope, state=src["state"],
            fingerprint=src["fingerprint"], snapshot_at=_valid_datetime(src["snapshot_at"]),
            rules_version=src["rules_version"], boundary_hash=src["boundary_hash"],
            complete=bool(src["complete"]), manifest={**src["source"], "demo_seed": True},
            statistics={}, finished_at=_valid_datetime(src["finished_at"]),
        )
        # Reproduces source timestamps rather than claiming a new observation on import.
        if src["created_at"] is not None:
            CatalogBatch.objects.filter(pk=batch.pk).update(created_at=_valid_datetime(src["created_at"]))
        batches[str(batch.pk)] = batch
    for row in payload["entries"]:
        poi = CatalogPOI.objects.create(
            source="openstreetmap", osm_type=row["osm_type"], osm_number=row["osm_number"],
            external_id=row["external_id"], first_seen=_valid_datetime(row["first_seen"]),
            last_seen=_valid_datetime(row["last_seen"]),
        )
        values = {field: row[field] for field in FIELDS}
        values["osm_timestamp"] = _valid_datetime(values["osm_timestamp"])
        CatalogEntry.objects.create(
            batch=batches[active_id], observed_in=batches[row["observed_in"]], poi=poi, **values
        )
    scope.active_batch = batches[active_id]
    scope.revision += 1
    scope.save(update_fields=["active_batch", "revision"])
    return {"status": "installed", "count": len(payload["entries"])}
