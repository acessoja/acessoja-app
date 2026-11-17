#!/usr/bin/env python3
"""Run the API benchmark against a disposable, seeded SQLite + threaded WSGI lab."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import tempfile
import threading
import random
import sys
from socketserver import ThreadingMixIn
from wsgiref.simple_server import WSGIServer, WSGIRequestHandler, make_server
from card127_round2_support import RequestLifecycleProbe


class ThreadedWSGIServer(ThreadingMixIn, WSGIServer):
    daemon_threads = True
    request_queue_size = 256


class QuietHandler(WSGIRequestHandler):
    def log_message(self, format, *args):
        pass


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--samples", type=int, default=100)
    parser.add_argument("--repetitions", type=int, default=3)
    parser.add_argument("--warmup", type=int, default=10)
    parser.add_argument("--locals", type=int, default=500)
    parser.add_argument("--seed", type=int, default=127)
    parser.add_argument("--port", type=int, default=0, help="0 chooses an unused loopback port")
    parser.add_argument("--timeout", type=float, default=10)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.locals < 20 or args.samples < 100 or args.repetitions < 1 or args.warmup < 0:
        parser.error("Use no mínimo 20 locais e 100 amostras para manter a prova simultânea de 100.")

    root = Path(__file__).resolve().parents[2]
    sys.path.insert(0, str(root))
    with tempfile.TemporaryDirectory(prefix="acessoja-card127-") as temporary:
        db_path = Path(temporary) / "synthetic.sqlite3"
        os.environ.update({
            "DJANGO_SETTINGS_MODULE": "acessoja.settings",
            "SECRET_KEY": "card127-disposable-lab-only",
            "DEBUG": "True",
            "ALLOWED_HOSTS": "127.0.0.1,localhost",
            "DATABASE_URL": "sqlite:///" + db_path.as_posix(),
            "OVERPASS_URL": "http://127.0.0.1:9/disabled-card127",
            "CORS_ALLOWED_ORIGINS": "http://127.0.0.1",
        })
        import django
        django.setup()
        from django.core.management import call_command
        from django.core.wsgi import get_wsgi_application
        from django.db import connections
        from locais.models import Local

        call_command("migrate", verbosity=0, interactive=False)
        rng = random.Random(args.seed)
        rows = [Local(
            nome=f"Card127 sintético {i:05d}", endereco=f"Rua de teste {i:05d}",
            distancia=float(i % 25), latitude=-16.3267 + rng.random() * .01,
            longitude=-48.9528 + rng.random() * .01, categoria="cafeteria", subcategoria="",
            accessibility_information={},
        ) for i in range(args.locals)]
        Local.objects.bulk_create(rows, batch_size=200)
        actual_count = Local.objects.filter(nome__startswith="Card127 sintético ").count()
        if actual_count != args.locals:
            raise RuntimeError(f"Seed incompleto: esperado={args.locals}, efetivo={actual_count}")

        from django.db import connection

        probe = RequestLifecycleProbe(
            get_wsgi_application(),
            query_count=lambda: len(connection.queries),
        )
        server = make_server("127.0.0.1", args.port, probe, server_class=ThreadedWSGIServer,
                             handler_class=QuietHandler)
        server_thread = threading.Thread(target=server.serve_forever, daemon=True)
        server_thread.start()
        try:
            from card127 import write_run
            from argparse import Namespace
            metadata = Namespace(
                base_url=f"http://127.0.0.1:{server.server_port}", authorized_host=None,
                run_id=None, output=args.output, database="SQLite descartável (diagnóstico)",
                server_workers="ThreadingMixIn (one handler thread per request)", seed=args.seed,
                entity_counts={"locais": actual_count, "visitas": 0, "usuarios": 0},
                samples=args.samples, repetitions=args.repetitions, warmup=args.warmup,
                concurrency=[1, 10, 100], timeout=args.timeout, error_budget_pct=1,
                server_concurrency_probe=lambda: probe.maximum,
                server_concurrency_reset=probe.reset_maximum,
                server_query_metrics=probe.query_metrics,
            )
            write_run(metadata)
        finally:
            server.shutdown()
            server.server_close()
            server_thread.join(timeout=5)
            connections.close_all()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
