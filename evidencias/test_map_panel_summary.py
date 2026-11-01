"""CT-01/02/06/21/23: authoritative projection is independent of source pages."""

import pytest
from rest_framework.test import APIClient
from locais.models import Local
from modal_avaliacao.models import ModalAvaliacao
from usuarios.models import Usuario
from .capture import sync_remote_places
from .models import ResourceEvidence

pytestmark = pytest.mark.django_db


def test_resource_summary_uses_all_public_pages_and_never_private_authorship(settings):
    settings.PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]
    local = Local.objects.create(nome="Synthetic panel", endereco="Synthetic street", distancia=0)
    for i in range(22):
        user = Usuario.objects.create_user(
            f"panel-synthetic-{i}", password="synthetic-only", email=f"{i}@example.invalid", mostrar_avaliacoes=i != 21
        )
        review = ModalAvaliacao.objects.create(
            user=user,
            local=local,
            estrelas=4,
            questionnaire_version=2,
            verified_author=True,
            answers={"rampa_acesso": "no" if i >= 20 else "yes"},
        )
        if i == 20:
            ResourceEvidence.objects.filter(review=review, resource="rampa_acesso").update(key="zzzz:last-visible")
    client = APIClient()
    query = {"local_id": local.pk, "resource": "rampa_acesso"}
    plain = client.get("/api/evidencias/", query)
    assert plain.status_code == 200 and "summary" not in plain.data
    response = client.get("/api/evidencias/", {**query, "include_summary": "true"})
    assert response.status_code == 200
    assert response.data["count"] == 21 and len(response.data["results"]) == 20
    assert all(row["state"] == "presence_reported" for row in response.data["results"])
    summary = response.data["summary"]
    assert summary["state"] == "divergent" and summary["provenance"]["evidence_count"] == 21
    assert summary["evidence"][0]["counts"] == {"yes": 20, "no": 1, "unknown": 0, "not_applicable": 0}
    assert "panel-synthetic" not in str(summary) and "example.invalid" not in str(summary)
    assert response["Cache-Control"] == "private, no-store"
    second = client.get(response.data["next"])
    assert second.status_code == 200
    assert second.data["summary"]["state"] == summary["state"]
    assert second.data["summary"]["provenance"] == summary["provenance"]
    assert second.data["summary"]["evidence"][0]["counts"] == summary["evidence"][0]["counts"]
    assert len(second.data["results"]) == 1


def test_unlinked_osm_summary_and_absent_resource_never_require_fake_local():
    external = "osm:node:675431"
    sync_remote_places([{"external_id": external, "accessibility_data": {"toilets:wheelchair": "yes"}}])
    client = APIClient()
    for resource, state in [("banheiro_acessivel", "presence_reported"), ("piso_tatil", "unknown")]:
        response = client.get(
            "/api/evidencias/", {"external_id": external, "resource": resource, "include_summary": True}
        )
        assert response.status_code == 200
        assert response.data["summary"]["state"] == state
    assert not Local.objects.exists()


def test_invalid_summary_parameter_cannot_bypass_scope_validation():
    client = APIClient()
    for body in [
        {"resource": "rampa_acesso", "include_summary": True},
        {"local_id": 1, "external_id": "osm:node:1", "resource": "rampa_acesso", "include_summary": True},
        {"local_id": 1, "resource": "unknown-resource", "include_summary": True},
        {"local_id": 1, "resource": "rampa_acesso", "include_summary": "invalid"},
    ]:
        assert client.get("/api/evidencias/", body).status_code == 400
