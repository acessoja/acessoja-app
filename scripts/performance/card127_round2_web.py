"""Build and exercise instrumented Flutter Web on isolated loopback services."""

from __future__ import annotations

import argparse
from collections import Counter
from contextlib import ExitStack
import csv
from datetime import datetime, timezone
import hashlib
import importlib.metadata
import json
import math
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from xml.sax.saxutils import escape
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from socketserver import ThreadingMixIn
from threading import Thread
from urllib.parse import urlsplit
from wsgiref.simple_server import WSGIServer, WSGIRequestHandler, make_server

from card127_round2_support import (
    RequestLifecycleProbe, ScenarioState, bind_error, classify_http_outcome,
)


class ThreadedWSGI(ThreadingMixIn, WSGIServer):
    daemon_threads = True
    request_queue_size = 256


class QuietWSGI(WSGIRequestHandler):
    def log_message(self, *_args):
        pass


class QuietHTTP(SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass


class SyntheticOverpass(QuietHTTP):
    def do_POST(self):
        self.rfile.read(int(self.headers.get("Content-Length", "0")))
        payload = b'{"version":0.6,"generator":"Card127 synthetic fixture","elements":[]}'
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)


def _cors_headers(environ: dict, web_origin: str) -> list[tuple[str, str]]:
    origin = environ.get("HTTP_ORIGIN")
    headers = [("Content-Type", "application/json"), ("Cache-Control", "no-store")]
    if origin == web_origin:
        headers.extend([
            ("Access-Control-Allow-Origin", origin),
            ("Access-Control-Allow-Credentials", "true"),
            ("Vary", "Origin"),
        ])
    return headers


class SyntheticScenarioMiddleware:
    """Injects local-only latency/status/empty data on the synthetic discovery route."""

    def __init__(self, app, state: ScenarioState, web_origin: str):
        self.app, self.state, self.web_origin = app, state, web_origin

    def __call__(self, environ, start_response):
        name, delay_ms, forced_status, empty_results = self.state.get()
        is_discovery = (
            environ.get("REQUEST_METHOD") == "GET"
            and environ.get("PATH_INFO") == "/api/locais/"
        )
        if is_discovery and delay_ms:
            time.sleep(delay_ms / 1000)
        if is_discovery and forced_status:
            payload = json.dumps({"detail": "synthetic benchmark failure"}).encode()
            headers = _cors_headers(environ, self.web_origin)
            headers.append(("Content-Length", str(len(payload))))
            start_response(f"{forced_status} Synthetic Benchmark Failure", headers)
            return [payload]
        if is_discovery and empty_results:
            payload = b'{"count":0,"next":null,"previous":null,"results":[]}'
            headers = _cors_headers(environ, self.web_origin)
            headers.append(("Content-Length", str(len(payload))))
            start_response("200 OK", headers)
            return [payload]
        return self.app(environ, start_response)


def _new_http_server(factory, label: str, port: int):
    try:
        return factory(port)
    except OSError as error:
        raise bind_error(label, "127.0.0.1", port, error) from error


def _marker_records(page) -> list[dict]:
    return page.evaluate("() => Array.isArray(window.__card127Marks) ? window.__card127Marks : []")


def _wait_marker(page, name: str, *, after_count: int = 0, timeout_ms: int = 60000):
    page.wait_for_function(
        "({name, after}) => Array.isArray(window.__card127Marks) && "
        "window.__card127Marks.filter((item) => item.name === name).length > after",
        arg={"name": name, "after": after_count}, timeout=timeout_ms,
    )
    return [row for row in _marker_records(page) if row.get("name") == name][after_count]


def _usable_map_marker(page, timeout_ms: int) -> dict:
    """Return a visible, in-viewport, hit-testable Flutter semantics marker."""
    target = page.get_by_role("button", name=re.compile(r"Card127 Principal"))
    cluster = page.get_by_role("button", name=re.compile(r"locais\. Abrir agrupamento"))
    candidates = [target.nth(i) for i in range(target.count())]
    candidates.extend(cluster.nth(i) for i in range(cluster.count()))
    for candidate in candidates:
        if not candidate.is_visible() or not candidate.is_enabled():
            continue
        box = candidate.bounding_box()
        if not box:
            continue
        inside = page.evaluate(
            "box => box.x >= 0 && box.y >= 0 && box.x + box.width <= innerWidth "
            "&& box.y + box.height <= innerHeight", box,
        )
        if not inside:
            continue
        candidate.click(trial=True, timeout=timeout_ms)
        name = candidate.get_attribute("aria-label") or candidate.inner_text()
        return {
            "accessible_name": (name or "").strip()[:180], "role": "button",
            "marker_kind": "place" if "Card127 Principal" in (name or "") else "cluster",
            "enabled": True, "hit_testable": True, "in_viewport": True,
            "bounds_px": {key: round(value, 2) for key, value in box.items()},
        }
    raise RuntimeError("no_visible_hit_testable_marker")


def _safe_failure_diagnostics(page, page_state: dict, phase: str, error: Exception) -> dict:
    message = str(error).replace("SyntheticOnly!127", "[redacted]")[:300]
    auth_requests = [
        {key: row.get(key) for key in ("method", "path", "status", "outcome", "body_complete_ms")}
        for row in page_state.get("requests", []) if row.get("path", "").startswith("/auth/")
    ]
    probe = page_state.get("probe")
    probe_records = [row for row in (probe.snapshot() if probe else [])
                     if row.sequence >= page_state.get("probe_start", 0)]
    login_sequences = [row.sequence for row in probe_records
                       if row.method == "POST" and row.path == "/auth/session/login/"]
    first_login_sequence = min(login_sequences) if login_sequences else None
    server_requests = [
        {"method": row.method, "path": row.path, "status": row.status,
         "duration_ms": row.duration_ms, "response_bytes": row.response_bytes,
         "outcome": classify_http_outcome(
             row.path, row.status,
             "visitor_bootstrap" if row.path == "/api/usuarios/me/" and row.status == 401
             and (first_login_sequence is None or row.sequence < first_login_sequence) else phase,
         ) if row.duration_ms is not None else "in_flight"}
        for row in probe_records
    ]
    server_pending = [row for row in (probe.pending_snapshot(page_state.get("probe_start", 0)) if probe else [])
                      if row.path.startswith(("/api/", "/auth/"))]
    return {
        "phase": phase, "error_type": type(error).__name__, "error_message": message,
        "auth_requests": auth_requests,
        "api_requests": [
            {key: row.get(key) for key in ("method", "path", "status", "outcome", "body_complete_ms")}
            for row in page_state.get("requests", [])
        ],
        "server_requests": server_requests,
        "server_pending_requests": [{"method": row.method, "path": row.path, "outcome": "in_flight"}
                                     for row in server_pending],
        "request_event_counts": dict(page_state.get("event_counts", {})),
        "login_form_state": page_state.get("login_form_state"),
        "ui_events": page.evaluate("() => (window.__card127UiEvents || []).slice(-30)"),
        "login_tab_count": page.get_by_role("tab", name="Avaliar", exact=True).count(),
    }


def _write_round3_artifacts(report_dir: Path, result: dict, flutter: str) -> None:
    """Write a new, bounded CSV/JSON evidence package without touching older runs."""
    run_id = report_dir.name
    rows = []
    metrics = (
        ("bootstrap_to_first_frame_ms", "bootstrap_to_first_frame"),
        ("duration_to_interaction_ms", "suggestions_harness_start_to_route_action"),
        ("screen_to_first_card_ms", "suggestions_screen_to_first_card"),
        ("screen_to_route_action_ms", "suggestions_screen_to_route_action"),
        ("first_marker_usable_ms_from_app_ready", "map_main_screen_to_marker"),
        ("first_marker_usable_ms_from_map_ready", "map_ready_to_marker"),
        ("first_results_list_usable_ms", "map_results_list_usable"),
        ("local_selection_ms", "map_local_selection_to_preview"),
        ("detail_ready_ms", "map_local_detail_ready"),
    )
    for scenario in result.get("scenarios", []):
        common = {
            "run_id": run_id, "sha": result.get("sha"), "scenario": scenario.get("scenario"),
            "profile": scenario.get("profile"), "repetition": scenario.get("repetition"),
        }
        for key, milestone in metrics:
            value = scenario.get(key)
            if value is not None:
                rows.append({**common, "milestone": milestone, "value": value, "unit": "ms",
                             "status": "measured", "error_type": None, "phase": None,
                             "method": None, "path": None, "http_status": None,
                             "response_bytes": None, "in_flight_count": 0})
        for stage in ("api", "list_api", "selection_api"):
            snapshot = scenario.get(stage) or {}
            for request in snapshot.get("requests", []):
                rows.append({**common, "milestone": "api_full_response", "value": request.get("full_response_ms"),
                             "unit": "ms", "status": request.get("outcome"), "error_type": None,
                             "phase": snapshot.get("phase"), "method": request.get("method"),
                             "path": request.get("path"), "http_status": request.get("status"),
                             "response_bytes": request.get("response_bytes"),
                             "in_flight_count": snapshot.get("in_flight_count")})
        auth = scenario.get("authentication")
        if auth:
            rows.append({**common, "milestone": "authenticated_login", "value": auth.get("login_http_status"),
                         "unit": "http_status", "status": "authenticated" if auth.get("main_screen_tab_visible") else "failed",
                         "error_type": None, "phase": "login", "method": "POST",
                         "path": "/auth/session/login/", "http_status": auth.get("login_http_status"),
                         "response_bytes": None, "in_flight_count": 0})
    for failure in result.get("scenario_failures", []):
        rows.append({"run_id": run_id, "sha": result.get("sha"), "scenario": failure.get("scenario"),
                     "profile": failure.get("profile"), "repetition": failure.get("repetition"),
                     "milestone": "not_measured", "value": None, "unit": None,
                     "status": "failed", "error_type": failure.get("error_type"),
                     "phase": failure.get("phase"), "method": None, "path": None,
                     "http_status": None, "response_bytes": None,
                     "in_flight_count": len(failure.get("server_pending_requests", []))})
    fields = ["run_id", "sha", "scenario", "profile", "repetition", "milestone", "value", "unit",
              "status", "error_type", "phase", "method", "path", "http_status", "response_bytes",
              "in_flight_count"]
    with (report_dir / "resultados.csv").open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)

    grouped: dict[tuple[str, str, str], list[float]] = {}
    for row in rows:
        if row.get("unit") == "ms" and isinstance(row.get("value"), (int, float)):
            grouped.setdefault((row["scenario"], row["profile"], row["milestone"]), []).append(row["value"])
    aggregates = []
    for (scenario, profile, milestone), values in sorted(grouped.items()):
        ordered = sorted(values)
        aggregates.append({"scenario": scenario, "profile": profile, "milestone": milestone,
                           "n": len(values), "p50_ms": round(float(__import__("statistics").median(values)), 3),
                           "p95_ms": round(float(ordered[max(0, math.ceil(.95 * len(ordered)) - 1)]), 3)})
    summary = {
        "run_id": run_id, "status": result.get("status"),
        "measurement_semantics": result.get("measurement_semantics"),
        "web_observations": len(result.get("scenarios", [])),
        "web_failures": result.get("scenario_failures", []),
        "metric_aggregates": aggregates,
        "marker_observations": [
            {"scenario": row.get("scenario"), "repetition": row.get("repetition"),
             "observed": row.get("first_marker_usable") is not None,
             "kind": (row.get("first_marker_usable") or {}).get("marker_kind"),
             "in_viewport": (row.get("first_marker_usable") or {}).get("in_viewport"),
             "hit_testable": (row.get("first_marker_usable") or {}).get("hit_testable")}
            for row in result.get("scenarios", []) if row.get("scenario") == "production_map_flow"
        ],
        "authentication_observations": [
            {"scenario": row.get("scenario"), "repetition": row.get("repetition"),
             **row["authentication"]}
            for row in result.get("scenarios", []) if row.get("authentication")
        ],
        "postgresql": "BLOQUEADO — nenhum DATABASE_URL autorizado; serviço detectado sem conexão.",
        "android": "FORA DO ESCOPO conforme prompt Rodada 3.",
        "comparison_policy": "Não comparar diretamente com Rodadas 1/2; protocolo/fixture e instrumentação diferem.",
        "historical_runs_preserved": True,
    }
    (report_dir / "resumo.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    chart_rows = [row for row in aggregates if row["milestone"] != "api_full_response"]
    max_value = max((row["p95_ms"] for row in chart_rows), default=1)
    width, label_width, chart_width = 900, 285, 500
    height = 90 + len(chart_rows) * 42
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
           '<style>text{font:12px Arial,sans-serif;fill:#222}.title{font-size:17px;font-weight:bold}</style>',
           '<text class="title" x="12" y="24">Card 127 — Rodada 3 (p50 / p95, ms)</text>',
           '<rect x="650" y="40" width="12" height="12" fill="#377eb8"/><text x="668" y="51">p50</text>',
           '<rect x="720" y="40" width="12" height="12" fill="#e41a1c"/><text x="738" y="51">p95</text>']
    for index, row in enumerate(chart_rows):
        y = 78 + index * 42
        label = escape(f"{row['scenario']} · {row['milestone']}")
        p50_width = row["p50_ms"] / max_value * chart_width
        p95_width = row["p95_ms"] / max_value * chart_width
        svg.extend([
            f'<text x="12" y="{y + 12}">{label}</text>',
            f'<rect x="{label_width}" y="{y}" width="{p50_width:.2f}" height="12" fill="#377eb8"/>',
            f'<rect x="{label_width}" y="{y + 16}" width="{p95_width:.2f}" height="12" fill="#e41a1c"/>',
            f'<text x="{label_width + p95_width + 6:.2f}" y="{y + 27}">{row["p95_ms"]:.1f}</text>',
        ])
    svg.append("</svg>")
    (report_dir / "p95.svg").write_text("\n".join(svg), encoding="utf-8")
    try:
        flutter_exe = shutil.which(flutter) or flutter
        version = subprocess.run([flutter_exe, "--version", "--machine"], text=True, capture_output=True,
                                 timeout=30, shell=os.name == "nt", check=False)
        flutter_meta = json.loads(version.stdout) if version.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError):
        flutter_meta = None
    try:
        playwright_version = importlib.metadata.version("playwright")
    except importlib.metadata.PackageNotFoundError:
        playwright_version = None
    environment = {
        "run_id": run_id, "collected_at_utc": result.get("finished_at"), "sha": result.get("sha"),
        "branch": subprocess.check_output(["git", "branch", "--show-current"], text=True).strip(),
        "platform": result.get("platform"), "python": result.get("python"),
        "flutter": flutter_meta, "playwright_python": playwright_version,
        "chrome": result.get("browser_version"), "viewport": result.get("viewport"),
        "cache_policy": result.get("cache"), "database": result.get("database"),
        "fixtures": result.get("seed_counts"), "network_policy": result.get("network_policy"),
        "repetitions": sorted({row.get("repetition") for row in result.get("scenarios", [])}),
        "scenario_filter": sorted({row.get("scenario") for row in result.get("scenarios", [])}),
        "warmup": "none; cold browser context per observation",
        "android": "not run and out of scope",
        "parameters": result.get("parameters"),
    }
    (report_dir / "ambiente.json").write_text(json.dumps(environment, ensure_ascii=False, indent=2), encoding="utf-8")
    (report_dir / "logs_sanitizados.json").write_text(json.dumps({
        "run_id": run_id, "policy": "No request bodies, credentials or user data recorded.",
        "bootstrap_unauthorized": "GET /api/usuarios/me/ 401 classified expected only before login.",
        "raw_server_log_tail": "omitted",
    }, ensure_ascii=False, indent=2), encoding="utf-8")


def _build_failure_result(report_dir: Path, root: Path, seed_counts: dict,
                          repetitions: int, smoke: bool, scenario_filter: set[str] | None,
                          timeout_ms: int, artificial_delay_ms: int, *, error_type: str,
                          timeout_seconds: int | None = None, exit_code: int | None = None) -> dict:
    return {
        "run_id": report_dir.name,
        "started_at": datetime.now(timezone.utc).isoformat(),
        "finished_at": datetime.now(timezone.utc).isoformat(),
        "sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
        "platform": platform.platform(), "python": platform.python_version(),
        "browser_expected_version": "not launched",
        "database": "SQLite fixture setup; browser not launched; PostgreSQL not accessed",
        "seed_counts": seed_counts,
        "viewport": {"width": 1280, "height": 900, "device_scale_factor": 1},
        "network_policy": "Browser not launched; no external network requests made.",
        "parameters": {"repetitions": repetitions, "smoke": smoke,
                       "scenario_filter": sorted(scenario_filter) if scenario_filter else None,
                       "timeout_ms": timeout_ms, "artificial_delay_ms": artificial_delay_ms},
        "build_exit_code": exit_code,
        "build_failure": {"phase": "flutter_web_build", "error_type": error_type,
                          "timeout_seconds": timeout_seconds},
        "scenarios": [], "scenario_failures": [], "status": "blocked",
        "limitations": ["Build Flutter Web não concluiu; nenhum cenário de browser executado."],
    }


def _wait_api_idle(page, state: dict, timeout_s: float = 5) -> list[dict]:
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        pending = [row for row in state["requests"] if not row["finished"]]
        if not pending:
            return []
        page.wait_for_timeout(40)
    return [
        {key: value for key, value in row.items() if key not in {"started", "finished"}}
        for row in state["requests"] if not row["finished"]
    ]


def _api_snapshot(api_probe: RequestLifecycleProbe, start: int, phase: str) -> dict:
    completed = [record for record in api_probe.snapshot() if record.sequence >= start
                 if record.path.startswith(("/api/", "/auth/"))]
    pending = [record for record in api_probe.pending_snapshot(start)
               if record.path.startswith(("/api/", "/auth/"))]
    rows = sorted(completed + pending, key=lambda record: record.sequence)
    login_sequences = [row.sequence for row in rows
                       if row.method == "POST" and row.path == "/auth/session/login/"]
    first_login_sequence = min(login_sequences) if login_sequences else None
    routes = Counter((row.method, row.path) for row in rows)
    sanitized = []
    for row in rows:
        is_unauthenticated_bootstrap = (
            row.path == "/api/usuarios/me/" and row.status == 401 and (
                phase == "visitor_bootstrap"
                or (first_login_sequence is not None and row.sequence < first_login_sequence)
            )
        )
        outcome = classify_http_outcome(
            row.path, row.status,
            "visitor_bootstrap" if is_unauthenticated_bootstrap else phase,
        )
        sanitized.append({
            "method": row.method, "path": row.path, "phase": phase,
            "status": row.status, "outcome": outcome if row.duration_ms is not None else "in_flight",
            "full_response_ms": row.duration_ms, "response_bytes": row.response_bytes,
            "sql_queries": row.sql_queries,
        })
    return {
        "phase": phase,
        "request_count": len(rows),
        "completed_count": len(completed),
        "in_flight_count": len(pending),
        "route_counts": [
            {"method": method, "path": path, "count": count}
            for (method, path), count in sorted(routes.items())
        ],
        "duplicate_route_count": sum(count - 1 for count in routes.values() if count > 1),
        "http_error_count": sum(item["outcome"] == "http_error" for item in sanitized),
        "requests": sanitized,
    }


def _new_page(browser, api_port: int, web_port: int, overpass_port: int, state: dict, phase: dict,
              timeout_ms: int = 20000):
    context = browser.new_context(
        locale="pt-BR", viewport={"width": 1280, "height": 900}, device_scale_factor=1,
    )
    context.set_default_timeout(timeout_ms)
    context.add_init_script("""
      (() => {
        localStorage.setItem('flutter.onboarding_completed', 'true');
        window.__card127Marks = [];
        window.__card127UiEvents = [];
        window.addEventListener('card127-performance', (event) => {
          try {
            const mark = JSON.parse(event.detail);
            mark.browser_elapsed_ms = performance.now();
            window.__card127Marks.push(mark);
          } catch (_) {}
        });
        document.addEventListener('input', (event) => {
          const element = event.target;
          if (element instanceof HTMLInputElement) {
            window.__card127UiEvents.push({type: 'input', label: element.getAttribute('aria-label')});
          }
        }, true);
        document.addEventListener('click', (event) => {
          const element = event.target instanceof Element ? event.target.closest('button,[role="button"]') : null;
          if (element) window.__card127UiEvents.push({type: 'click', role: element.getAttribute('role'), label: (element.getAttribute('aria-label') || element.textContent || '').trim().slice(0, 100)});
        }, true);
        document.addEventListener('keydown', (event) => {
          if (event.key === 'Enter') window.__card127UiEvents.push({type: 'enter', label: event.target instanceof Element ? event.target.getAttribute('aria-label') : null});
        }, true);
      })();
    """)
    third_party = []
    allowed_ports = {api_port, web_port, overpass_port}

    def route(request_route):
        parsed = urlsplit(request_route.request.url)
        if parsed.hostname in {"127.0.0.1", "localhost"} and parsed.port in allowed_ports:
            request_route.continue_()
        else:
            third_party.append(1)
            request_route.abort()

    context.route("**/*", route)
    page = context.new_page()
    page_errors = []
    page.on("pageerror", lambda error: page_errors.append(type(error).__name__))
    page_state = {"probe": state["probe"], "probe_start": state["probe"].checkpoint(),
                  "requests": [], "event_counts": {
        "request": 0, "response": 0, "requestfinished": 0,
        "requestfailed": 0, "unmatched_response": 0, "unmatched_completion": 0,
    }}

    def on_request(request):
        parsed = urlsplit(request.url)
        if parsed.port != api_port or not parsed.path.startswith(("/api/", "/auth/")):
            return
        try:
            sizes = request.sizes()
        except Exception:
            sizes = {}
        row = {
            "method": request.method, "path": parsed.path,
            "phase": phase["value"], "started": time.perf_counter(), "finished": False,
            "request_bytes": sizes.get("requestBodySize"),
            "_request_url": request.url,
        }
        page_state["requests"].append(row)
        page_state["event_counts"]["request"] += 1

    def row_for(request):
        for candidate in reversed(page_state["requests"]):
            if (not candidate["finished"] and candidate["method"] == request.method
                    and candidate["path"] == urlsplit(request.url).path):
                return candidate
        return None

    def is_api_request(request):
        parsed = urlsplit(request.url)
        return parsed.port == api_port and parsed.path.startswith(("/api/", "/auth/"))

    def on_response(response):
        if not is_api_request(response.request):
            return
        page_state["event_counts"]["response"] += 1
        row = row_for(response.request)
        if row is None:
            page_state["event_counts"]["unmatched_response"] += 1
        else:
            row["status"] = response.status
            row["headers_ms"] = round((time.perf_counter() - row["started"]) * 1000, 3)

    def on_finished(request):
        if not is_api_request(request):
            return
        page_state["event_counts"]["requestfinished"] += 1
        row = row_for(request)
        if row is None:
            page_state["event_counts"]["unmatched_completion"] += 1
            return
        try:
            sizes = request.sizes()
            row["request_bytes"] = sizes.get("requestBodySize", row.get("request_bytes"))
            row["response_bytes"] = sizes.get("responseBodySize")
        except Exception:
            row["response_bytes"] = None
        row["body_complete_ms"] = round((time.perf_counter() - row["started"]) * 1000, 3)
        row["finished"] = True
        row["outcome"] = classify_http_outcome(row["path"], row.get("status"), row["phase"])

    def on_failed(request):
        if not is_api_request(request):
            return
        page_state["event_counts"]["requestfailed"] += 1
        row = row_for(request)
        if row is not None:
            row["finished"] = True
            row["outcome"] = "request_failed"
            row["failure_type"] = "request_failed"
            row["body_complete_ms"] = round((time.perf_counter() - row["started"]) * 1000, 3)
        else:
            page_state["event_counts"]["unmatched_completion"] += 1

    page.on("request", on_request)
    page.on("response", on_response)
    page.on("requestfinished", on_finished)
    page.on("requestfailed", on_failed)
    return context, page, third_party, page_errors, page_state


def _wait_login_form_stable(page, timeout_ms: int) -> None:
    page.wait_for_function("""() => {
      const visible = element => {
        if (!element || !element.isConnected) return false;
        const rect = element.getBoundingClientRect();
        return rect.width > 0 && rect.height > 0 && getComputedStyle(element).visibility !== 'hidden';
      };
      const user = document.querySelector('input[aria-label="Usuário"]:not([disabled])');
      const password = document.querySelector('input[aria-label="Senha"]:not([disabled])');
      const submit = Array.from(document.querySelectorAll('[role="button"],button'))
        .find(element => (element.innerText || '').trim() === 'Entrar');
      if (!visible(user) || !visible(password) || !visible(submit)) {
        window.__card127LoginLayout = null;
        return false;
      }
      const rect = element => {
        const box = element.getBoundingClientRect();
        return [box.x, box.y, box.width, box.height].map(value => Math.round(value * 10) / 10);
      };
      const layout = JSON.stringify([rect(user), rect(password), rect(submit)]);
      const previous = window.__card127LoginLayout;
      window.__card127LoginLayout = {layout, frames: previous && previous.layout === layout ? previous.frames + 1 : 0};
      return window.__card127LoginLayout.frames >= 2;
    }""", polling="raf", timeout=timeout_ms)


def _click(page, name: str, *, role: str = "button"):
    target = page.get_by_role(role, name=name, exact=True).first
    target.wait_for(state="visible")
    if not target.is_enabled():
        raise RuntimeError(f"Ação indisponível na bancada sintética: {name}")
    target.click()
    return target


def _enter_app(page, profile: dict, api_state: dict, phase: dict, first_frame: dict,
               timeout_ms: int = 60000) -> dict:
    phase["value"] = "app_bootstrap" if profile.get("owner") else "visitor_bootstrap"
    navigation_started = time.perf_counter()
    page.goto(profile["origin"], wait_until="domcontentloaded")
    _wait_marker(page, "app_bootstrap_start", timeout_ms=timeout_ms)
    first_frame["mark"] = _wait_marker(page, "flutter_first_frame", timeout_ms=timeout_ms)
    phase["value"] = "login_form_ready"
    login_status = None
    login_submit_method = None
    if profile.get("owner"):
        placeholder = page.locator("flt-semantics-placeholder")
        placeholder.wait_for(state="attached", timeout=timeout_ms)
        placeholder.evaluate("element => element.click()")
        phase["value"] = "login_form_interaction_ready"
        _wait_login_form_stable(page, timeout_ms)
        for label, value in (("Usuário", profile["owner"]), ("Senha", "SyntheticOnly!127")):
            field = page.locator(f'input[aria-label="{label}"]:not([disabled])')
            phase["value"] = f"login_field_{label.lower()}"
            field.wait_for(state="visible", timeout=timeout_ms)
            field.click()
            page.keyboard.type(value)
            page.wait_for_function(
                "({label, value}) => { const input = document.querySelector(`input[aria-label=\\\"${label}\\\"]:not([disabled])`); return !!input && input.value === value; }",
                arg={"label": label, "value": value}, polling="raf", timeout=5000,
            )
            page_state = api_state.setdefault("login_form_state", {})
            page_state[f"{label.lower()}_value_set"] = field.input_value() == value
        phase["value"] = "login_submit_button"
        submit = page.get_by_role("button", name="Entrar", exact=True).first
        submit.wait_for(state="visible", timeout=timeout_ms)
        api_state["login_form_state"].update({
            "submit_enabled": submit.is_enabled(),
            "submit_bounds_px": submit.bounding_box(),
            "submit_semantics": submit.evaluate("element => ({tag: element.tagName, role: element.getAttribute('role'), label: element.getAttribute('aria-label'), text: (element.innerText || '').trim().slice(0, 80)})"),
        })
        submit.click(trial=True, timeout=timeout_ms)
        submit_bounds = submit.bounding_box()
        phase["value"] = "login_response_wait"
        with page.expect_response(
            lambda response: response.request.method == "POST"
            and urlsplit(response.url).path == "/auth/session/login/",
            timeout=timeout_ms,
        ) as login_response:
            # Use a physical pointer action on the verified semantics bounds.
            page.mouse.click(
                submit_bounds["x"] + submit_bounds["width"] / 2,
                submit_bounds["y"] + submit_bounds["height"] / 2,
            )
        login_status = login_response.value.status
        login_submit_method = "verified_semantics_bounds_pointer"
        if login_status < 200 or login_status >= 300:
            raise RuntimeError(f"login_http_status_{login_status}")
        phase["value"] = "login_main_screen_wait"
    else:
        placeholder = page.locator("flt-semantics-placeholder")
        placeholder.wait_for(state="attached", timeout=timeout_ms)
        placeholder.evaluate("element => element.click()")
        phase["value"] = "guest_continue"
        _click(page, "Explorar sem conta")
    phase["value"] = "main_screen_ready"
    page.get_by_role("tab", name="Avaliar", exact=True).wait_for(state="visible", timeout=timeout_ms)
    api_state["probe"].wait_idle(timeout=5)
    if profile.get("owner"):
        first_frame["authentication"] = {
            "login_http_status": login_status,
            "submit_method": login_submit_method,
            "main_screen_tab_visible": True,
            "ui_events": page.evaluate("() => (window.__card127UiEvents || []).slice(-12)"),
        }
    return {"navigation_start_monotonic": navigation_started}


def _suggestions_flow(page, api_state: dict, phase: dict, scenario_name: str,
                      *, expected: str = "recommendation", timeout_ms: int = 60000) -> dict:
    phase["value"] = "suggestions"
    request_start = api_state["probe"].checkpoint()
    before_markers = _marker_records(page)
    previous_screen_enters = sum(row.get("name") == "suggestions_screen_enter" for row in before_markers)
    started = time.perf_counter()
    _click(page, "Sugestões", role="tab")
    screen_enter = _wait_marker(page, "suggestions_screen_enter", after_count=previous_screen_enters,
                                timeout_ms=timeout_ms)
    if expected == "recommendation":
        card_mark = _wait_marker(
            page, "first_recommendation_card_visible",
            after_count=sum(row.get("name") == "first_recommendation_card_visible" for row in before_markers),
            timeout_ms=timeout_ms,
        )
        action_mark = _wait_marker(
            page, "first_route_action_enabled",
            after_count=sum(row.get("name") == "first_route_action_enabled" for row in before_markers),
            timeout_ms=timeout_ms,
        )
        route_action = page.get_by_role(
            "button", name=re.compile("Planejar rota para Card127")
        ).first
        route_action.wait_for(state="visible", timeout=timeout_ms)
        if not route_action.is_enabled():
            raise RuntimeError("A primeira ação de rota apareceu desabilitada")
        empty_mark, failure_mark = None, None
    elif expected == "empty":
        empty_mark = _wait_marker(
            page, "suggestions_empty_state_visible",
            after_count=sum(row.get("name") == "suggestions_empty_state_visible" for row in before_markers),
            timeout_ms=timeout_ms,
        )
        card_mark, action_mark, failure_mark = None, None, None
    else:
        failure_mark = _wait_marker(
            page, "suggestions_load_failed",
            after_count=sum(row.get("name") == "suggestions_load_failed" for row in before_markers),
            timeout_ms=timeout_ms,
        )
        card_mark, action_mark, empty_mark = None, None, None
    duration_to_interaction_ms = round((time.perf_counter() - started) * 1000, 3)
    api_state["probe"].wait_idle(timeout=5)
    events = _marker_records(page)
    suggestion_events = events[len(before_markers):]
    return {
        "scenario": scenario_name, "started_monotonic": started,
        "duration_to_interaction_ms": duration_to_interaction_ms,
        "screen_enter": screen_enter, "first_card_visible": card_mark,
        "first_route_action_enabled": action_mark, "empty_state_visible": empty_mark,
        "load_failed": failure_mark,
        "screen_to_first_card_ms": round(card_mark["browser_elapsed_ms"] - screen_enter["browser_elapsed_ms"], 3)
            if card_mark else None,
        "screen_to_route_action_ms": round(action_mark["browser_elapsed_ms"] - screen_enter["browser_elapsed_ms"], 3)
            if action_mark else None,
        "markers": suggestion_events,
        "api": _api_snapshot(api_state["probe"], request_start, "suggestions"),
    }


def run(report_dir: Path, *, chrome: Path, flutter: str = "flutter", repetitions: int = 3,
        web_port: int = 0, api_port: int = 0, overpass_port: int = 0,
        artificial_delay_ms: int = 750, smoke: bool = False,
        scenario_filter: set[str] | None = None) -> dict:
    report_dir.mkdir(parents=True, exist_ok=True)
    if (report_dir / "web.json").exists():
        raise FileExistsError(f"A evidência Web já existe; não será sobrescrita: {report_dir / 'web.json'}")
    root = Path(__file__).resolve().parents[2]
    frontend = root / "frontend"
    sys.path.insert(0, str(root))
    scenario_state = ScenarioState()
    timeout_ms = 15000 if smoke else 60000

    with tempfile.TemporaryDirectory(prefix="acessoja-card127-r2-web-", ignore_cleanup_errors=True) as temporary:
        temp_root = Path(temporary)
        build_dir = temp_root / "web_build"
        build_dir.mkdir()
        db_path = temp_root / "synthetic.sqlite3"

        def files_factory(port):
            class Files(QuietHTTP):
                def __init__(self, *args, **kwargs):
                    super().__init__(*args, directory=str(build_dir), **kwargs)
            return ThreadingHTTPServer(("127.0.0.1", port), Files)

        static_server = _new_http_server(files_factory, "Flutter Web local", web_port)
        web_port = static_server.server_port
        web_origin = f"http://127.0.0.1:{web_port}"

        overpass_server = _new_http_server(
            lambda port: ThreadingHTTPServer(("127.0.0.1", port), SyntheticOverpass),
            "stub Overpass local", overpass_port,
        )
        overpass_port = overpass_server.server_port
        os.environ.update({
            "DJANGO_SETTINGS_MODULE": "acessoja.settings",
            "SECRET_KEY": "card127-round2-ui-disposable-only",
            "DEBUG": "True", "ALLOWED_HOSTS": "127.0.0.1,localhost",
            "DATABASE_URL": "sqlite:///" + db_path.as_posix(),
            "CORS_ALLOWED_ORIGINS": web_origin,
            "CSRF_TRUSTED_ORIGINS": web_origin,
            "OVERPASS_URL": f"http://127.0.0.1:{overpass_port}/api/interpreter",
        })
        import django
        django.setup()
        from django.core.management import call_command
        from django.core.wsgi import get_wsgi_application
        from django.db import connections
        from django.test import override_settings
        from locais.models import Local, VisitaRecente
        from usuarios.models import Usuario
        from playwright.sync_api import sync_playwright

        scenario_state.set("setup")
        with override_settings(
            CORS_ALLOW_CREDENTIALS=True,
            PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"],
            PRIVATE_IMAGE_ROOT=temp_root / "private",
        ):
            call_command("migrate", verbosity=0, interactive=False)
            owners = [
                Usuario.objects.create_user(
                    f"card127-r2-owner-{index}", "SyntheticOnly!127",
                    email=f"round2-{index}@example.invalid",
                    accessibility_preferences=preferences,
                )
                for index, preferences in enumerate((
                    ["rampa_acesso", "banheiro_acessivel"],
                    ["rampa_acesso"],
                    [],
                ), start=1)
            ]
            fixtures = [
                ("Card127 Zero", "saude", "", {}),
                ("Card127 Parcial", "saude", "clinica", {"rampa_acesso": {"state": "presence_reported"}}),
                ("Card127 Principal", "saude", "hospital", {
                    "rampa_acesso": {"state": "presence_reported"},
                    "banheiro_acessivel": {"state": "presence_reported"},
                }),
            ]
            fixtures.extend((f"Card127 sintético {i:02d}", "educacao", "", {}) for i in range(22))
            places = [Local.objects.create(
                nome=name, endereco=f"Rua de teste {index:02d}", distancia=float(index),
                latitude=-16.3267 + ((index % 5) - 2) * .006,
                longitude=-48.9528 + ((index // 5) - 2) * .006,
                categoria=category, subcategoria=subcategory,
                accessibility_information=accessibility,
            ) for index, (name, category, subcategory, accessibility) in enumerate(fixtures)]
            for place in places[:3]:
                VisitaRecente.objects.create(user=owners[0], local=place, arrival_confirmed=True)
            seed_counts = {
                "locals": len(places), "synthetic_users": len(owners),
                "map_layout": "5x5 grid centered on the initial map camera; 0.006 degrees between fixtures",
                "visits_by_profile": {"auth_visits_preferences": 3, "auth_no_visits_preferences": 0,
                                      "auth_no_visits_no_preferences": 0},
            }
            api_port_arg = api_port
            try:
                django_app = get_wsgi_application()

                def app_close_connection(environ, start_response):
                    response = django_app(environ, start_response)
                    def consume_and_close():
                        try:
                            yield from response
                        finally:
                            close = getattr(response, "close", None)
                            if close:
                                close()
                            connections.close_all()
                    return consume_and_close()

                scenario_app = SyntheticScenarioMiddleware(
                    app_close_connection, scenario_state, web_origin,
                )
                api_probe = RequestLifecycleProbe(scenario_app)
                api_server = make_server(
                    "127.0.0.1", api_port_arg,
                    api_probe,
                    server_class=ThreadedWSGI, handler_class=QuietWSGI,
                )
            except OSError as error:
                raise bind_error("API local Web Card 127", "127.0.0.1", api_port_arg, error) from error
            api_port = api_server.server_port

            flutter_exe = shutil.which(flutter) or flutter
            build_command = [
                flutter_exe, "build", "web", "--release", "--no-pub", "--no-web-resources-cdn",
                f"--dart-define=API_BASE_URL=http://127.0.0.1:{api_port}",
                "--dart-define=CARD127_BENCHMARK=true",
                "--dart-define=STADIA_MAPS_ENABLED=false",
                "--dart-define=ROUTE_BASE_URL=http://127.0.0.1:9",
                f"--output={build_dir}",
            ]
            try:
                completed = subprocess.run(
                    build_command, cwd=frontend, text=True, capture_output=True,
                    shell=os.name == "nt", timeout=360,
                )
            except (OSError, subprocess.TimeoutExpired) as error:
                failed_build = _build_failure_result(
                    report_dir, root, seed_counts, repetitions, smoke, scenario_filter,
                    timeout_ms, artificial_delay_ms, error_type=type(error).__name__,
                    timeout_seconds=360 if isinstance(error, subprocess.TimeoutExpired) else None,
                )
                (report_dir / "web.json").write_text(
                    json.dumps(failed_build, ensure_ascii=False, indent=2), encoding="utf-8",
                )
                _write_round3_artifacts(report_dir, failed_build, flutter)
                return failed_build
            if completed.returncode:
                failed_build = _build_failure_result(
                    report_dir, root, seed_counts, repetitions, smoke, scenario_filter,
                    timeout_ms, artificial_delay_ms, error_type="BuildFailed",
                    exit_code=completed.returncode,
                )
                (report_dir / "web.json").write_text(
                    json.dumps(failed_build, ensure_ascii=False, indent=2), encoding="utf-8",
                )
                _write_round3_artifacts(report_dir, failed_build, flutter)
                return failed_build
            app_js = build_dir / "main.dart.js"
            if not app_js.exists():
                raise RuntimeError("O build Flutter encerrou sem gerar main.dart.js no diretório temporário.")

            servers = (static_server, overpass_server, api_server)
            threads = []
            for server in servers:
                thread = Thread(target=server.serve_forever, daemon=True)
                thread.start()
                threads.append(thread)
            api_origin = f"http://127.0.0.1:{api_port}"
            result = {
                "run_id": report_dir.name,
                "started_at": datetime.now(timezone.utc).isoformat(),
                "sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
                "instrumentation_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                "app_probe_sha256": hashlib.sha256(
                    (frontend / "lib/services/card127_performance_probe.dart").read_bytes()
                ).hexdigest(),
                "build_sha256": hashlib.sha256(app_js.read_bytes()).hexdigest(),
                "platform": platform.platform(), "python": platform.python_version(),
                "flutter_build_output": "captured privately; only exit code and SDK version recorded",
                "build_exit_code": completed.returncode,
                "browser_expected_version": "Chrome version is recorded by Playwright",
                "database": "disposable SQLite, synthetic-only; no PostgreSQL credentials/config used",
                "seed_counts": seed_counts,
                "ports": {"web_loopback": web_port, "api_loopback": api_port,
                          "overpass_loopback": overpass_port},
                "cache": "new Chrome context for each cold profile; warm-reopen remains in the same app/context",
                "viewport": {"width": 1280, "height": 900, "device_scale_factor": 1},
                "network_policy": "Only these three loopback ports are allowed; all other browser hosts aborted.",
                "measurement_semantics": {
                    "flutter_marks": "browser_elapsed_ms uses window.performance.now() at event receipt; mark-to-mark deltas use that browser clock.",
                    "web_intervals": "screen/list/selection durations use Python time.perf_counter() as standalone intervals; never subtracted from browser timestamps.",
                    "suggestions_action_interval": "starts before locator wait/click on the Suggestions tab; includes automation locator/readiness time, not a direct timestamp of physical user click.",
                    "api_lifecycle": "Threaded WSGI RequestLifecycleProbe records through full response iterable consumption and reports in_flight separately.",
                },
                "parameters": {"repetitions": repetitions, "smoke": smoke,
                               "scenario_filter": sorted(scenario_filter) if scenario_filter else None,
                               "timeout_ms": timeout_ms, "artificial_delay_ms": artificial_delay_ms},
                "scenarios": [],
                "scenario_failures": [],
                "limitations": [
                    "Headless desktop Chrome; not a physical Android or GPU measurement.",
                    "Map tiles and route providers are disabled/blocked; backend Overpass uses a local empty fixture.",
                    "No personal user data; credentials are generated only for disposable synthetic accounts.",
                ],
            }

            state = {"probe": api_probe}
            phase = {"value": "app_bootstrap"}
            with ExitStack() as stack:
                stack.callback(connections.close_all)
                for server, thread in zip(servers, threads):
                    stack.callback(thread.join, 5)
                    stack.callback(server.server_close)
                    stack.callback(server.shutdown)
                playwright = stack.enter_context(sync_playwright())
                browser = playwright.chromium.launch(
                    executable_path=str(chrome), headless=True,
                    args=["--no-sandbox", "--disable-dev-shm-usage"],
                )
                stack.callback(browser.close)
                result["browser_version"] = browser.version

                profiles = [
                    ("auth_visits_preferences", owners[0].nome, "recommendation"),
                    ("auth_no_visits_preferences", owners[1].nome, "recommendation"),
                    ("auth_no_visits_no_preferences", owners[2].nome, "recommendation"),
                    ("guest_no_visits", None, "recommendation"),
                    ("empty_results_guest", None, "empty"),
                    ("slow_discovery_guest", None, "recommendation"),
                    ("http_503_discovery_guest", None, "error"),
                ]
                if scenario_filter:
                    profiles = [item for item in profiles if item[0] in scenario_filter]
                elif repetitions == 1 and smoke:
                    profiles = [item for item in profiles if item[0] in {
                        "guest_no_visits", "empty_results_guest"
                    }]
                if not profiles:
                    raise ValueError("Nenhum perfil de cenário selecionado")
                for profile_name, owner_name, expected in profiles:
                    for repetition in range(1, repetitions + 1):
                        if profile_name == "empty_results_guest":
                            scenario_state.set(profile_name, empty_results=True)
                        elif profile_name == "slow_discovery_guest":
                            scenario_state.set(profile_name, artificial_delay_ms=artificial_delay_ms)
                        elif profile_name == "http_503_discovery_guest":
                            scenario_state.set(profile_name, forced_status=503)
                        else:
                            scenario_state.set(profile_name)
                        context, page, external, page_errors, page_state = _new_page(
                            browser, api_port, web_port, overpass_port, state, phase, timeout_ms
                        )
                        try:
                            first_frame = {}
                            _enter_app(page, {"origin": web_origin, "owner": owner_name}, page_state, phase,
                                       first_frame, timeout_ms)
                            flow = _suggestions_flow(page, page_state, phase, profile_name,
                                                     expected=expected, timeout_ms=timeout_ms)
                            flow.update({
                                "repetition": repetition, "profile": profile_name,
                                "first_frame": first_frame["mark"],
                                "bootstrap_to_first_frame_ms": round(
                                    first_frame["mark"]["browser_elapsed_ms"] - next(
                                        row["browser_elapsed_ms"] for row in _marker_records(page)
                                        if row.get("name") == "app_bootstrap_start"
                                    ), 3,
                                ),
                                "third_party_attempts": len(external), "page_errors": page_errors,
                                "pending_at_boundary": flow["api"]["in_flight_count"],
                                "authentication": first_frame.get("authentication"),
                            })
                            flow.pop("started_monotonic", None)
                            result["scenarios"].append(flow)
                        except Exception as error:
                            result["scenario_failures"].append({
                                "scenario": profile_name, "profile": profile_name,
                                "repetition": repetition,
                                **_safe_failure_diagnostics(page, page_state, phase["value"], error),
                            })
                        finally:
                            context.close()

                # Measure app-initialized reopen separately from cold browser bootstrap.
                for repetition in range(1, repetitions + 1) if not smoke and (
                    scenario_filter is None or "warm_reopen_auth" in scenario_filter
                ) else []:
                    scenario_state.set("warm_reopen_auth")
                    context, page, external, page_errors, page_state = _new_page(
                        browser, api_port, web_port, overpass_port, state, phase, timeout_ms
                    )
                    try:
                        first_frame = {}
                        _enter_app(page, {"origin": web_origin, "owner": owners[0].nome},
                                   page_state, phase, first_frame, timeout_ms)
                        first = _suggestions_flow(page, page_state, phase, "warm_reopen_first")
                        _click(page, "Voltar")
                        page.get_by_role("tab", name="Avaliar", exact=True).wait_for(state="visible")
                        second = _suggestions_flow(page, page_state, phase, "warm_reopen_second")
                        result["scenarios"].extend([
                            {**first, "profile": "warm_reopen_auth", "repetition": repetition,
                             "third_party_attempts": len(external), "page_errors": page_errors},
                            {**second, "profile": "warm_reopen_auth", "repetition": repetition,
                             "third_party_attempts": len(external), "page_errors": page_errors},
                        ])
                    finally:
                        context.close()

                # Production map: wait for an actionable marker, then list result and selection.
                for repetition in range(1, repetitions + 1) if (
                    scenario_filter is None or "production_map_flow" in scenario_filter
                ) else []:
                    scenario_state.set("map_flow_authenticated")
                    context, page, external, page_errors, page_state = _new_page(
                        browser, api_port, web_port, overpass_port, state, phase, timeout_ms
                    )
                    map_api_start = page_state["probe"].checkpoint()
                    try:
                        _enter_app(page, {"origin": web_origin, "owner": owners[0].nome},
                                   page_state, phase, {}, timeout_ms)
                        main_screen = _wait_marker(page, "main_screen_enter", timeout_ms=timeout_ms)
                        map_ready = _wait_marker(page, "map_ready", timeout_ms=timeout_ms)
                        phase["value"] = "map_first_marker"
                        marker_error = None
                        try:
                            marker_event = _usable_map_marker(page, timeout_ms)
                            marker_event["browser_elapsed_ms"] = page.evaluate("performance.now()")
                            first_marker_ms = marker_event["browser_elapsed_ms"] - main_screen["browser_elapsed_ms"]
                        except Exception as error:
                            marker_error = {"type": type(error).__name__, "message": str(error)[:300]}
                            marker_event, first_marker_ms = None, None
                        page_state["probe"].wait_idle(timeout=1)
                        marker_api = _api_snapshot(page_state["probe"], map_api_start, "map_bootstrap_to_marker")
                        phase["value"] = "map_results_list"
                        list_request_start = page_state["probe"].checkpoint()
                        list_start = time.perf_counter()
                        _click(page, "Buscar destino ou calcular rota")
                        result_row = page.get_by_role("button", name=re.compile("Card127 Principal")).last
                        result_row.wait_for(state="visible")
                        list_ms = round((time.perf_counter() - list_start) * 1000, 3)
                        page_state["probe"].wait_idle(timeout=1)
                        list_api = _api_snapshot(page_state["probe"], list_request_start, "map_results_list")
                        selection_request_start = page_state["probe"].checkpoint()
                        select_start = time.perf_counter()
                        result_row.click()
                        page.get_by_role("heading", name="Card127 Principal", exact=True).wait_for(
                            state="visible", timeout=timeout_ms,
                        )
                        select_ms = round((time.perf_counter() - select_start) * 1000, 3)
                        detail_idle = page_state["probe"].wait_idle(timeout=5)
                        detail_ready_ms = round((time.perf_counter() - select_start) * 1000, 3)
                        map_result = {
                            "scenario": "production_map_flow", "profile": "authenticated",
                            "repetition": repetition,
                            "authentication": first_frame.get("authentication"),
                            "map_ready": map_ready,
                            "first_marker_usable_ms_from_app_ready": first_marker_ms,
                            "first_marker_usable_ms_from_map_ready": round(
                                marker_event["browser_elapsed_ms"] - map_ready["browser_elapsed_ms"], 3
                            ) if marker_event else None,
                            "main_screen_enter": main_screen,
                            "first_marker_observed": marker_event,
                            "first_marker_usable": ({"name": "first_marker_usable", **marker_event}
                                                     if marker_event else None),
                            "first_marker_failure_type": marker_error,
                            "first_results_list_usable_ms": list_ms,
                            "local_selection_ms": select_ms,
                            "detail_ready_ms": detail_ready_ms,
                            "detail_heading_visible": True,
                            "detail_requests_idle_at_boundary": detail_idle,
                            "api": marker_api, "list_api": list_api,
                            "selection_api": _api_snapshot(page_state["probe"], selection_request_start, "map_selection"),
                            "third_party_attempts": len(external), "page_errors": page_errors,
                        }
                        result["scenarios"].append(map_result)
                    except Exception as error:
                        result["scenario_failures"].append({
                            "scenario": "production_map_flow", "profile": "authenticated",
                            "repetition": repetition,
                            **_safe_failure_diagnostics(page, page_state, phase["value"], error),
                        })
                    finally:
                        context.close()

            result["finished_at"] = datetime.now(timezone.utc).isoformat()
            result["status"] = "partial" if result["scenario_failures"] else "executed"
            (report_dir / "web.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
            _write_round3_artifacts(report_dir, result, flutter)
            return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--chrome", type=Path, required=True)
    parser.add_argument("--flutter", default="flutter")
    parser.add_argument("--repetitions", type=int, default=3)
    parser.add_argument("--web-port", type=int, default=0)
    parser.add_argument("--api-port", type=int, default=0)
    parser.add_argument("--overpass-port", type=int, default=0)
    parser.add_argument("--artificial-delay-ms", type=int, default=750)
    parser.add_argument("--smoke", action="store_true")
    parser.add_argument("--scenario", action="append", dest="scenarios",
                        help="run only the named profile; repeat flag to select multiple")
    args = parser.parse_args()
    if args.repetitions < 1 or args.artificial_delay_ms < 1:
        parser.error("repetitions e artificial-delay-ms devem ser positivos")
    result = run(
        args.report.resolve(), chrome=args.chrome, flutter=args.flutter,
        repetitions=args.repetitions, web_port=args.web_port,
        api_port=args.api_port, overpass_port=args.overpass_port,
        artificial_delay_ms=args.artificial_delay_ms,
        smoke=args.smoke,
        scenario_filter=set(args.scenarios) if args.scenarios else None,
    )
    print(f"Web Card 127: {result['status']} — {args.report.resolve()}")
    return 0 if result["status"] == "executed" else 2


if __name__ == "__main__":
    raise SystemExit(main())
