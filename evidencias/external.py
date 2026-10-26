"""Apply current local moderation after raw provider cache reads, in batches."""

from collections import defaultdict

from .capture import sync_catalog_entries, sync_remote_places
from .models import ResourceEvidence
from .projection import confirmation_stats, public_evidence, resource_summary


def external_summaries(identities):
    rows = list(public_evidence(external_ids=identities))
    stats = confirmation_stats(rows) if rows else {}
    grouped = defaultdict(list)
    for row in rows:
        grouped[row.external_id].append(row)
    blocked = set(
        ResourceEvidence.objects.filter(
            external_id__in=identities, withdrawn=False, current_revision__is_valid=False
        ).values_list("external_id", flat=True)
    )
    return {
        identity: resource_summary(grouped[identity], statistics=stats) for identity in identities
    }, blocked


def project_remote_places(places):
    sync_remote_places(places)
    identities = [place["external_id"] for place in places if place.get("external_id")]
    summaries, blocked = external_summaries(identities)
    for place in places:
        identity = place.get("external_id")
        if identity in summaries:
            place["accessibility"] = summaries[identity]
        if identity in blocked:
            place["accessibility_data"] = {
                key: value
                for key, value in place.get("accessibility_data", {}).items()
                if key != "toilets:wheelchair"
            }


def project_catalog_places(entries, documents):
    from .query_projection import unpack_quality
    from locais.accessibility import osm_information, resolve_information

    embedded = all(hasattr(entry, "_quality_rows") for entry in entries)
    if embedded:
        for entry, document in zip(entries, documents):
            records, statistics = unpack_quality(entry._quality_rows)
            valid = [row for row in records if row.current_revision.is_valid]
            document["accessibility"] = (
                resource_summary(valid, statistics=statistics)
                if records
                else resolve_information(external=osm_information(entry.tags))
            )
            if any(not row.current_revision.is_valid for row in records):
                document["accessibility_data"] = {
                    key: value for key, value in entry.tags.items() if key != "toilets:wheelchair"
                }
        return
    # Detail endpoints can repair a trusted catalog assertion created outside the importer.
    sync_catalog_entries(entries)
    identities = [entry.poi.external_id for entry in entries]
    summaries, blocked = external_summaries(identities)
    for entry, document in zip(entries, documents):
        document["accessibility"] = summaries[entry.poi.external_id]
        if entry.poi.external_id in blocked:
            document["accessibility_data"] = {
                key: value
                for key, value in document["accessibility_data"].items()
                if key != "toilets:wheelchair"
            }
