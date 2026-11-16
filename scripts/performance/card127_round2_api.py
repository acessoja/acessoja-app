"""Run focused Card 127 API routes against synthetic, disposable SQLite."""

from __future__ import annotations

import argparse
import concurrent.futures
import csv
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import platform
import random
import statistics
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from socketserver import ThreadingMixIn
from wsgiref.simple_server import WSGIServer, WSGIRequestHandler, make_server

from card127_round2_support import RequestLifecycleProbe, bind_error


class ThreadedWSGI(ThreadingMixIn, WSGIServer):
    daemon_threads = True
    request_queue_size = 256


class QuietHandler(WSGIRequestHandler):
    def log_message(self, *_args):
        pass


def percentile(values: list[float], p: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    point = (len(ordered) - 1) * p
    low, high = int(point), min(int(point) + 1, len(ordered) - 1)
    return round(ordered[low] + (ordered[high] - ordered[low]) * (point - low), 3)


def _request(url: str, token: str, timeout: float = 15) -> dict:
    started = time.perf_counter()
    req = urllib.request.Request(
        url,
        headers={"Accept": "application/json", "Authorization": f"Token {token}",
                 "User-Agent": "AcessoJa-Card127-Rodada2/1.0"},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            body = response.read()
            status = response.status
        outcome = "success" if 200 <= status < 300 else "http_error"
    except urllib.error.HTTPError as error:
        body, status, outcome = error.read(), error.code, "http_error"
    except (TimeoutError, OSError) as error:
        body, status, outcome = b"", None, "transport_error"
        error_type = type(error).__name__
    else:
        error_type = None
    duration = (time.perf_counter() - started) * 1000
    try:
        json.loads(body)
        payload_valid = True
    except (json.JSONDecodeError, UnicodeDecodeError):
        payload_valid = False
    if outcome == "success" and not payload_valid:
        outcome = "invalid_json"
    return {"duration_ms": round(duration, 3), "status": status,
            "response_bytes": len(body), "outcome": outcome,
            "error_type": error_type, "payload_valid": payload_valid}


def _measure(path: str, token: str, *, samples: int, concurrency: int, origin: str,
             probe: RequestLifecycleProbe, timeout: float = 15) -> dict:
    barrier = threading.Barrier(concurrency) if concurrency > 1 else None
    active = maximum = 0
    lock = threading.Lock()

    def one(_index):
        nonlocal active, maximum
        if barrier:
            try:
                barrier.wait(timeout=timeout)
            except threading.BrokenBarrierError:
                return {"duration_ms": 0, "status": None, "response_bytes": 0,
                        "outcome": "barrier_timeout", "payload_valid": False}
        with lock:
            active += 1
            maximum = max(maximum, active)
        try:
            return _request(origin + path, token, timeout)
        finally:
            with lock:
                active -= 1

    probe.reset()
    started = time.perf_counter()
    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as pool:
        outcomes = list(pool.map(one, range(samples)))
    if not probe.wait_idle(timeout):
        raise RuntimeError("WSGI response iterables did not close before the benchmark batch ended")
    elapsed = time.perf_counter() - started
    records = probe.snapshot()
    latencies = [row["duration_ms"] for row in outcomes]
    successes = sum(row["outcome"] == "success" for row in outcomes)
    statuses = {}
    for row in outcomes:
        key = str(row["status"]) if row["status"] is not None else "transport_error"
        statuses[key] = statuses.get(key, 0) + 1
    query_counts = [row.sql_queries for row in records if row.sql_queries is not None]
    return {
        "samples": samples, "successes": successes, "errors": samples - successes,
        "timeouts": sum(row["outcome"] in {"transport_error", "barrier_timeout"} for row in outcomes),
        "status_counts": statuses, "failure_kinds": {
            kind: sum(row["outcome"] == kind for row in outcomes)
            for kind in sorted({row["outcome"] for row in outcomes if row["outcome"] != "success"})
        },
        "p50_ms": percentile(latencies, .50), "p95_ms": percentile(latencies, .95),
        "throughput_rps": round(samples / elapsed, 3) if elapsed > 0 else None,
        "response_bytes_mean": round(statistics.mean(row["response_bytes"] for row in outcomes), 1),
        "client_max_in_flight": maximum, "server_max_in_flight": probe.maximum,
        "sql_queries_per_request_mean": round(statistics.mean(query_counts), 2) if query_counts else None,
        "sql_queries_per_request_max": max(query_counts, default=None),
        "server_requests_completed": len(records), "elapsed_s": round(elapsed, 3),
        "effective_concurrency": probe.maximum,
    }


def run(report_dir: Path, *, repetitions: int = 3, route_samples: int = 25,
        concurrency_samples: int = 100, seed: int = 127, timeout: float = 15) -> dict:
    report_dir.mkdir(parents=True, exist_ok=True)
    root = Path(__file__).resolve().parents[2]
    sys.path.insert(0, str(root))
    run_id = report_dir.name
    with tempfile.TemporaryDirectory(prefix="acessoja-card127-r2-api-") as temporary:
        db_path = Path(temporary) / "synthetic.sqlite3"
        os.environ.update({
            "DJANGO_SETTINGS_MODULE": "acessoja.settings",
            "SECRET_KEY": "card127-round2-disposable-only",
            "DEBUG": "True", "ALLOWED_HOSTS": "127.0.0.1,localhost",
            "DATABASE_URL": "sqlite:///" + db_path.as_posix(),
            "OVERPASS_URL": "http://127.0.0.1:9/disabled-card127",
        })
        import django
        django.setup()
        from django.core.management import call_command
        from django.core.wsgi import get_wsgi_application
        from django.db import connection, connections
        from django.contrib.auth import get_user_model
        from rest_framework.authtoken.models import Token
        from locais.models import Local, VisitaRecente
        from favoritos.models import Favorito

        call_command("migrate", verbosity=0, interactive=False)
        rng = random.Random(seed)
        places = [Local(
            nome=f"Card127 sintético {i:04d}", endereco=f"Rua de teste {i:04d}",
            distancia=float(i % 25), latitude=-16.3267 + rng.random() * .01,
            longitude=-48.9528 + rng.random() * .01, categoria="cafeteria",
            subcategoria="cafeteria", accessibility_information={
                "rampa_acesso": {"state": "presence_reported"} if i % 2 else {},
            },
        ) for i in range(200)]
        Local.objects.bulk_create(places, batch_size=200)
        first_place = Local.objects.order_by("pk").first()
        User = get_user_model()
        owner = User.objects.create_user(
            "card127-api-owner", "SyntheticOnly!127", email="api-owner@example.invalid",
            accessibility_preferences=["rampa_acesso"],
        )
        token = Token.objects.create(user=owner).key
        VisitaRecente.objects.create(user=owner, local=first_place, arrival_confirmed=True)
        Favorito.objects.create(user=owner, local=first_place)

        def sql_count():
            return len(connection.queries)

        probe = RequestLifecycleProbe(get_wsgi_application(), query_count=sql_count,
                                      on_finish=connections.close_all)
        try:
            server = make_server("127.0.0.1", 0, probe, server_class=ThreadedWSGI,
                                 handler_class=QuietHandler)
        except OSError as error:
            raise bind_error("API local de rodada 2", "127.0.0.1", 0, error) from error
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        origin = f"http://127.0.0.1:{server.server_port}"
        place_id = first_place.pk
        query = urllib.parse.urlencode({
            "paginated": "true", "page_size": "20", "page": "1",
            "search": "Card127", "categorias": "cafeteria",
        })
        page2 = urllib.parse.urlencode({
            "paginated": "true", "page_size": "20", "page": "2",
            "search": "Card127", "categorias": "cafeteria",
        })
        scenarios = [
            ("locals_filtered_page_1", f"/api/locais/?{query}", "authenticated"),
            ("locals_filtered_page_2", f"/api/locais/?{page2}", "authenticated"),
            ("local_detail", f"/api/locais/{place_id}/", "authenticated"),
            ("public_evaluations_by_local", f"/api/avaliacoes/modal-avaliacoes/?local_id={place_id}", "authenticated"),
            ("favorites_list", "/api/favoritos/?page_size=20", "authenticated"),
            ("favorites_map_layer", f"/api/favoritos/listas/camada/?locais={place_id}", "authenticated"),
            ("favorite_states", f"/api/favoritos/estados/?locais={place_id}", "authenticated"),
            ("auth_profile", "/api/usuarios/me/", "authenticated"),
            ("recent_visits", "/api/visitas/", "authenticated"),
            ("accessibility_preferences", "/api/usuarios/me/accessibility-preferences/", "authenticated"),
        ]
        results, csv_rows = [], []
        try:
            # Gradual load is applied only to the synthetic public list route.
            levels = [level for level in (1, 10, 25, 50, 100)
                      if level <= concurrency_samples]
            for repetition in range(1, repetitions + 1):
                for concurrency in levels:
                    measurement = _measure(
                        f"/api/locais/?{query}", token, samples=concurrency_samples,
                        concurrency=concurrency, origin=origin, probe=probe, timeout=timeout,
                    )
                    record = {
                        "scenario": "locals_filtered_page_1_load",
                        "endpoint": "/api/locais/", "profile": "authenticated",
                        "concurrency_requested": concurrency, "repetition": repetition,
                        **measurement,
                    }
                    results.append(record)
                    csv_rows.append(_csv_row(run_id, record))
                for scenario_name, path, profile in scenarios:
                    measurement = _measure(
                        path, token, samples=route_samples, concurrency=1,
                        origin=origin, probe=probe, timeout=timeout,
                    )
                    record = {
                        "scenario": scenario_name, "endpoint": path.split("?", 1)[0],
                        "profile": profile, "concurrency_requested": 1,
                        "repetition": repetition, **measurement,
                    }
                    results.append(record)
                    csv_rows.append(_csv_row(run_id, record))
            data = {
                "run_id": run_id,
                "started_at": datetime.now(timezone.utc).isoformat(),
                "sha": __import__("subprocess").check_output(
                    ["git", "rev-parse", "HEAD"], cwd=root, text=True
                ).strip(),
                "instrumentation": "RequestLifecycleProbe records through WSGI response iterable close; HTTP client reads complete bodies.",
                "platform": platform.platform(), "python": platform.python_version(),
                "django": django.get_version(),
                "drf": __import__("rest_framework").VERSION,
                "database": "disposable SQLite; synthetic-only; no authorized PostgreSQL configuration",
                "network": "loopback only", "seed": seed,
                "dataset": {"locals": Local.objects.count(), "users": 1, "visits": VisitaRecente.objects.count(),
                            "favorites": Favorito.objects.count(), "reviews": 0},
                "samples": {"per_route_per_repetition": route_samples,
                            "concurrency_route_samples_per_repetition": concurrency_samples,
                            "repetitions": repetitions, "concurrency_levels": levels},
                "run_mode": "full" if concurrency_samples >= 100 else "smoke",
                "scenarios": results,
                "limitations": [
                    "SQLite is diagnostic only and cannot establish PostgreSQL performance.",
                    "Review collection is empty and only its public GET list is measured; no mutations are benchmarked.",
                    "Token exists only in process memory and is absent from result files/logs.",
                ],
                "finished_at": datetime.now(timezone.utc).isoformat(),
            }
            (report_dir / "api.json").write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
            with (report_dir / "api.csv").open("w", newline="", encoding="utf-8-sig") as handle:
                writer = csv.DictWriter(handle, fieldnames=list(csv_rows[0]) if csv_rows else [])
                writer.writeheader()
                writer.writerows(csv_rows)
            return data
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=5)
            connections.close_all()


def _csv_row(run_id: str, result: dict) -> dict:
    return {
        "run_id": run_id, "scenario": result["scenario"], "profile": result["profile"],
        "endpoint": result["endpoint"], "repetition": result["repetition"],
        "samples": result["samples"], "successes": result["successes"],
        "errors": result["errors"], "timeouts": result["timeouts"],
        "p50_ms": result["p50_ms"], "p95_ms": result["p95_ms"],
        "throughput_rps": result["throughput_rps"],
        "client_max_in_flight": result["client_max_in_flight"],
        "server_max_in_flight": result["server_max_in_flight"],
        "response_bytes_mean": result["response_bytes_mean"],
        "sql_queries_per_request_mean": result["sql_queries_per_request_mean"],
        "status_counts_json": json.dumps(result["status_counts"], sort_keys=True),
        "evidence": "api.json#scenarios",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--repetitions", type=int, default=3)
    parser.add_argument("--route-samples", type=int, default=25)
    parser.add_argument("--concurrency-samples", type=int, default=100)
    parser.add_argument("--seed", type=int, default=127)
    parser.add_argument("--timeout", type=float, default=15)
    args = parser.parse_args()
    if min(args.repetitions, args.route_samples, args.concurrency_samples) < 1 or args.timeout <= 0:
        parser.error("repetitions, amostras e timeout devem ser positivos")
    result = run(args.report.resolve(), repetitions=args.repetitions,
                 route_samples=args.route_samples,
                 concurrency_samples=args.concurrency_samples,
                 seed=args.seed, timeout=args.timeout)
    print(f"API Card 127: {len(result['scenarios'])} cenários — {args.report.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
