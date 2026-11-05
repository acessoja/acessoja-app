import pytest
from rest_framework.test import APIClient

from usuarios.models import Usuario


pytestmark = pytest.mark.django_db


def test_username_availability_distinguishes_format_and_occupancy():
    Usuario.objects.create_user("already.taken", email="taken@example.test", password="Maple clouds!8294")
    client = APIClient()

    available = client.get("/auth/username-availability/?nome=new.public-name")
    occupied = client.get("/auth/username-availability/?nome=already.taken")
    invalid = client.get("/auth/username-availability/?nome=ad")

    assert available.status_code == 200
    assert available.json()["available"] is True
    assert occupied.status_code == 200
    assert occupied.json()["available"] is False
    assert invalid.status_code == 400
    assert "nome" in invalid.json()
