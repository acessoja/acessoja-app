"""Administrative, file-only import. Source editions are staged before atomic activation."""

import hashlib
import json
import math
import tempfile
import time
from datetime import datetime, timezone as dt_timezone
from pathlib import Path
from urllib.parse import urlsplit

from django.db import transaction
from django.utils import timezone

from locais.catalog_models import CatalogBatch, CatalogEntry, CatalogPOI, CatalogScope
from locais.models import Local
from .catalog_geometry import CatalogInputError, MunicipalityBoundary, file_hash, write_json
from .catalog_publication import CatalogLease
from .catalog_reader import PBFStage
from .catalog_rules import MUNICIPALITY, RULES_VERSION
from .matching import strong_match


def snapshot_date(path, supplied=None):
    import osmium

    with osmium.io.Reader(str(path)) as reader:
        stamp = reader.header().get("osmosis_replication_timestamp")
    header = datetime.fromisoformat(stamp.replace("Z", "+00:00")) if stamp else None
    given = datetime.fromisoformat(supplied.replace("Z", "+00:00")) if supplied else None
    if (header and header.utcoffset() is None) or (
        given and (given.utcoffset() is None or (header and given != header))
    ):
        raise CatalogInputError("snapshot_date_conflicts_with_header_or_timezone_missing")
    result = header or given
    if result and result > timezone.now():
        raise CatalogInputError("snapshot_date_in_future")
    return result


def source_reference(url):
    if not url:
        return "operator local file"
    parsed = urlsplit(url)
    if (
        parsed.scheme not in ("http", "https")
        or not parsed.hostname
        or parsed.username
        or parsed.password
        or parsed.query
        or parsed.fragment
    ):
        raise CatalogInputError("public_source_url_required_without_credentials_or_query")
    return url


def canonical_match(identity, values):
    explicit = Local.objects.filter(osm_id=identity).first()
    if explicit:
        return explicit, "explicit_osm_id", False
    if not values["original_name"] or not values["address"]:
        return None, "", False
    lat, lon = values["latitude"], values["longitude"]
    delta_lon = min(180, 0.0003 / max(0.00001, math.cos(math.radians(lat))))
    candidates = list(
        Local.objects.filter(
            latitude__range=(lat - 0.0003, lat + 0.0003), longitude__range=(lon - delta_lon, lon + delta_lon)
        ).order_by("pk")[:101]
    )
    place = {
        "external_id": identity,
        "nome": values["original_name"],
        "endereco": values["address"],
        "categoria": values["category"],
        "latitude": lat,
        "longitude": lon,
    }
    claimed = set(
        CatalogPOI.objects.filter(local_id__in=[c.pk for c in candidates])
        .exclude(external_id=identity)
        .values_list("local_id", flat=True)
    )
    matches = [local for local in candidates if local.pk not in claimed and strong_match(place, local)]
    if len(candidates) > 100 or len(matches) > 1:
        return None, "", True
    return (matches[0], "conservative_attributes", False) if matches else (None, "", False)


def _store_chunk(rows, batch, active, dry_run, stats, stage):
    identities = [identity for identity, _ in rows]
    pois = CatalogPOI.objects.in_bulk(identities, field_name="external_id")
    old = (
        {
            e.poi.external_id: e
            for e in CatalogEntry.objects.filter(batch=active, poi__external_id__in=identities).select_related("poi")
        }
        if active
        else {}
    )
    entries, new_pois = [], []
    explicit = Local.objects.in_bulk(identities, field_name="osm_id")
    for identity, values in rows:
        poi, previous = pois.get(identity), old.get(identity)
        if not poi:
            _, kind, number = identity.split(":")
            poi = CatalogPOI(external_id=identity, osm_type=kind, osm_number=int(number))
            new_pois.append(poi)
        stats[
            (
                "created"
                if previous is None
                else "unchanged" if previous.content_hash == values["content_hash"] else "updated"
            )
        ] += 1
        if previous and previous.source_status == "not_seen":
            stats["reactivated"] += 1
        if not poi.local_id:
            local, method, ambiguous = explicit.get(identity), "explicit_osm_id", False
            if not local:
                if stage.db.execute("SELECT 1 FROM ambiguous_source WHERE identity=?", (identity,)).fetchone():
                    local, method, ambiguous = None, "", True
                else:
                    local, method, ambiguous = canonical_match(identity, values)
            stats["pending_review"] += ambiguous
            if ambiguous and len(stats["review_identity_sample"]) < 20:
                stats["review_identity_sample"].append(identity)
            if local:
                stage.db.execute("INSERT OR REPLACE INTO proposed_links VALUES (?,?,?)", (identity, local.pk, method))
        else:
            local = poi.local
        stats["linked"] += bool(local)
        if not dry_run:
            entries.append((poi, values))
    if dry_run:
        return
    CatalogPOI.objects.bulk_create(new_pois, batch_size=250)
    CatalogEntry.objects.bulk_create(
        [CatalogEntry(batch=batch, observed_in=batch, poi=poi, **values) for poi, values in entries], batch_size=250
    )


def _carry(active, batch, stage, comparable, dry_run, stats):
    if not active:
        return
    fields = [f.attname for f in CatalogEntry._meta.concrete_fields if f.name not in ("id", "batch")]
    buffer = []
    # Iterate only the previous edition; writes target a different batch.
    for entry in CatalogEntry.objects.filter(batch=active).select_related("poi").iterator(chunk_size=250):
        identity = entry.poi.external_id
        if stage.db.execute("SELECT 1 FROM accepted WHERE identity=?", (identity,)).fetchone():
            continue
        known_rejected = bool(stage.db.execute("SELECT 1 FROM rejected_known WHERE identity=?", (identity,)).fetchone())
        missing = comparable or known_rejected
        stats["not_seen" if missing else "carried_without_absence_inference"] += 1
        if dry_run:
            continue
        values = {key: getattr(entry, key) for key in fields}
        if missing:
            values["source_status"] = "not_seen"
        buffer.append(CatalogEntry(batch=batch, **values))
        if len(buffer) == 250:
            CatalogEntry.objects.bulk_create(buffer, batch_size=250)
            buffer.clear()
    if buffer:
        CatalogEntry.objects.bulk_create(buffer, batch_size=250)


def import_catalog(
    *,
    path,
    boundary_path,
    municipality=MUNICIPALITY,
    dry_run=False,
    report_path=None,
    coverage_path=None,
    full_snapshot=False,
    supplied_date=None,
    date_decision="",
    source_url="",
    provider="operator",
    work_directory=None,
    obtained_at=None
):
    start = time.monotonic()
    lease, batch, stage = None, None, None
    report = {"municipality": municipality, "dry_run": dry_run, "result": "failed", "rules_version": RULES_VERSION}
    try:
        if municipality != MUNICIPALITY or Path(path).suffix.lower() != ".pbf":
            raise CatalogInputError("supported_input_is_anapolis_pbf")
        boundary = MunicipalityBoundary(boundary_path, municipality)
        source_sha = file_hash(path)
        stamp = snapshot_date(path, supplied_date)
        scope = CatalogScope.objects.select_related("active_batch").get(pk=municipality)
        active = scope.active_batch
        if (stamp is None or (active and (active.snapshot_at is None or stamp < active.snapshot_at))) and len(
            date_decision.strip()
        ) < 10:
            raise CatalogInputError("explicit_date_decision_required_for_unknown_or_older_snapshot")
        coverage = boundary.coverage(coverage_path) if coverage_path else {"covers_municipality": False}
        fingerprint = hashlib.sha256(
            json.dumps(
                [
                    source_sha,
                    boundary.hash,
                    RULES_VERSION,
                    stamp.isoformat() if stamp else None,
                    bool(full_snapshot),
                    coverage,
                ],
                sort_keys=True,
            ).encode()
        ).hexdigest()
        manifest = {
            "provider": provider[:100],
            "url": source_reference(source_url),
            "sha256": source_sha,
            "bytes": Path(path).stat().st_size,
            "obtained_at": obtained_at,
            "processed_at": timezone.now().isoformat(),
            "snapshot_at": stamp.isoformat() if stamp else None,
            "date_decision": date_decision[:500],
            "boundary": boundary.manifest,
            "coverage": coverage,
            "full_snapshot_attested": full_snapshot,
            "attribution": "© OpenStreetMap contributors",
            "license": "ODbL-1.0",
            "license_url": "https://www.openstreetmap.org/copyright",
        }
        report["source"] = manifest
        reused = active and active.fingerprint == fingerprint
        if not dry_run:
            lease = CatalogLease(municipality)
            lease.acquire()
            # Re-read after acquiring the publisher gate, avoiding a stale comparison.
            scope.refresh_from_db()
            if scope.active_batch_id != (active.pk if active else None):
                raise CatalogInputError("active_catalog_changed_retry_import")
            if not reused:
                batch = CatalogBatch.objects.create(
                    scope=scope,
                    fingerprint=fingerprint,
                    snapshot_at=stamp,
                    rules_version=RULES_VERSION,
                    boundary_hash=boundary.hash,
                    manifest=manifest,
                )
        with tempfile.TemporaryDirectory(prefix="acessoja-catalog-", dir=work_directory) as directory:
            stage = PBFStage(directory, boundary, lease.heartbeat if lease else None)
            try:
                report["selection"] = stage.read(path)
                if source_sha != file_hash(path):
                    raise CatalogInputError("source_changed_while_reading")
                complete = bool(
                    full_snapshot
                    and coverage["covers_municipality"]
                    and report["selection"]["complete_geometry"]
                    and stamp
                )
                comparable = bool(
                    complete
                    and active
                    and active.complete
                    and active.rules_version == RULES_VERSION
                    and active.boundary_hash == boundary.hash
                    and active.snapshot_at <= stamp
                )
                changes = dict.fromkeys(
                    (
                        "created",
                        "updated",
                        "unchanged",
                        "linked",
                        "pending_review",
                        "not_seen",
                        "reactivated",
                        "carried_without_absence_inference",
                    ),
                    0,
                )
                changes["review_identity_sample"] = []
                report.update(complete=complete, absence_reconciliation=comparable, changes=changes)
                for rows in stage.chunks(250):
                    _store_chunk(rows, batch, active, dry_run or bool(reused), changes, stage)
                    if lease:
                        lease.heartbeat()
                _carry(active, batch, stage, comparable, dry_run or bool(reused), changes)
                if lease and not reused:
                    with transaction.atomic():
                        report["validation"] = "passed_before_publication"
                        batch.state, batch.complete = ("published" if complete else "partial"), complete
                        batch.statistics = {
                            "selection": report["selection"],
                            "changes": changes,
                            "validation": "passed",
                            "complete": complete,
                        }
                        batch.finished_at = timezone.now()
                        batch.save(update_fields=["state", "complete", "statistics", "finished_at"])
                        from evidencias.capture import sync_catalog_batch
                        sync_catalog_batch(batch)
                        lease.activate(batch)
                        for identity, local_id, method in stage.db.execute("SELECT * FROM proposed_links"):
                            CatalogPOI.objects.filter(external_id=identity, local__isnull=True).update(
                                local_id=local_id, link_method=method
                            )
                        observed = CatalogPOI.objects.filter(editions__batch=batch, editions__observed_in=batch)
                        observed.filter(first_seen__isnull=True).update(first_seen=stamp or batch.created_at)
                        observed.update(last_seen=stamp or batch.created_at)
                report.update(
                    result="dry_run" if dry_run else "reused" if reused else "published",
                    batch_id=str(active.pk if reused else batch.pk) if (reused or batch) else None,
                )
            finally:
                stage.close()
                stage = None
        return report
    except Exception as exc:
        code = getattr(exc, "code", None) or "catalog_import_failed"
        report["error_code"] = code[:64]
        if batch:
            CatalogBatch.objects.filter(pk=batch.pk, state="building").update(
                state="failed", error_code=code[:64], finished_at=timezone.now()
            )
        raise
    finally:
        if lease:
            lease.release()
        report["duration_seconds"] = round(time.monotonic() - start, 3)
        report["finished_at"] = datetime.now(dt_timezone.utc).isoformat()
        if report_path:
            write_json(report_path, report)
