#!/usr/bin/env python3
"""Measure real Flutter Web map/suggestion milestones against a disposable Django/SQLite fixture."""

from __future__ import annotations

import argparse
from contextlib import ExitStack
import csv
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import sys
import tempfile
import time
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from socketserver import ThreadingMixIn
from threading import Thread
from urllib.parse import urlsplit
from wsgiref.simple_server import WSGIServer, WSGIRequestHandler, make_server


class ThreadedWSGI(ThreadingMixIn, WSGIServer):
    daemon_threads = True
    request_queue_size = 256


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chrome", type=Path, required=True)
    parser.add_argument("--rounds", type=int, default=3)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    if args.rounds < 1:
        parser.error("Use uma ou mais repetições por cenário; o p95 só é interpretável com amostra suficiente.")
    root = Path(__file__).resolve().parents[2]
    build = root / "frontend" / "build" / "web"
    report_dir = args.report.resolve()
    report_dir.mkdir(parents=True, exist_ok=False)
    sys.path.insert(0, str(root))

    with tempfile.TemporaryDirectory(prefix="acessoja-card127-ui-") as temporary:
        db_path = Path(temporary) / "synthetic.sqlite3"
        os.environ.update(
            {
                "DJANGO_SETTINGS_MODULE": "acessoja.settings",
                "SECRET_KEY": "card127-synthetic-ui-only",
                "DEBUG": "True",
                "ALLOWED_HOSTS": "127.0.0.1,localhost",
                "DATABASE_URL": "sqlite:///" + db_path.as_posix(),
                "CORS_ALLOWED_ORIGINS": "http://127.0.0.1:8002",
                "CSRF_TRUSTED_ORIGINS": "http://127.0.0.1:8002",
                "OVERPASS_URL": "http://127.0.0.1:8003/api/interpreter",
            }
        )
        import django

        django.setup()
        from django.core.management import call_command
        from django.core.wsgi import get_wsgi_application
        from django.db import connections
        from django.test import override_settings
        from locais.models import Local, VisitaRecente
        from usuarios.models import Usuario
        from playwright.sync_api import sync_playwright

        with override_settings(
            CORS_ALLOW_CREDENTIALS=True,
            PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"],
            PRIVATE_IMAGE_ROOT=Path(temporary) / "private",
        ):
            call_command("migrate", verbosity=0, interactive=False)
            owners = [
                Usuario.objects.create_user(
                    f"card127-owner-{i}",
                    "SyntheticOnly!127",
                    email=f"owner-{i}@example.invalid",
                    accessibility_preferences=["rampa_acesso", "banheiro_acessivel"],
                )
                for i in range(1, args.rounds + 1)
            ]
            places = []
            fixtures = [
                ("Card127 Zero", "saude", "", {}),
                ("Card127 Parcial", "saude", "clinica", {"rampa_acesso": {"state": "presence_reported"}}),
                (
                    "Card127 Principal",
                    "saude",
                    "hospital",
                    {
                        "rampa_acesso": {"state": "presence_reported"},
                        "banheiro_acessivel": {"state": "presence_reported"},
                    },
                ),
            ]
            fixtures.extend((f"Card127 sintético {i:02d}", "educacao", "", {}) for i in range(22))
            for index, (name, category, subcategory, accessibility) in enumerate(fixtures):
                places.append(
                    Local.objects.create(
                        nome=name,
                        endereco=f"Rua de teste {index:02d}",
                        distancia=float(index),
                        latitude=-16.3267 + (index % 10) * 0.0002,
                        longitude=-48.9528 + (index // 10) * 0.0002,
                        categoria=category,
                        subcategoria=subcategory,
                        accessibility_information=accessibility,
                    )
                )
            for owner in owners:
                for place in places[:3]:
                    VisitaRecente.objects.create(user=owner, local=place, arrival_confirmed=True)
            counts = {
                "locals": Local.objects.count(),
                "synthetic_visits": VisitaRecente.objects.filter(user__in=owners).count(),
                "synthetic_users": len(owners),
            }

            class Quiet(WSGIRequestHandler):
                def log_message(self, *values):
                    pass

            class Files(SimpleHTTPRequestHandler):
                def __init__(self, *values, **kwargs):
                    super().__init__(*values, directory=str(build), **kwargs)

                def log_message(self, *values):
                    pass

            class SyntheticOverpass(SimpleHTTPRequestHandler):
                def do_POST(self):
                    self.rfile.read(int(self.headers.get("Content-Length", "0")))
                    payload = b'{"version":0.6,"generator":"Card127 synthetic fixture","elements":[]}'
                    self.send_response(200)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Content-Length", str(len(payload)))
                    self.end_headers()
                    self.wfile.write(payload)

                def log_message(self, *values):
                    pass

            api = make_server("127.0.0.1", 8001, get_wsgi_application(), server_class=ThreadedWSGI, handler_class=Quiet)
            web = ThreadingHTTPServer(("127.0.0.1", 8002), Files)
            overpass = ThreadingHTTPServer(("127.0.0.1", 8003), SyntheticOverpass)
            for server in (api, web, overpass):
                Thread(target=server.serve_forever, daemon=True).start()

            result = {
                "started_at": datetime.now(timezone.utc).isoformat(),
                "sha": __import__("subprocess").check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
                "instrumentation_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                "build_sha256": hashlib.sha256((build / "main.dart.js").read_bytes()).hexdigest(),
                "platform": platform.platform(),
                "python": platform.python_version(),
                "flutter_sdk": "3.47.5 (project pin 3.47.4)",
                "browser_expected": "Chrome 157.0.8103.52",
                "viewport": {"width": 1280, "height": 900, "device_scale_factor": 1},
                "database": "disposable SQLite, synthetic records only",
                "seed_counts": counts,
                "cache": "fresh browser context per repetition; SQLite/OS cache state not controlled",
                "third_party_policy": (
                    "all browser hosts other than 127.0.0.1/localhost aborted; backend Overpass calls hit "
                    "a local synthetic endpoint returning zero elements"
                ),
                "rounds": [],
                "limitations": [
                    "Headless desktop Chrome, not Android or physical GPU.",
                    "No result-free suggestion state measured.",
                    "Map milestone is the real map-results selection list; canvas/GPU raster and tiles "
                    "are not measured.",
                ],
            }

            def save_result():
                (report_dir / "web.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")

            def network_since(requests, start_index):
                entries = [{k: v for k, v in x.items() if k != "start"} for x in list(requests.values())[start_index:]]
                failures = sum(1 for row in entries if row.get("status", 0) >= 400)
                return entries, failures

            with ExitStack() as stack:
                stack.callback(connections.close_all)
                stack.callback(web.server_close)
                stack.callback(web.shutdown)
                stack.callback(api.server_close)
                stack.callback(api.shutdown)
                playwright = stack.enter_context(sync_playwright())
                browser = playwright.chromium.launch(
                    executable_path=str(args.chrome), headless=True, args=["--no-sandbox", "--disable-dev-shm-usage"]
                )
                stack.callback(browser.close)
                result["browser_version"] = browser.version

                def new_page():
                    context = browser.new_context(
                        locale="pt-BR", viewport={"width": 1280, "height": 900}, device_scale_factor=1
                    )
                    context.set_default_timeout(20000)
                    context.add_init_script("localStorage.setItem('flutter.onboarding_completed','true')")
                    requests, external, errors = {}, [], []

                    def route(request_route):
                        host = urlsplit(request_route.request.url).hostname
                        if host in {"127.0.0.1", "localhost"}:
                            request_route.continue_()
                        else:
                            external.append(host or "unknown")
                            request_route.abort()

                    context.route("**/*", route)
                    page = context.new_page()
                    page.on("pageerror", lambda error: errors.append(type(error).__name__))

                    def on_request(request):
                        if urlsplit(request.url).path.startswith("/api/"):
                            requests[id(request)] = {
                                "path": urlsplit(request.url).path,
                                "method": request.method,
                                "start": time.perf_counter(),
                            }

                    page.on("request", on_request)

                    def on_response(response):
                        row = requests.get(id(response.request))
                        if row:
                            row.update(
                                {
                                    "status": response.status,
                                    "duration_ms": round((time.perf_counter() - row["start"]) * 1000, 3),
                                }
                            )

                    page.on("response", on_response)
                    return context, page, requests, external, errors

                def click(page, label, role="button"):
                    target = page.get_by_role(role, name=label, exact=True).first
                    try:
                        target.wait_for(state="visible")
                    except Exception:
                        page.screenshot(path=str(report_dir / "action-failure.png"))
                        print(
                            json.dumps(
                                {
                                    "missing_action": label,
                                    "semantics": page.locator("flt-semantics").all_text_contents()[:60],
                                },
                                ensure_ascii=False,
                            ),
                            flush=True,
                        )
                        raise
                    if not target.is_enabled():
                        raise RuntimeError(f"Ação indisponível: {label}")
                    target.click()

                def sign_in(page, owner_name):
                    page.goto("http://127.0.0.1:8002/", wait_until="domcontentloaded")
                    placeholder = page.locator("flt-semantics-placeholder")
                    placeholder.wait_for(state="attached", timeout=60000)
                    placeholder.evaluate("element => element.click()")
                    for label, value in (("Usuário", owner_name), ("Senha", "SyntheticOnly!127")):
                        field = page.locator(f'input[aria-label="{label}"]:not([disabled])')
                        field.wait_for(state="visible")
                        field.click()
                        page.keyboard.press("ControlOrMeta+A")
                        page.keyboard.type(value, delay=20)
                    click(page, "Entrar")
                    try:
                        page.get_by_role("tab", name="Avaliar", exact=True).wait_for(state="visible", timeout=60000)
                    except Exception:
                        page.screenshot(path=str(report_dir / "signin-failure.png"))
                        print(
                            json.dumps(
                                {
                                    "api": [{k: v for k, v in x.items() if k != "start"} for x in requests.values()],
                                    "semantics": page.locator("flt-semantics").all_text_contents()[:25],
                                },
                                ensure_ascii=False,
                            ),
                            flush=True,
                        )
                        raise

                def print_debug(label, page, requests, external, errors):
                    page.screenshot(path=str(report_dir / f"{label}-failure.png"), full_page=False)
                    details = {
                        "label": label,
                        "api": [{k: v for k, v in x.items() if k != "start"} for x in requests.values()],
                        "third_party_hosts": external,
                        "page_errors": errors,
                        "semantics": page.locator("flt-semantics").all_text_contents()[:35],
                    }
                    print(json.dumps(details, ensure_ascii=False), flush=True)

                for repetition in range(1, args.rounds + 1):
                    context, page, requests, external, errors = new_page()
                    sign_in(page, owners[repetition - 1].nome)
                    click(page, "Buscar destino ou calcular rota")
                    start = time.perf_counter()
                    row = page.get_by_role("button", name=re.compile("Card127 Principal")).last
                    row.wait_for(state="visible")
                    row.click()
                    page.get_by_role("button", name=re.compile("Card127 Principal")).first.wait_for(state="visible")
                    map_ms = round((time.perf_counter() - start) * 1000, 3)
                    result["rounds"].append(
                        {
                            "scenario": "mapa_lista_ate_local_selecionavel",
                            "repetition": repetition,
                            "duration_ms": map_ms,
                            "success": True,
                            "errors": 0,
                            "timeouts": 0,
                            "api_requests": len(requests),
                            "third_party_attempts": len(external),
                            "page_errors": errors,
                            "network": [{k: v for k, v in x.items() if k != "start"} for x in requests.values()],
                        }
                    )
                    save_result()
                    click(page, "Fechar resumo")

                    request_start = len(requests)
                    start = time.perf_counter()
                    click(page, "Sugestões", role="tab")
                    route_action = page.get_by_role(
                        "button", name=re.compile("Planejar rota para Card127 Principal")
                    ).first
                    route_action.wait_for(state="visible")
                    if not route_action.is_enabled():
                        raise RuntimeError("Primeira sugestão visível, mas ação de uso desabilitada")
                    suggestion_ms = round((time.perf_counter() - start) * 1000, 3)
                    suggestion_network, suggestion_errors = network_since(requests, request_start)
                    result["rounds"].append(
                        {
                            "scenario": "sugestoes_autenticado_ate_primeira_acao",
                            "repetition": repetition,
                            "duration_ms": suggestion_ms,
                            "success": True,
                            "errors": suggestion_errors,
                            "timeouts": 0,
                            "api_requests": len(suggestion_network),
                            "third_party_attempts": len(external),
                            "page_errors": errors,
                            "network": suggestion_network,
                        }
                    )
                    save_result()
                    context.close()

                    context, page, requests, external, errors = new_page()
                    page.goto("http://127.0.0.1:8002/", wait_until="domcontentloaded")
                    page.locator("flt-semantics-placeholder").wait_for(state="attached", timeout=60000)
                    page.locator("flt-semantics-placeholder").evaluate("element => element.click()")
                    click(page, "Explorar sem conta")
                    page.get_by_role("tab", name="Avaliar", exact=True).wait_for(state="visible", timeout=60000)
                    guest_request_start = len(requests)
                    start = time.perf_counter()
                    click(page, "Sugestões", role="tab")
                    guest_action = page.get_by_role(
                        "button", name=re.compile("Planejar rota para Card127 Principal")
                    ).first
                    guest_action.wait_for(state="visible", timeout=60000)
                    if not guest_action.is_enabled():
                        raise RuntimeError("Primeira sugestão visitante visível, mas ação desabilitada")
                    guest_ms = round((time.perf_counter() - start) * 1000, 3)
                    guest_network, guest_errors = network_since(requests, guest_request_start)
                    result["rounds"].append(
                        {
                            "scenario": "sugestoes_visitante_ate_primeira_acao",
                            "repetition": repetition,
                            "duration_ms": guest_ms,
                            "success": True,
                            "errors": guest_errors,
                            "timeouts": 0,
                            "api_requests": len(guest_network),
                            "third_party_attempts": len(external),
                            "page_errors": errors,
                            "network": guest_network,
                        }
                    )
                    context.close()
                    save_result()
                    print(f"Repetição {repetition}/{args.rounds}: mapa e Sugestões", flush=True)

            rows = []
            for record in result["rounds"]:
                rows.append(
                    {
                        "run_id": report_dir.name,
                        "sha": result["sha"],
                        "fase": "baseline",
                        "cenario": record["scenario"],
                        "rota_ou_marco": record["scenario"],
                        "cache": "fresh_browser_context",
                        "repeticao": record["repetition"],
                        "amostras": 1,
                        "sucessos": int(record["success"]),
                        "erros": record["errors"],
                        "timeouts": record["timeouts"],
                        "p50_ms": record["duration_ms"],
                        "p95_ms": None,
                        "vazao": None,
                        "vazao_unidade": None,
                        "concorrencia_observada": 1,
                        "payload_bytes_medio": None,
                        "limite_ms": 3000 if record["scenario"].startswith("mapa") else None,
                        "status": "EXPLORATORIO",
                        "evidencia": "web.json#rounds",
                    }
                )
            with (report_dir / "web.csv").open("w", newline="", encoding="utf-8-sig") as handle:
                fields = list(rows[0]) if rows else []
                writer = csv.DictWriter(handle, fieldnames=fields)
                writer.writeheader()
                writer.writerows(rows)
            result["finished_at"] = datetime.now(timezone.utc).isoformat()
            result["status"] = "executed"
            (report_dir / "web.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
