"""Cards 62–67: public projection, real persistence and versioned private pages."""

import re
from pathlib import Path

import pytest
from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError as ModelValidationError
from django.db import connection, IntegrityError, transaction
from django.utils import timezone
from rest_framework.test import APIClient

from acessoja.accessibility_catalog import CATALOG_VERSION, RESOURCE_IDS
from favoritos.models import Favorito
from locais.catalog_models import CatalogBatch, CatalogEntry, CatalogPOI, CatalogScope
from locais.models import Local, VisitaRecente
from locais.services.catalog_rules import source_values, MUNICIPALITY
from locais.services.categories import SUBCATEGORIES, subcategory_for
from locais.accessibility import matching_resources, presence_count
from modal_avaliacao.models import ModalAvaliacao

pytestmark = pytest.mark.django_db
URL = "/api/locais/descoberta/"
R = "rampa_acesso"
B = "banheiro_acessivel"


def user(name="discovery"):
    return get_user_model().objects.create_user(nome=name, email=f"{name}@test.invalid", password="test-password")


def api(owner=None):
    value = APIClient()
    if owner:
        value.force_authenticate(owner)
    return value


def local(name, states=None, **extra):
    return Local.objects.create(
        nome=name,
        endereco="Rua Teste",
        distancia=0,
        accessibility_information={key: {"state": state} for key, state in (states or {}).items()},
        **extra,
    )


def personal(resources=(R, B), **extra):
    return {
        "criteria": {"page_size": "1", "ordering": "name"},
        "personalization": {
            "resources": list(resources),
            "mode": "prioritize",
            "catalog_version": CATALOG_VERSION,
            "snapshot_revision": 1,
            **extra,
        },
    }


def catalog(name="OSM", tags=None, linked=None, number=1):
    scope, _ = CatalogScope.objects.get_or_create(pk=MUNICIPALITY)
    batch = scope.active_batch or CatalogBatch.objects.create(
        scope=scope,
        fingerprint="test",
        snapshot_at=timezone.now(),
        rules_version="test",
        boundary_hash="test",
        complete=True,
        state="published",
    )
    if not scope.active_batch:
        scope.active_batch = batch
        scope.save()
    poi = CatalogPOI.objects.create(osm_type="node", osm_number=number, external_id=f"node/{number}", local=linked)
    values = source_values(
        {"name": name, **(tags or {"amenity": "cafe"})},
        latitude=0,
        longitude=0,
        geometry_type="Point",
        point_method="original",
    )
    return CatalogEntry.objects.create(poi=poi, batch=batch, observed_in=batch, **values)


@pytest.mark.parametrize("state", ["unknown", "absence_reported", "divergent", "limited", "not_applicable", "invalid"])
def test_only_reported_presence_scores(state):
    info = {R: {"state": state}, B: {"state": "presence_reported"}}
    assert presence_count(info, [R, B, B]) == 1
    assert matching_resources(info, [R, B], combination="qualquer")[0]
    assert not matching_resources(info, [R, B])[0]
    assert matching_resources(info, [R], True)[0] == (state == "unknown")
    assert matching_resources(info, [R], mode="priorizar")[0]
    assert matching_resources(info, [])[0]


def test_private_priority_global_pages_keeps_zero_and_does_not_persist():
    owner = user()
    owner.accessibility_preferences = [B]
    owner.save()
    a = local("A zero")
    b = local("B one", {R: "presence_reported"})
    c = local("C two", {R: "presence_reported", B: "presence_reported"})
    payload = personal()
    client = api(owner)
    response = client.post(URL, payload, format="json")
    assert response.status_code == 200, response.data
    assert response.data["count"] == 3
    assert response.data["results"][0]["id_local"] == c.pk
    ids = [c.pk]
    while response.data["next"]:
        payload["cursor"] = response.data["next"]
        assert R not in payload["cursor"] and B not in payload["cursor"]
        response = client.post(URL, payload, format="json")
        assert response.status_code == 200, response.data
        ids.extend(row["id_local"] for row in response.data["results"])
    assert ids == [c.pk, b.pk, a.pk]
    owner.refresh_from_db()
    assert owner.accessibility_preferences == [B]
    assert not Favorito.objects.exists() and not ModalAvaliacao.objects.exists() and not VisitaRecente.objects.exists()
    public = api().get(f"/api/locais/{c.pk}/").data
    assert "resource_match" not in public and "personalization" not in public


@pytest.mark.parametrize("mode,expected", [("all", 1), ("any", 2), ("prioritize", 3)])
def test_personal_modes_separate_from_manual(mode, expected):
    local("A", {R: "presence_reported", B: "presence_reported"}, categoria="saude")
    local("B", {R: "presence_reported"}, categoria="saude")
    local("C", categoria="saude")
    local("D", {R: "presence_reported", B: "presence_reported"}, categoria="educacao")
    payload = personal(mode=mode)
    payload["criteria"]["categorias"] = "saude"
    response = api(user()).post(URL, payload, format="json")
    assert response.status_code == 200, response.data
    assert response.data["count"] == expected


def test_manual_all_any_prioritize_and_legacy_envelopes():
    local("A", {R: "presence_reported", B: "absence_reported"})
    local("B")
    for endpoint in [URL, "/api/locais/"]:
        assert api().get(endpoint, {"recursos": f"{R},{B}", "paginated": "true"}).data["count"] == 0
        assert (
            api()
            .get(endpoint, {"recursos": f"{R},{B}", "combinacao_recursos": "qualquer", "paginated": "true"})
            .data["count"]
            == 1
        )
        assert (
            api()
            .get(endpoint, {"recursos": f"{R},{B}", "modo_recursos": "priorizar", "paginated": "true"})
            .data["count"]
            == 2
        )
    assert isinstance(api().get("/api/locais/").data, list)


def test_unknown_opt_in_never_scores_or_accepts_absence():
    local("Unknown")
    local("Absent", {R: "absence_reported"})
    local("Present", {R: "presence_reported"})
    response = api().get(URL, {"recursos": R, "incluir_desconhecidos": "true"})
    assert {r["nome"] for r in response.data["results"]} == {"Unknown", "Present"}
    response = api().get(URL, {"recursos": R, "modo_recursos": "priorizar"})
    assert response.data["count"] == 3
    assert response.data["results"][0]["nome"] == "Present"


def test_cursor_bound_to_account_query_and_version():
    owner, other = user("a"), user("b")
    a = local("A", {R: "presence_reported"})
    local("B")
    payload = personal()
    first = api(owner).post(URL, payload, format="json")
    cursor = first.data["next"]
    assert api(other).post(URL, {**payload, "cursor": cursor}, format="json").status_code == 400
    changed = personal(resources=[B])
    assert api(owner).post(URL, {**changed, "cursor": cursor}, format="json").status_code == 400
    a.accessibility_information = {R: {"state": "absence_reported"}}
    a.save()
    response = api(owner).post(URL, {**payload, "cursor": cursor}, format="json")
    assert response.status_code == 409
    assert response.data["code"] == "discovery_changed"


def test_public_pages_version_and_private_headers():
    local("A")
    local("B")
    response = api().get(URL, {"page_size": "1"})
    assert response.status_code == 200, response.data
    assert api().get(response.data["next"]).status_code == 200
    assert response["Cache-Control"] == "private, no-store"
    assert {"Authorization", "Cookie"} <= set(response["Vary"].split(", "))
    assert api().post(URL, personal(), format="json").status_code == 401
    response = api(user()).post(
        URL, {**personal(), "personalization": {"resources": ["sensitive-invalid"]}}, format="json"
    )
    assert response.status_code == 400 and "sensitive-invalid" not in str(response.data)


@pytest.mark.parametrize(
    "query",
    [
        "recursos=x",
        "recursos=rampa_acesso,,piso_tatil",
        "recursos=x&recursos=y",
        "combinacao_recursos=x",
        "modo_recursos=x",
        "incluir_desconhecidos=1",
        "ordering=proximity",
        "page=2",
        "subcategorias=DROP%20TABLE",
        "categorias=educacao&subcategorias=hospital",
        "subcategorias=hospital&subcategorias=escola",
        "modo_recursos=priorizar&incluir_desconhecidos=false",
        "modo_recursos=priorizar&combinacao_recursos=todos",
        "owner=1",
    ],
)
def test_invalid_parameters_rejected_without_write(query):
    assert api().get(URL + "?" + query).status_code == 400
    assert not Local.objects.exists()


def test_score_before_distance_name_and_missing_coordinates():
    no_point = local("B strong", {R: "presence_reported"})
    near = local("A weak", latitude=0, longitude=0)
    far = local("C strong", {R: "presence_reported"}, latitude=1, longitude=1)
    response = api().get(
        URL,
        {"recursos": R, "modo_recursos": "priorizar", "ordering": "proximity", "origin_lat": "0", "origin_lon": "0"},
    )
    assert [r["id_local"] for r in response.data["results"]] == [far.pk, no_point.pk, near.pk]


def test_category_semantics_verified_osm_and_canonical_identity():
    legacy = local("Hospital legacy", categoria="saude")
    hospital = local("Hospital", categoria="saude", subcategoria="hospital")
    school = local("School", categoria="educacao", subcategoria="escola")
    linked = catalog(tags={"amenity": "hospital", "toilets:wheelchair": "yes"}, linked=hospital)
    catalog("Library", {"amenity": "library"}, number=2)
    response = api().get(URL, {"categorias": "saude,educacao", "subcategorias": "hospital"})
    assert {r["id_local"] for r in response.data["results"]} == {hospital.pk, school.pk}
    response = api().get(URL, {"categorias": "saude"})
    assert {r["id_local"] for r in response.data["results"]} == {legacy.pk, hospital.pk}
    response = api().get(URL, {"subcategorias": "biblioteca"})
    assert response.data["count"] == 1 and response.data["results"][0]["categoria"] == "outros"
    assert api().get(URL, {"origens": "openstreetmap", "subcategorias": "hospital"}).data["count"] == 1
    assert linked.poi.local_id == hospital.pk


@pytest.mark.parametrize(
    "tags,expected",
    [
        ({"name": "Hospital"}, ""),
        ({"healthcare": "yes"}, ""),
        ({"amenity": "hospital"}, "hospital"),
        ({"shop": "clothes"}, "roupas"),
        ({"shop": "convenience"}, "conveniencia"),
        ({"shop": "supermarket"}, "supermercado"),
        ({"amenity": "library"}, "biblioteca"),
        ({"amenity": "cinema"}, "cinema"),
        ({"amenity": "theatre"}, "teatro"),
        ({"amenity": "community_centre"}, "centro_comunitario"),
        ({"amenity": "hospital", "shop": "clothes"}, ""),
        ({"amenity": "clinic;hospital"}, ""),
        ({"shop": "other_store"}, ""),
    ],
)
def test_category_mapping_conservative(tags, expected):
    assert subcategory_for(tags) == expected
    if expected:
        parent = SUBCATEGORIES[expected]["parent"]
        assert subcategory_for(tags, parent) == expected
        values = source_values(tags, latitude=0, longitude=0, geometry_type="Point", point_method="original")
        assert values["category"] == parent


def test_category_pair_all_write_paths_and_database_constraint():
    value = local("A", categoria="saude", subcategoria="hospital")
    assert (
        api(user())
        .post(
            "/api/locais/",
            {"nome": "B", "endereco": "Rua", "distancia": 0, "categoria": "educacao", "subcategoria": "hospital"},
            format="json",
        )
        .status_code
        == 400
    )
    value.categoria = "educacao"
    with pytest.raises(ModelValidationError):
        value.save()
    with pytest.raises(IntegrityError), transaction.atomic():
        Local.objects.filter(pk=value.pk).update(categoria="educacao")


def test_server_limit_is_explicit_not_global(settings):
    settings.DISCOVERY_MAX_CANDIDATES = 2
    for i in range(4):
        local(str(i))
    response = api().get(URL)
    assert response.data["count"] == 2 and not response.data["count_exact"]
    assert response.data["scope"]["limited"] and not response.data["scope"]["coverage_complete"]
    assert response.data["scope"]["sources"]["openstreetmap"] == "unavailable"


def test_projection_uses_constant_query_count():
    for i in range(30):
        local(str(i), {R: "presence_reported"})
    queries = []

    def count(execute, sql, params, many, context):
        queries.append(sql.split()[0])
        return execute(sql, params, many, context)

    with connection.execute_wrapper(count):
        response = api().get(URL, {"recursos": R, "modo_recursos": "priorizar"})
    assert response.status_code == 200, response.data
    assert 1 <= len(queries) <= 12, len(queries)
    assert response.data["count"] == 30


def test_catalog_contract_has_ten_resources_and_generated_flutter_children():
    assert len(RESOURCE_IDS) == 10
    text = (Path(__file__).parents[1] / "frontend/lib/models/place_subcategories.dart").read_text(encoding="utf-8")
    entries = re.findall(r"'([^']+)':\s*\{\s*'parent': '([^']+)',\s*'pt': '([^']+)',\s*'en': '([^']+)',?\s*\}", text)
    assert {key: {"parent": parent, "pt": pt, "en": en} for key, parent, pt, en in entries} == {
        key: {field: value[field] for field in ["parent", "pt", "en"]} for key, value in SUBCATEGORIES.items()
    }
    assert api().get("/api/locais/categorias/").data["version"] == 1


def test_legacy_catalog_new_modes_and_subcategories_use_authorized_projection():
    catalog("Hospital", {"amenity": "hospital", "toilets:wheelchair": "yes"}, number=81)
    catalog("Clinic", {"amenity": "clinic", "toilets:wheelchair": "no"}, number=82)
    catalog("Ambiguous", {"amenity": "hospital", "shop": "clothes"}, number=83)
    base = "/api/locais/catalogo/"
    assert api().get(base, {"subcategorias": "hospital"}).data["count"] == 1
    response = api().get(base, {"recursos": f"{R},{B}", "combinacao_recursos": "qualquer"})
    assert response.data["count"] == 1
    response = api().get(base, {"recursos": B, "modo_recursos": "priorizar"})
    assert response.data["count"] == 3 and response.data["results"][0]["nome"] == "Hospital"


def test_private_snapshot_not_implicitly_replaced_by_profile_edits():
    owner = user()
    first = local("Ramp", {R: "presence_reported"})
    local("Toilet", {B: "presence_reported"})
    client = api(owner)
    payload = personal([R])
    response = client.post(URL, payload, format="json")
    owner.accessibility_preferences = [B]
    owner.save(update_fields=["accessibility_preferences"])
    again = client.post(URL, payload, format="json")
    assert response.data["version"] == again.data["version"]
    assert again.data["results"][0]["id_local"] == first.pk
    payload["cursor"] = response.data["next"]
    assert client.post(URL, payload, format="json").status_code == 200


def test_private_session_authentication_keeps_csrf_and_expiration():
    owner = user()
    client = APIClient(enforce_csrf_checks=True)
    client.force_login(owner)
    session = client.session
    session["web_login_at"] = timezone.now().timestamp()
    session.save()
    assert client.post(URL, personal(), format="json").status_code == 403
    client.logout()
    assert client.post(URL, personal(), format="json").status_code == 401
    assert client.get(URL).status_code == 200


def test_private_logging_redacts_body_and_credentials():
    import logging
    from acessoja.logging_filters import RedactCoordinates

    for body in [
        '{"personalization":{"resources":["private-selection"]}}',
        "Authorization: Token private-credential",
        '{"resources": ["private-selection"]}',
    ]:
        record = logging.LogRecord("test", logging.ERROR, "", 1, "%s", (body,), None)
        RedactCoordinates().filter(record)
        assert "private-selection" not in record.getMessage()
        assert "private-credential" not in record.getMessage()


@pytest.mark.parametrize(
    "personalization",
    [
        None,
        [],
        {"resources": [R], "mode": "invalid"},
        {"resources": [R], "catalog_version": True},
        {"resources": [R], "catalog_version": CATALOG_VERSION, "mode": "prioritize", "include_unknown": True},
        {"resources": [R], "catalog_version": CATALOG_VERSION, "owner": 9},
    ],
)
def test_invalid_private_context_is_sanitized(personalization):
    response = api(user()).post(URL, {"personalization": personalization}, format="json")
    assert response.status_code == 400
    assert response.data["code"] == "invalid_discovery"


def test_cursor_expires_and_rejects_post_query_identity_injection():
    from unittest.mock import patch

    local("A")
    local("B")
    owner = user()
    payload = personal()
    first = api(owner).post(URL, payload, format="json")
    with patch("django.core.signing.time.time", return_value=9999999999):
        response = api(owner).post(URL, {**payload, "cursor": first.data["next"]}, format="json")
    assert response.status_code == 409
    assert api(owner).post(URL + "?owner=1", payload, format="json").status_code == 400


def test_consolidated_text_uses_same_normalized_words_for_internal_and_osm():
    local("Café Central", categoria="cafeteria")
    catalog("Café Central OSM", number=991)
    response = api().get(URL, {"search": "cafe central"})
    assert response.status_code == 200 and response.data["count"] == 2


def test_classification_change_invalidates_continuation():
    first = local("A", categoria="saude", subcategoria="hospital")
    local("B", categoria="saude", subcategoria="hospital")
    page = api().get(URL, {"page_size": "1"})
    Local.objects.filter(pk=first.pk).update(subcategoria="clinica")
    assert api().get(page.data["next"]).status_code == 409


def test_backend_rating_uses_unrounded_visible_average_before_auxiliary_count():
    from locais.discovery import DiscoveryOptions
    from locais.discovery_integrated import rank_documents
    from locais.accessibility import parse_filters

    rows = [
        {
            "nome": "A",
            "canonical_id": "a",
            "origins": ["acessoja"],
            "categoria": "saude",
            "media_estrelas": 4.5,
            "_discovery_rating": 4.51,
            "quantidade_avaliacoes": 10,
            "accessibility": {},
        },
        {
            "nome": "Z",
            "canonical_id": "z",
            "origins": ["acessoja"],
            "categoria": "saude",
            "media_estrelas": 4.5,
            "_discovery_rating": 4.54,
            "quantidade_avaliacoes": 2,
            "accessibility": {},
        },
    ]
    ordered = rank_documents(rows, parse_filters({}), DiscoveryOptions({"ordering": "rating"}), None)
    assert [row["canonical_id"] for row in ordered] == ["z", "a"]


def test_generated_category_catalog_command_checks_real_contract(monkeypatch, capsys):
    from scripts.generate_place_categories import main

    monkeypatch.setattr("sys.argv", ["generate_place_categories.py"])
    main()
    assert "11 parents, 22 children" in capsys.readouterr().out


def test_legacy_manual_receipt_retry_survives_additive_child_field():
    import hashlib
    import json
    import uuid
    from locais.models import ManualPlaceRegistration

    owner = user()
    known = local("Known", categoria="saude")
    old = {
        "nome": "Known",
        "endereco": "Synthetic",
        "categoria": "saude",
        "latitude": 0.0,
        "longitude": 0.0,
        "point_confirmed": True,
    }
    request_id = uuid.uuid4()
    digest = hashlib.sha256(json.dumps(old, sort_keys=True).encode()).hexdigest()
    ManualPlaceRegistration.objects.create(user=owner, request_id=request_id, payload_hash=digest, local=known)
    for extra in [{}, {"subcategoria": ""}]:
        response = api(owner).post(
            "/api/locais/cadastro-manual/", {**old, **extra, "request_id": str(request_id)}, format="json"
        )
        assert response.status_code == 200, response.data
        assert response.data["id_local"] == known.pk
    assert Local.objects.count() == 1


def reference_cases():
    import json

    return json.loads((Path(__file__).parent / "data/discovery_examples.json").read_text())["cases"]


@pytest.mark.parametrize("case", reference_cases(), ids=lambda case: case["name"])
def test_shared_reference_truth_table_across_backend_and_flutter(case):
    info = {key: {"state": state} for key, state in zip([R, B], case["states"])}
    assert presence_count(info, [R, B, R]) == case["score"]
    assert matching_resources(info, [R, B], case["unknown"])[0] == case["all"]
    assert matching_resources(info, [R, B], case["unknown"], combination="qualquer")[0] == case["any"]
    assert matching_resources(info, [R, B], mode="priorizar")[0]


def test_three_resource_p3_p2_p1_p0_exact_ids_count_and_stable_page_boundaries():
    keys = [R, B, "piso_tatil"]
    ids = [
        local(name, {key: "presence_reported" for key in keys[:count]}).pk
        for name, count in [("A zero", 0), ("B one", 1), ("C two", 2), ("Z three", 3)]
    ]
    response = api().get(URL, {"page_size": "1", "recursos": ",".join([*keys, R]), "modo_recursos": "priorizar"})
    actual = []
    scores = []
    while True:
        assert response.status_code == 200 and response.data["count"] == 4
        row = response.data["results"][0]
        actual.append(row["id_local"])
        scores.append(row["resource_match"])
        if not response.data["next"]:
            break
        response = api().get(response.data["next"])
    assert actual == list(reversed(ids))
    assert scores == [{"count": count, "total": 3} for count in [3, 2, 1, 0]]


def test_withdrawn_osm_evidence_cannot_reappear_through_raw_tag_in_discovery_or_panel():
    from evidencias.capture import sync_catalog_entries
    from evidencias.models import ResourceEvidence

    entry = catalog(tags={"amenity": "cafe", "toilets:wheelchair": "yes"}, number=999)
    sync_catalog_entries([entry])
    root = ResourceEvidence.objects.get(external_id=entry.poi.external_id, resource=B)
    root.withdrawn = True
    root.save(update_fields=["withdrawn"])
    discovery = api().get(URL)
    assert discovery.status_code == 200
    panel = api().get(f"/api/locais/catalogo/{entry.poi.pk}/")
    assert panel.status_code == 200, panel.data
    for row in [discovery.data["results"][0], panel.data]:
        assert row["accessibility"][B]["state"] == "unknown"
        assert "toilets:wheelchair" not in row["accessibility_data"]
    root.refresh_from_db()
    assert root.withdrawn


def test_current_linked_tags_classify_legacy_and_conflicts_are_unknown_in_list_and_detail():
    known = local("Synthetic", categoria="saude")
    entry = catalog(tags={"amenity": "hospital"}, linked=known, number=1001)
    for url in [URL, "/api/locais/"]:
        response = api().get(url, {"subcategorias": "hospital"})
        rows = response.data["results"] if isinstance(response.data, dict) else response.data
        assert len(rows) == 1, response.data
        assert rows[0]["subcategoria"] == "hospital"
    assert api().get(f"/api/locais/{known.pk}/").data["subcategoria"] == "hospital"
    known.subcategoria = "clinica"
    known.save()
    assert api().get(f"/api/locais/{known.pk}/").data["subcategoria"] == ""
    for child in ["hospital", "clinica"]:
        assert api().get(URL, {"subcategorias": child}).data["count"] == 0
    entry.tags = {"amenity": "clinic"}
    entry.save()
    assert api().get(URL, {"subcategorias": "clinica"}).data["count"] == 1


def test_multiple_linked_type_assertions_are_deduplicated_or_marked_unknown_independent_of_order():
    from locais.services.categories import canonical_subcategory

    hospital, clinic = {"amenity": "hospital"}, {"amenity": "clinic"}
    assert canonical_subcategory("saude", "", [hospital, hospital]) == "hospital"
    for observations in [[hospital, clinic], [clinic, hospital]]:
        assert canonical_subcategory("saude", "", observations) == ""
    known = local("Synthetic", categoria="saude")
    catalog(tags=hospital, linked=known, number=1002)
    catalog(tags=clinic, linked=known, number=1003)
    assert api().get(f"/api/locais/{known.pk}/").data["subcategoria"] == ""
    assert api().get(URL, {"subcategorias": "hospital"}).data["count"] == 0
