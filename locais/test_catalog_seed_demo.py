"""End-to-end smoke and tamper tests for the committed OSM demo seed."""
import json
import uuid

import pytest
from django.core.management.base import CommandError

from locais.catalog_models import CatalogBatch, CatalogEntry, CatalogPOI, CatalogScope
from locais.services.catalog_rules import MUNICIPALITY, RULES_VERSION
from locais.services.catalog_seed_demo import (
    export_public_catalog,
    import_public_catalog,
    validate_public_catalog,
)


@pytest.mark.django_db(transaction=True)
def test_export_public_catalog_only_source_data_and_idempotent_restore():
    scope, _ = CatalogScope.objects.get_or_create(pk=MUNICIPALITY)
    batch = CatalogBatch.objects.create(
        scope=scope, state="partial", fingerprint="a" * 64,
        rules_version=RULES_VERSION, boundary_hash="b" * 64,
        manifest={"provider": "Geofabrik", "attribution": "© OpenStreetMap contributors",
                  "license": "ODbL-1.0", "email_operador_privado": "nao-exportar"},
    )
    poi = CatalogPOI.objects.create(
        external_id="osm:node:123456789", osm_type="node", osm_number=123456789
    )
    CatalogEntry.objects.create(
        batch=batch, observed_in=batch, poi=poi,
        original_name="Local publico", display_name="Local publico",
        category="loja", address="Rua A", latitude=-16.32, longitude=-48.95,
        geometry_type="Point", point_method="node", tags={"name": "Local publico"},
        resource_states={"rampa_acesso": "unknown"}, search_text="local publico rua a",
        content_hash="c" * 64,
    )
    scope.active_batch = batch
    scope.save(update_fields=["active_batch"])

    document = export_public_catalog()
    encoded = json.dumps(document, ensure_ascii=False)
    assert "email_operador_privado" not in encoded
    assert "local_id" not in encoded
    assert "password" not in encoded
    assert len(document["payload"]["entries"]) == 1
    assert document["payload"]["license"] == "ODbL-1.0"
    payload = validate_public_catalog(document)
    CatalogScope.objects.filter(pk=MUNICIPALITY).update(active_batch=None)
    CatalogEntry.objects.all().delete()
    CatalogPOI.objects.all().delete()
    CatalogBatch.objects.all().delete()
    assert import_public_catalog(payload) == {"status": "installed", "count": 1}
    assert import_public_catalog(payload) == {"status": "already_installed", "count": 1}
    assert CatalogEntry.objects.count() == 1
    assert CatalogPOI.objects.filter(local__isnull=True).count() == 1


@pytest.mark.django_db(transaction=True)
def test_catalog_seed_rejects_existing_active_batch():
    scope, _ = CatalogScope.objects.get_or_create(pk=MUNICIPALITY)
    scope.active_batch = CatalogBatch.objects.create(
        scope=scope, state="partial", fingerprint="b" * 64,
        rules_version=RULES_VERSION, boundary_hash="c" * 64,
    )
    scope.save(update_fields=["active_batch"])
    with pytest.raises(CommandError):
        import_public_catalog({"active_batch_id": str(uuid.uuid4()), "entries": [], "batches": []})


def test_catalog_seed_rejects_modified_document():
    document = {"sha256": "0" * 64, "payload": {"format": "wrong"}}
    with pytest.raises(CommandError):
        validate_public_catalog(document)
