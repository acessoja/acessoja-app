from concurrent.futures import ThreadPoolExecutor
from threading import Barrier

import pytest
from django.contrib.auth import get_user_model
from django.db import close_old_connections, connection
from django.db.models import Sum
from rest_framework.test import APIClient

from locais.models import Local
from modal_avaliacao.models import ModalAvaliacao
from .models import PointActivity
from .services import impact, sync_evaluation

pytestmark = pytest.mark.django_db(transaction=True)


def setup_records(name):
    if connection.vendor != "postgresql":
        pytest.skip("Real row-lock concurrency requires PostgreSQL.")
    user = get_user_model().objects.create_user(nome=name, email=f"{name}@test.com", password="test-pass")
    place = Local.objects.create(nome="Biblioteca", endereco="Centro", distancia=0)
    review = ModalAvaliacao.objects.create(user=user, local=place, estrelas=4, verified_author=True)
    return user, review


def test_postgresql_concurrent_survey_completion_awards_once():
    user, review = setup_records("survey-concurrent")
    barrier = Barrier(2)

    def worker():
        close_old_connections()
        client = APIClient()
        client.force_authenticate(get_user_model().objects.get(pk=user.pk))
        barrier.wait(timeout=10)
        try:
            return client.patch(
                f"/api/avaliacoes/modal-avaliacoes/{review.pk}/",
                {f"pergunta_{i}": "Não sei" for i in range(1, 5)},
                format="json",
            )
        finally:
            close_old_connections()

    with ThreadPoolExecutor(max_workers=2) as pool:
        responses = list(pool.map(lambda _: worker(), range(2)))
    assert [response.status_code for response in responses] == [200, 200]
    assert sorted(response.data["points_delta"] for response in responses) == [0, 5]
    assert impact(user)["points"] == 15
    assert PointActivity.objects.count() == 2


def test_postgresql_concurrent_stale_signal_and_deletion_keep_zero_balance():
    user, review = setup_records("deletion-concurrent")
    barrier = Barrier(2)

    def worker(delete):
        close_old_connections()
        snapshot = ModalAvaliacao.objects.get(pk=review.pk)
        barrier.wait(timeout=10)
        try:
            if delete:
                snapshot.delete()
            else:
                sync_evaluation(snapshot)
        finally:
            close_old_connections()

    with ThreadPoolExecutor(max_workers=2) as pool:
        list(pool.map(worker, [False, True]))
    assert not ModalAvaliacao.objects.filter(pk=review.pk).exists()
    assert impact(user)["points"] == 0
    assert PointActivity.objects.aggregate(total=Sum("delta"))["total"] == 0


def test_postgresql_concurrent_summary_reads_keep_counts_and_points_consistent():
    user, review = setup_records("summary-concurrent")
    barrier = Barrier(2)

    def reader():
        close_old_connections()
        barrier.wait(timeout=10)
        try:
            for _ in range(15):
                value = impact(user)
                assert value["points"] == value["reviews"] * 10
                assert value["contributions_count"] == value["reviews"]
        finally:
            close_old_connections()

    def writer():
        close_old_connections()
        barrier.wait(timeout=10)
        try:
            for _ in range(5):
                current = ModalAvaliacao.objects.get(pk=review.pk)
                current.is_valid = False
                current.save(update_fields=["is_valid"])
                current.is_valid = True
                current.save(update_fields=["is_valid"])
        finally:
            close_old_connections()

    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(reader), pool.submit(writer)]
        for future in futures:
            future.result(timeout=30)
