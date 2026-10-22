import json
import uuid
from datetime import timedelta

import pytest
from django.utils import timezone
from drf_spectacular.generators import SchemaGenerator
from rest_framework.test import APIClient

from usuarios.models import Usuario
from .models import Local, RouteHistorySession, VisitaRecente

pytestmark = pytest.mark.django_db
URL = "/api/route-history/"
PREF = "/api/usuarios/me/route-history-preferences/"


@pytest.fixture
def history():
    user = Usuario.objects.create_user(nome="history", email="history@test.test", password="test-password")
    other = Usuario.objects.create_user(nome="other-history", email="other-history@test.test", password="test-password")
    local = Local.objects.create(nome="Local", endereco="Rua", distancia=0, latitude=0, longitude=0)
    client = APIClient()
    client.force_authenticate(user)
    return user, other, local, client


def opt_in(client, origin=False):
    response = client.patch(PREF, {"save_history": True, "save_origin": origin,
                            "notice_version": "2026-10-21"}, format="json")
    assert response.status_code == 200
    return response.data["revision"]


def body(local, revision=1, **changes):
    return {
        "session_id": str(uuid.uuid4()),
        "event": "started",
        "consent_revision": revision,
        "destination_name": local.nome,
        "destination_source": "acessoja",
        "local_id": local.pk,
        "latitude": 0,
        "longitude": 0,
        "estimated_distance": 100,
        "estimated_duration": 20,
        **changes,
    }


def event(client, session, name, index=1, revision=1, **changes):
    return client.patch(
        f"{URL}{session}/",
        {"event": name, "event_index": index, "consent_revision": revision, **changes},
        format="json",
    )


def test_default_is_off_and_legacy_flags_are_not_consent(history):
    user, other, local, client = history
    assert client.get(PREF).data == {"save_history": False, "save_origin": False, "revision": 0}
    Usuario.objects.filter(pk=user.pk).update(historico_visivel=True, compartilhar_localizacao=True)
    assert client.post(URL, body(local, revision=0), format="json").status_code == 403
    assert RouteHistorySession.objects.count() == 0
    assert client.get(URL).data["results"] == []


@pytest.mark.parametrize(
    "path,method",
    [
        (PREF, "get"),
        (PREF, "patch"),
        (URL, "get"),
        (URL, "post"),
        (URL + "clear/", "delete"),
        (URL + "origins/", "delete"),
        (URL + str(uuid.uuid4()) + "/", "get"),
    ],
)
def test_authentication_required(path, method):
    assert getattr(APIClient(), method)(path, {}, format="json").status_code in (401, 403)


def test_started_only_idempotency_and_distinct_sessions(history):
    user, other, local, client = history
    revision = opt_in(client)
    payload = body(local, revision)
    response = client.post(URL, payload, format="json")
    assert response.status_code == 201
    assert response.data["status"] == "in_progress" and response.data["ended_at"] is None
    assert response.data["started_at"] is not None and response.data["latitude"] == 0
    assert client.post(URL, payload, format="json").status_code == 200
    assert client.post(URL, {**payload, "destination_name": "Changed"}, format="json").status_code == 409
    assert client.post(URL, body(local, revision), format="json").status_code == 201
    assert RouteHistorySession.objects.count() == 2
    assert not VisitaRecente.objects.exists()
    public = client.get("/api/usuarios/perfil/", {"nome": user.nome}).data
    assert not set(public) & {"save_route_history", "save_route_origin", "route_history_revision", "route_sessions"}
    for path in ["/auth/users/", "/auth/users/me/", "/api/avaliacoes/modal-avaliacoes/"]:
        assert "route_history" not in json.dumps(client.get(path).data)
    assert (
        client.put("/api/usuarios/perfil/?nome=history", {"save_route_history": True}, format="json").status_code == 400
    )


@pytest.mark.parametrize(
    "changes",
    [
        {"event": "preview"},
        {"event": "visit"},
        {"event": "arrived"},
        {"user": 1},
        {"nome_usuario": "other-history"},
        {"started_at": "2020-01-01"},
        {"latitude": 91},
        {"longitude": -181},
        {"latitude": True},
        {"latitude": None},
        {"estimated_duration": -1},
        {"external_id": "osm:node:1"},
        {"destination_source": "manual"},
    ],
)
def test_invalid_start_is_atomic(history, changes):
    user, other, local, client = history
    opt_in(client)
    assert client.post(URL, body(local, **changes), format="json").status_code == 400
    assert not RouteHistorySession.objects.exists()


@pytest.mark.parametrize("invalid", [float("nan"), float("inf"), -float("inf")])
def test_nonfinite_coordinates_are_rejected(history, invalid):
    user, other, local, client = history
    opt_in(client)
    data = body(local, latitude=invalid)
    response = client.post(URL, json.dumps(data), content_type="application/json")
    assert response.status_code == 400
    assert not RouteHistorySession.objects.exists()


def test_owner_scope_and_client_identity_cannot_select_another_account(history):
    user, other, local, client = history
    opt_in(client)
    response = client.post(URL, body(local), format="json")
    session = response.data["session_id"]
    assert client.get(URL)["Cache-Control"] == "private, no-store"
    assert client.get(URL, {"user": other.pk}).status_code == 400
    client.force_authenticate(other)
    opt_in(client)
    assert client.get(URL).data["count"] == 0
    assert client.get(f"{URL}{session}/").status_code == 404
    assert event(client, session, "cancelled").status_code == 404
    assert client.delete(f"{URL}{session}/").status_code == 404
    client.delete(URL + "clear/")
    assert RouteHistorySession.objects.get(user=user).deleted_at is None


def test_transitions_recalculation_unknown_end_and_terminal_order(history):
    user, other, local, client = history
    opt_in(client)
    session = client.post(URL, body(local), format="json").data["session_id"]
    response = event(client, session, "recalculated", estimated_distance=220)
    assert response.data["status"] == "in_progress" and response.data["estimated_distance"] == 220
    assert event(client, session, "interrupted", index=2).data["ended_at"] is None
    assert event(client, session, "resumed", index=3).data["status"] == "in_progress"
    assert event(client, session, "arrived", index=4).status_code == 400
    response = event(client, session, "arrived", index=4, arrival_confirmed=True)
    assert response.data["status"] == "completed" and response.data["ended_at"] is not None
    assert event(client, session, "arrived", index=4, arrival_confirmed=True).data == response.data
    assert event(client, session, "recalculated", index=1, estimated_distance=999).status_code == 409
    assert event(client, session, "resumed", index=5).status_code == 409
    record = RouteHistorySession.objects.get(session_id=session)
    assert record.status == "completed" and record.estimated_distance == 220
    assert RouteHistorySession.objects.count() == 1


def test_cancellation_after_start_is_terminal_but_interruption_has_unknown_end(history):
    user, other, local, client = history
    opt_in(client)
    session = client.post(URL, body(local), format="json").data["session_id"]
    assert event(client, session, "interrupted").data["ended_at"] is None
    assert event(client, session, "arrived", index=2, arrival_confirmed=True).status_code == 409
    response = event(client, session, "cancelled", index=2)
    assert response.data["status"] == "cancelled" and response.data["ended_at"] is not None
    assert event(client, session, "resumed", index=3).status_code == 409


def test_origin_requires_separate_consent_and_is_rounded_before_storage(history):
    user, other, local, client = history
    revision = opt_in(client)
    data = body(local, revision, origin_latitude=-16.326789, origin_longitude=-48.952876)
    assert client.post(URL, data, format="json").status_code == 400
    assert not RouteHistorySession.objects.exists()
    revision = opt_in(client, origin=True)
    response = client.post(URL, {**data, "consent_revision": revision}, format="json")
    assert response.status_code == 201
    record = RouteHistorySession.objects.get()
    assert (record.origin_latitude, record.origin_longitude) == (-16.33, -48.95)
    response = client.patch(PREF, {"save_origin": False}, format="json")
    assert response.status_code == 200
    assert event(client, record.session_id, "recalculated", revision=revision).status_code == 409
    assert (
        event(
            client,
            record.session_id,
            "recalculated",
            revision=response.data["revision"],
            origin_latitude=0,
            origin_longitude=0,
        ).status_code
        == 400
    )
    record.refresh_from_db()
    assert record.origin_latitude == -16.33
    client.delete(URL + "origins/")
    record.refresh_from_db()
    assert record.origin_latitude is None and record.latitude == 0 and record.deleted_at is None


def test_revocation_preserves_old_records_and_stale_consent_cannot_collect(history):
    user, other, local, client = history
    revision = opt_in(client)
    client.post(URL, body(local, revision), format="json")
    client.patch(PREF, {"save_history": False}, format="json")
    assert client.get(URL).data["count"] == 1
    assert client.post(URL, body(local, revision), format="json").status_code == 403
    newer = opt_in(client)
    assert newer > revision
    assert client.post(URL, body(local, revision), format="json").status_code == 409
    assert client.post(URL, body(local, newer), format="json").status_code == 201


def test_origin_can_be_revoked_with_recording_disabled(history):
    user, other, local, client = history
    opt_in(client, origin=True)
    client.post(URL, body(local), format="json")
    client.patch(PREF, {"save_history": False}, format="json")
    response = client.patch(PREF, {"save_origin": False}, format="json")
    assert response.status_code == 200
    assert response.data == {"save_history": False, "save_origin": False, "revision": 3}
    assert client.get(URL).data["count"] == 1


def test_deleted_record_scrubs_private_data_and_late_start_or_patch_cannot_restore(history):
    user, other, local, client = history
    opt_in(client)
    data = body(local)
    client.post(URL, data, format="json")
    assert client.delete(f"{URL}{data['session_id']}/").status_code == 204
    assert client.get(URL).data["count"] == 0
    assert client.post(URL, data, format="json").status_code == 410
    assert event(client, data["session_id"], "cancelled").status_code == 410
    record = RouteHistorySession.objects.get()
    assert record.destination_name == "" and record.latitude is None and record.local_id is None
    assert record.started_at is None and record.ended_at is None and record.deleted_at is not None


def test_clear_is_private_keeps_visits_contributions_and_prevents_pending_creates(history):
    user, other, local, client = history
    from contribuicoes.models import ContributionPointEvent

    opt_in(client)
    visit = VisitaRecente.objects.create(user=user, local=local)
    contribution = ContributionPointEvent.objects.create(
        user=user, local=local, action="history-test", points=10, idempotency_key="history-test-points"
    )
    points = contribution.points
    client.post(URL, body(local), format="json")
    queued = body(local)
    result = client.delete(URL + "clear/")
    assert result.status_code == 200 and result.data["save_history"] is True
    assert client.post(URL, queued, format="json").status_code == 409
    assert client.get(URL).data["count"] == 0
    assert VisitaRecente.objects.filter(pk=visit.pk).exists()
    contribution.refresh_from_db()
    assert contribution.points == points


def test_deleted_destination_keeps_historical_coordinates_without_recreating_a_place(history):
    user, other, local, client = history
    opt_in(client)
    response = client.post(URL, body(local), format="json")
    local.delete()
    data = client.get(f"{URL}{response.data['session_id']}/").data
    assert data["destination_available"] is False and data["local_id"] is None
    assert data["destination_name"] == "Local" and data["latitude"] == 0
    assert not Local.objects.exists()


def test_external_and_manual_destinations_keep_separate_ids(history):
    user, other, local, client = history
    opt_in(client)
    for source in ["openstreetmap", "manual"]:
        data = body(local, destination_source=source)
        del data["local_id"]
        if source == "openstreetmap":
            data["external_id"] = "osm:way:200"
        result = client.post(URL, data, format="json")
        assert result.status_code == 201 and result.data["local_id"] is None
    assert Local.objects.count() == 1


def test_stable_pagination_and_schema(history):
    user, other, local, client = history
    opt_in(client)
    for i in range(4):
        client.post(URL, body(local), format="json")
    RouteHistorySession.objects.update(started_at=timezone.now() - timedelta(days=1))
    first = client.get(URL, {"page_size": 2}).data
    second = client.get(first["next"]).data
    assert first["count"] == 4 and len(first["results"]) == 2
    assert not {r["session_id"] for r in first["results"]} & {r["session_id"] for r in second["results"]}
    schema = SchemaGenerator().get_schema(request=None, public=True)
    assert URL in schema["paths"] and PREF in schema["paths"]
    assert schema["paths"][URL]["post"]["security"]
