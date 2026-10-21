"""Synthetic PBF topology, SQL queries and community journeys. No public network."""

from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from threading import Barrier
from unittest.mock import patch

import osmium
import pytest
from django.contrib.auth import get_user_model
from django.db import close_old_connections, connection
from django.utils import timezone
from rest_framework.test import APIClient
from shapely.geometry import Point, Polygon, MultiPolygon, mapping

from favoritos.models import Favorito
from locais.catalog_models import CatalogBatch, CatalogEntry, CatalogPOI, CatalogScope
from locais.models import Local, VisitaRecente, ManualRegistrationGuard
from locais.services.catalog_geometry import CatalogInputError, MunicipalityBoundary, prepare_ibge, write_json
from locais.services.catalog_import import canonical_match, import_catalog, snapshot_date, source_reference
from locais.services.catalog_metrics import measure_catalog
from locais.services.catalog_publication import CatalogBusy, CatalogLease, reactivate_batch
from locais.services.catalog_reader import PBFStage, location_index
from locais.services.catalog_rules import MUNICIPALITY, eligibility, source_values
from modal_avaliacao.models import ModalAvaliacao

pytestmark = pytest.mark.django_db
BASE = "/api/locais/catalogo/"


def api(user=None):
    client = APIClient()
    if user:
        client.force_authenticate(user)
    return client


def user(name="catalog_owner"):
    return get_user_model().objects.create_user(nome=name, email=f"{name}@test.invalid", password="test-password")


def boundary_file(path):
    geometry = MultiPolygon(
        [
            Polygon([(0, 0), (4, 0), (4, 4), (0, 4)], holes=[[(2, 2), (3, 2), (3, 3), (2, 3)]]),
            Polygon([(5, 0), (6, 0), (6, 1), (5, 1)]),
        ]
    )
    write_json(
        path,
        {
            "type": "Feature",
            "geometry": mapping(geometry),
            "properties": {"municipality": MUNICIPALITY, "output_crs": "EPSG:4326", "edition": "SYNTHETIC"},
        },
    )
    return path


def pbf(path, *, stamp="2026-01-01T00:00:00Z", names=None, incomplete=False):
    header = osmium.io.Header()
    if stamp:
        header.set("osmosis_replication_timestamp", stamp)
    names = names if names is not None else {1: "Café", 2: "Farmácia"}
    with osmium.SimpleWriter(str(path), header=header) as writer:
        for i, name in names.items():
            writer.add_node(
                osmium.osm.mutable.Node(
                    id=i,
                    location=(1 + i / 1000, 1),
                    version=1,
                    timestamp="2026-01-01T00:00:00Z",
                    tags={
                        "name": name,
                        "amenity": "pharmacy" if i == 2 else "cafe",
                        "addr:full": f"Rua {i}",
                        "toilets:wheelchair": "yes",
                    },
                )
            )
        for i, point in enumerate([(0.1, 0.1), (1.9, 0.1), (1.9, 0.3), (0.3, 0.3), (0.3, 1.9), (0.1, 1.9)], 100):
            writer.add_node(osmium.osm.mutable.Node(id=i, location=point))
        for i, point in enumerate(
            [(0.5, 0.5), (1.5, 0.5), (1.5, 1.5), (0.5, 1.5), (0.7, 0.7), (0.7, 0.9), (0.9, 0.9), (0.9, 0.7)], 200
        ):
            writer.add_node(osmium.osm.mutable.Node(id=i, location=point))
        writer.add_way(
            osmium.osm.mutable.Way(id=10, nodes=[100, 101, 102, 103, 104, 105, 100], tags={"amenity": "school"})
        )
        writer.add_way(osmium.osm.mutable.Way(id=20, nodes=[200, 201, 202, 203, 200]))
        writer.add_way(osmium.osm.mutable.Way(id=21, nodes=[204, 205, 206, 207, 204]))
        writer.add_relation(
            osmium.osm.mutable.Relation(
                id=30,
                members=[("w", 20, "outer"), ("w", 21, "inner")],
                tags={"type": "multipolygon", "shop": "supermarket", "name": "Mercado da relação"},
            )
        )
        if incomplete:
            writer.add_relation(
                osmium.osm.mutable.Relation(
                    id=31, members=[("w", 99999, "outer")], tags={"type": "multipolygon", "amenity": "pharmacy"}
                )
            )
    return path


@pytest.fixture
def source(tmp_path):
    CatalogScope.objects.get_or_create(pk=MUNICIPALITY)
    ManualRegistrationGuard.objects.get_or_create(pk=1)
    return {"path": pbf(tmp_path / "source.osm.pbf"), "boundary_path": boundary_file(tmp_path / "boundary.json")}


def imported(source, **kwargs):
    return import_catalog(**source, coverage_path=source["boundary_path"], full_snapshot=True, **kwargs)


def test_real_pbf_areas_original_ids_and_dry_run(source):
    before = list(CatalogScope.objects.values())
    report = imported(source, dry_run=True)
    assert report["selection"]["accepted"] == 4
    assert report["selection"]["accepted_types"] == {"node": 2, "way": 1, "relation": 1}
    assert CatalogBatch.objects.count() == CatalogPOI.objects.count() == CatalogEntry.objects.count() == 0
    assert list(CatalogScope.objects.values()) == before
    first = imported(source)
    assert first["complete"] and first["changes"]["created"] == 4
    ids = dict(CatalogPOI.objects.values_list("external_id", "pk"))
    assert set(ids) == {"osm:node:1", "osm:node:2", "osm:way:10", "osm:relation:30"}
    second = imported(source)
    assert second["result"] == "reused" and second["changes"]["unchanged"] == 4
    assert dict(CatalogPOI.objects.values_list("external_id", "pk")) == ids
    assert CatalogBatch.objects.count() == 1 and CatalogEntry.objects.count() == 4
    assert Local.objects.count() == VisitaRecente.objects.count() == 0


def test_geometry_holes_islands_border_and_concave(source):
    boundary = MunicipalityBoundary(source["boundary_path"], MUNICIPALITY)
    assert boundary.point(Point(0, 0))[:2] == (0, 0)
    assert boundary.point(Point(5.5, 0.5))[:2] == (0.5, 5.5)
    with pytest.raises(CatalogInputError, match="outside_municipality"):
        boundary.point(Point(2.5, 2.5))
    concave = Polygon([(0.1, 0.1), (1.9, 0.1), (1.9, 0.3), (0.3, 0.3), (0.3, 1.9), (0.1, 1.9)])
    lat, lon, method, _, _ = boundary.point(concave)
    assert concave.covers(Point(lon, lat)) and method == "point_on_surface"
    assert not concave.covers(concave.centroid)
    crossing = Polygon([(3.5, 3.5), (4.1, 3.5), (4.1, 3.9), (3.5, 3.9)])
    assert boundary.point(crossing)[3]
    with pytest.raises(CatalogInputError):
        boundary.point(Polygon([(0, 0), (1, 1), (0, 1), (1, 0)]))


@pytest.mark.parametrize(
    "tags,reason",
    [
        ({"building": "yes"}, "not_a_supported_poi"),
        ({"shop": "vacant"}, "inactive"),
        ({"amenity": "cafe", "access": "private"}, "restricted_access"),
        ({"disused:amenity": "cafe"}, "inactive"),
        ({"amenity": "pharmacy"}, None),
    ],
)
def test_eligibility(tags, reason):
    assert eligibility(tags) == reason


def test_source_data_unknown_and_allowlist():
    values = source_values(
        {"amenity": "pharmacy", "wheelchair": "yes", "phone": "secret", "contact:email": "private"},
        latitude=0,
        longitude=0,
        geometry_type="Point",
        point_method="original_node",
    )
    assert "sem nome" in values["display_name"] and values["address"] == ""
    assert set(values["resource_states"].values()) == {"unknown"}
    assert "phone" not in values["tags"] and "contact:email" not in values["tags"]
    assert values["osm_version"] is None and values["osm_timestamp"] is None


def test_partial_failure_absence_reappearance_and_rollback(source, tmp_path):
    first = imported(source)
    item = CatalogPOI.objects.get(external_id="osm:node:1")
    owner = user()
    confirmed = api(owner).post(
        f"{BASE}{item.pk}/confirmar/", {"confirmed": True, "nome": "Corrigido", "endereco": "Rua corrigida"}
    )
    assert confirmed.status_code == 201
    local = Local.objects.get(pk=confirmed.data["id_local"])
    saved = Favorito.objects.create(user=owner, local=local)
    review = ModalAvaliacao.objects.create(user=owner, local=local, estrelas=4)
    newer = {**source, "path": pbf(tmp_path / "new.pbf", stamp="2026-01-02T00:00:00Z", names={2: "Farmácia nova"})}
    partial = import_catalog(**newer)
    assert not partial["complete"] and partial["changes"]["carried_without_absence_inference"] == 1
    third = {**source, "path": pbf(tmp_path / "third.pbf", stamp="2026-01-03T00:00:00Z", names={2: "Farmácia nova"})}
    imported(third)
    fourth = {**source, "path": pbf(tmp_path / "fourth.pbf", stamp="2026-01-04T00:00:00Z", names={2: "Farmácia nova"})}
    complete = imported(fourth)
    assert complete["absence_reconciliation"] and complete["changes"]["not_seen"] == 1
    assert api().get(f"{BASE}{item.pk}/").data["source_status"] == "not_seen"
    local.refresh_from_db()
    assert local.nome == "Corrigido" and Favorito.objects.filter(pk=saved.pk).exists()
    assert ModalAvaliacao.objects.get(pk=review.pk).estrelas == 4
    reactivate_batch(first["batch_id"], "Return to the first validated snapshot")
    assert CatalogScope.objects.get(pk=MUNICIPALITY).active_batch_id.hex == first["batch_id"].replace("-", "")
    assert Local.objects.get(pk=local.pk).nome == "Corrigido"
    fifth = {
        **source,
        "path": pbf(tmp_path / "fifth.pbf", stamp="2026-01-05T00:00:00Z", names={1: "Atualizado", 2: "Farmácia"}),
    }
    with patch("locais.services.catalog_import._carry", side_effect=RuntimeError("controlled")):
        with pytest.raises(RuntimeError):
            imported(fifth)
    assert CatalogScope.objects.get(pk=MUNICIPALITY).active_batch_id.hex == first["batch_id"].replace("-", "")
    assert CatalogBatch.objects.filter(state="failed").count() == 1


def test_incomplete_relation_prohibits_complete_publication(source, tmp_path):
    source["path"] = pbf(tmp_path / "incomplete.pbf", incomplete=True)
    report = imported(source)
    assert not report["complete"]
    assert report["selection"]["rejected"]["incomplete_geometry"] == 1
    assert report["selection"]["rejection_samples"]["incomplete_geometry"] == ["osm:relation:31"]


def test_lease_owner_and_old_snapshot_decisions(source, tmp_path):
    imported(source)
    lease = CatalogLease(MUNICIPALITY)
    lease.acquire()
    with pytest.raises(CatalogBusy):
        CatalogLease(MUNICIPALITY).acquire()
    CatalogScope.objects.filter(pk=MUNICIPALITY).update(lease_until=timezone.now() - timedelta(seconds=1))
    newer_owner = CatalogLease(MUNICIPALITY)
    newer_owner.acquire()
    with pytest.raises(CatalogBusy):
        lease.heartbeat()
    lease.release()
    assert CatalogScope.objects.get(pk=MUNICIPALITY).lease_owner == newer_owner.owner
    newer_owner.release()
    source["path"] = pbf(tmp_path / "old.pbf", stamp="2025-01-01T00:00:00Z")
    with pytest.raises(CatalogInputError, match="explicit_date_decision"):
        imported(source)
    assert not imported(source, date_decision="Operator explicitly accepts older data")["absence_reconciliation"]
    with pytest.raises(CatalogInputError):
        snapshot_date(source["path"], "2025-01-01T00:00:00")
    with pytest.raises(CatalogInputError):
        source_reference("https://secret@example.test/data?token=private")


def test_api_sql_filters_and_snapshot_version(source, django_assert_num_queries):
    imported(source)
    with django_assert_num_queries(4):
        response = api().get(BASE, {"page_size": "1", "ordering": "name"})
    assert response.status_code == 200 and response.data["count"] == 4
    assert response.data["coverage_complete"]
    assert "catalog_version=" in response.data["next"]
    assert api().get(BASE, {"categorias": "farmacia"}).data["count"] == 1
    assert api().get(BASE, {"search": "farmacia rua"}).data["count"] == 1
    assert api().get(BASE, {"bbox": "0,0,2,0.4"}).data["count"] == 1
    assert api().get(BASE, {"recursos": "rampa_acesso"}).data["count"] == 0
    assert api().get(BASE, {"recursos": "rampa_acesso", "incluir_desconhecidos": "true"}).data["count"] == 4
    assert api().get(BASE, {"ordering": "proximity", "origin_lat": "1", "origin_lon": "1"}).status_code == 200
    assert api().get(BASE, {"ordering": "rating"}).data["ordering"] == "name_unreviewed"
    CatalogScope.objects.filter(pk=MUNICIPALITY).update(revision=100)
    assert api().get(response.data["next"]).status_code == 409


@pytest.mark.parametrize(
    "params",
    [
        {"bbox": "nan,0,2,2"},
        {"ordering": "proximity"},
        {"page_size": "51"},
        {"recursos": "invented"},
        {"unknown": "x"},
        {"origin_lat": "0"},
        {"page": "0"},
    ],
)
def test_invalid_queries(params):
    assert api().get(BASE, params).status_code == 400


def test_materialize_once_trusted_identity_and_provenance(source):
    imported(source)
    item = CatalogPOI.objects.get(external_id="osm:node:1")
    endpoint = f"{BASE}{item.pk}/confirmar/"
    body = {"confirmed": True, "nome": "Nome comunitário", "endereco": "Endereço revisado"}
    assert api().get(f"{BASE}{item.pk}/").status_code == 200 and Local.objects.count() == 0
    assert api().post(endpoint, body).status_code == 401
    owner = user()
    client = api(owner)
    assert client.post(endpoint, {**body, "latitude": 80}).status_code == 400
    first = client.post(endpoint, body)
    assert first.status_code == 201
    second = client.post(endpoint, body)
    assert second.status_code == 200 and second.data["id_local"] == first.data["id_local"]
    local = Local.objects.get()
    assert local.latitude == 1 and local.osm_id == "osm:node:1"
    assert first.data["accessibility"]["banheiro_acessivel"]["state"] == "presence_reported"
    assert first.data["catalog_provenance"]["catalog_id"] == item.pk
    assert api().get(BASE).data["count"] == 3
    assert api().get(f"{BASE}{item.pk}/").data["linked_local"]["nome"] == "Nome comunitário"
    assert Favorito.objects.count() == VisitaRecente.objects.count() == 0
    assert first["Cache-Control"] == "private, no-store"


def test_confirm_catalog_without_postal_address_keeps_osm_identity(source):
    imported(source)
    item = CatalogPOI.objects.get(external_id="osm:node:1")
    client = api(user("catalog_without_address"))
    response = client.post(
        f"{BASE}{item.pk}/confirmar/", {"confirmed": True, "nome": "Nome confirmado", "endereco": ""}
    )
    assert response.status_code == 201
    local = Local.objects.get(pk=response.data["id_local"])
    assert local.osm_id == item.external_id and local.endereco == ""
    assert local.latitude == pytest.approx(1.0) and local.longitude == pytest.approx(1.001)
    assert client.post(
        f"{BASE}{item.pk}/confirmar/", {"confirmed": True, "nome": "Nome confirmado", "endereco": ""}
    ).status_code == 200


def test_publication_during_response_invalidates_count_and_page(source):
    imported(source)
    from locais.services.catalog_query import catalog_place

    def changed(*args, **kwargs):
        CatalogScope.objects.filter(pk=MUNICIPALITY).update(revision=999)
        return catalog_place(*args, **kwargs)

    with patch("locais.catalog_views.catalog_place", side_effect=changed):
        response = api().get(BASE)
    assert response.status_code == 409 and "results" not in response.data


def test_conservative_ambiguity_and_already_claimed_local(source):
    imported(source)
    values = {"original_name": "Mesmo", "address": "Rua A", "category": "cafeteria", "latitude": 1, "longitude": 1}
    local = Local.objects.create(
        nome="Mesmo", endereco="Rua A", categoria="cafeteria", latitude=1, longitude=1, distancia=0
    )
    assert canonical_match("osm:node:90", values)[0] == local
    duplicate = Local.objects.create(
        nome="Mesmo", endereco="Rua A", categoria="cafeteria", latitude=1, longitude=1, distancia=0
    )
    assert canonical_match("osm:node:90", values)[2]
    duplicate.delete()
    CatalogPOI.objects.filter(external_id="osm:node:1").update(local=local)
    assert canonical_match("osm:node:90", values)[0] is None
    response = api().get("/api/locais/", {"origens": "openstreetmap"})
    assert response.status_code == 200 and [r["id_local"] for r in response.data] == [local.pk]
    version = CatalogScope.objects.get(pk=MUNICIPALITY).revision
    local.delete()
    assert CatalogScope.objects.get(pk=MUNICIPALITY).revision > version


def test_duplicate_candidates_keep_identities_and_block_automatic_link(source, tmp_path):
    stage = PBFStage(tmp_path, MunicipalityBoundary(source["boundary_path"], MUNICIPALITY))
    tags = {"name": "Mesmo", "amenity": "cafe", "addr:full": "Rua A"}
    try:
        stage.accept("osm:node:90", tags, Point(1, 1), {})
        stage.accept("osm:way:90", tags, Point(1.00001, 1), {})
        stage.duplicates()
        assert stage.stats["candidate_duplicate_pairs"] == 1
        assert stage.db.execute("SELECT COUNT(*) FROM ambiguous_source").fetchone()[0] == 2
        assert stage.db.execute("SELECT COUNT(*) FROM accepted").fetchone()[0] == 2
    finally:
        stage.close()


def test_rule_change_and_explicit_closure_do_not_delete_community(source, tmp_path):
    imported(source)
    local = Local.objects.create(osm_id="osm:node:1", nome="Preservado", endereco="Rua real", distancia=0)
    newer = {
        **source,
        "path": pbf(tmp_path / "different-rules.pbf", stamp="2026-01-02T00:00:00Z", names={2: "Farmácia"}),
    }
    with patch("locais.services.catalog_import.RULES_VERSION", "synthetic-rules-v2"):
        report = imported(newer)
    assert not report["absence_reconciliation"] and report["changes"]["carried_without_absence_inference"] == 1
    from locais.services.catalog_import import _carry

    stage = PBFStage(tmp_path, MunicipalityBoundary(source["boundary_path"], MUNICIPALITY))
    try:
        stage.reject("restricted_access", "osm:node:1")
        counters = {"not_seen": 0, "carried_without_absence_inference": 0}
        _carry(CatalogScope.objects.get(pk=MUNICIPALITY).active_batch, None, stage, False, True, counters)
        assert counters["not_seen"] == 1
        assert Local.objects.get(pk=local.pk).nome == "Preservado"
    finally:
        stage.close()


def test_failed_publication_does_not_expose_proposed_conservative_links(source):
    local = Local.objects.create(
        nome="Café", endereco="Rua 1", categoria="cafeteria", latitude=1, longitude=1.001, distancia=0
    )
    with patch("locais.services.catalog_import._carry", side_effect=RuntimeError("controlled")):
        with pytest.raises(RuntimeError):
            imported(source)
    assert CatalogPOI.objects.filter(local=local).count() == 0
    assert CatalogScope.objects.get(pk=MUNICIPALITY).active_batch is None


def test_ibge_conversion_reads_crs_and_encoding(tmp_path):
    import zipfile
    import shapefile
    from pyproj import CRS, Transformer

    stem = tmp_path / "municipios"
    convert = Transformer.from_crs(4326, 3857, always_xy=True)
    with shapefile.Writer(str(stem), encoding="cp1252") as writer:
        writer.field("CD_MUN", "C", 7)
        writer.field("NM_MUN", "C", 40)
        writer.poly([[convert.transform(*p) for p in [(0, 0), (0, 1), (1, 1), (1, 0), (0, 0)]]])
        writer.record(MUNICIPALITY, "Anápolis sintética")
    stem.with_suffix(".prj").write_text(CRS.from_epsg(3857).to_wkt())
    stem.with_suffix(".cpg").write_text("1252")
    archive = tmp_path / "synthetic.zip"
    with zipfile.ZipFile(archive, "w") as z:
        for suffix in (".shp", ".shx", ".dbf", ".prj", ".cpg"):
            z.write(stem.with_suffix(suffix), "municipios" + suffix)
    target = tmp_path / "prepared.json"
    result = prepare_ibge(archive, MUNICIPALITY, target)
    assert result["name"] == "Anápolis sintética" and result["source_crs"] == "EPSG:3857"
    assert MunicipalityBoundary(target, MUNICIPALITY).point(Point(0.5, 0.5))[:2] == (0.5, 0.5)


@pytest.mark.django_db(transaction=True)
def test_postgresql_concurrent_catalog_confirmation(source):
    if connection.vendor != "postgresql":
        pytest.skip("Requires real PostgreSQL row locks")
    imported(source)
    item = CatalogPOI.objects.get(external_id="osm:node:1")
    owners = [user("catalog_a"), user("catalog_b")]
    gate = Barrier(2)

    def confirm(owner):
        close_old_connections()
        try:
            gate.wait(timeout=10)
            r = api(owner).post(
                f"{BASE}{item.pk}/confirmar/", {"confirmed": True, "nome": "Mesmo", "endereco": "Rua A"}
            )
            return r.status_code, r.data["id_local"]
        finally:
            close_old_connections()

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(confirm, owners))
    assert sorted(status for status, _ in results) == [200, 201]
    assert len({pk for _, pk in results}) == 1 and Local.objects.count() == 1


@pytest.mark.django_db(transaction=True)
def test_postgresql_concurrent_catalog_publishers():
    if connection.vendor != "postgresql":
        pytest.skip("Requires real PostgreSQL independent connections")
    CatalogScope.objects.get_or_create(pk=MUNICIPALITY)
    gate = Barrier(2)

    def acquire(_):
        close_old_connections()
        lease = CatalogLease(MUNICIPALITY)
        try:
            gate.wait(timeout=10)
            try:
                lease.acquire()
                return "acquired"
            except CatalogBusy:
                return "busy"
        finally:
            close_old_connections()

    with ThreadPoolExecutor(max_workers=2) as pool:
        assert sorted(pool.map(acquire, [1, 2])) == ["acquired", "busy"]


def test_ten_thousand_sql_budget_and_storage(source, tmp_path, django_assert_num_queries):
    report = imported(source)
    batch = CatalogBatch.objects.get(pk=report["batch_id"])
    CatalogPOI.objects.bulk_create(
        [CatalogPOI(external_id=f"osm:node:{i}", osm_type="node", osm_number=i) for i in range(1000, 11000)],
        batch_size=500,
    )
    pois = list(CatalogPOI.objects.filter(osm_number__gte=1000))
    values = source_values(
        {"amenity": "pharmacy", "name": "Synthetic pharmacy"},
        latitude=1,
        longitude=1,
        geometry_type="Point",
        point_method="original_node",
    )
    CatalogEntry.objects.bulk_create(
        [CatalogEntry(batch=batch, observed_in=batch, poi=poi, **values) for poi in pois], batch_size=250
    )
    with django_assert_num_queries(4):
        response = api().get(BASE, {"categorias": "farmacia", "page_size": "20"})
    assert response.data["count"] == 10001 and len(response.data["results"]) == 20
    measured = measure_catalog()
    Local.objects.bulk_create(
        [
            Local(nome=f"Synthetic {i}", endereco="Synthetic address", distancia=0, latitude=1 + i / 10000, longitude=1)
            for i in range(1000)
        ]
    )
    measured["matching_fixture_locals"] = 1000
    measured["matching_plan"] = (
        Local.objects.filter(latitude__range=(1, 1.0003), longitude__range=(1, 1.0003)).order_by("pk")[:101].explain()
    )
    assert measured["poi_count"] == 10004
    assert measured["database_bytes"] > 0
    if measured["measurement"] == "dbstat_unavailable":
        # SQLite without dbstat cannot measure individual table/index allocation.
        assert not measured["tables"]
        assert "catalog_bytes" not in measured
        assert measured["estimates"]["records"] == []
        assert measured["estimates"]["unavailable_reason"] == "table_and_index_bytes_not_measured"
    else:
        assert measured["catalog_bytes"] < measured["database_bytes"]
        assert len(measured["estimates"]["records"]) == 3
    import os

    if os.environ.get("CATALOG_BENCHMARK_REPORT"):
        write_json(
            os.environ["CATALOG_BENCHMARK_REPORT"], {"dataset": "SYNTHETIC 10000 plus four topology POIs", **measured}
        )


def test_catalog_node_location_index_is_platform_safe(tmp_path):
    # The location index remains in memory on Windows to avoid locked temp files.
    assert location_index(tmp_path, platform="win32") == "sparse_mem_array"
    linux_index = location_index(tmp_path, platform="linux")
    assert linux_index.startswith("sparse_file_array,")
    assert linux_index.endswith("locations.idx")
