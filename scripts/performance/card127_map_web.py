#!/usr/bin/env python3
"""Collect the repository's synthetic Flutter Web marker-layout benchmark in Chrome."""

from __future__ import annotations

import argparse
from contextlib import ExitStack
import csv
from datetime import datetime, timezone
import hashlib
import json
import platform
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from urllib.parse import urlsplit


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chrome", type=Path, required=True)
    parser.add_argument("--rounds", type=int, default=3)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    if args.rounds < 3:
        parser.error("Use ao menos 3 rodadas para comparar medianas.")
    root = Path(__file__).resolve().parents[2]
    build = root / "frontend" / "build" / "web"
    entry = root / "frontend" / "integration_test" / "map_marker_benchmark.dart"
    report_dir = args.report.resolve()
    report_dir.mkdir(parents=True, exist_ok=False)
    result = {
        "started_at": datetime.now(timezone.utc).isoformat(),
        "sha": __import__("subprocess").check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
        "instrumentation_sha256": hashlib.sha256(entry.read_bytes()).hexdigest(),
        "build_sha256": hashlib.sha256((build / "main.dart.js").read_bytes()).hexdigest(),
        "platform": platform.platform(),
        "browser_expected_version": "Chrome 157.0.8103.52",
        "sdk": "Flutter 3.47.5 / Dart 3.13.4 (project pin Flutter 3.47.4)",
        "mode": "Flutter Web release; headless Chrome; synthetic AdaptivePlaceLayer; no API, tile or third-party calls",
        "viewport": {"width": 1000, "height": 740, "device_scale_factor": 1},
        "rounds_requested": args.rounds,
        "rounds": [],
        "limitations": ["Measures marker layout and RAF intervals, not opening/filtering the production map flow.",
                        "RAF intervals in headless Chrome are not physical GPU raster timing or Android evidence."],
    }

    class Quiet(SimpleHTTPRequestHandler):
        def log_message(self, *values):
            pass

    from playwright.sync_api import sync_playwright

    with ExitStack() as stack:
        server = ThreadingHTTPServer(("127.0.0.1", 0), lambda *values, **kwargs: Quiet(*values, directory=str(build), **kwargs))
        stack.callback(server.server_close)
        stack.callback(server.shutdown)
        Thread(target=server.serve_forever, daemon=True).start()
        playwright = stack.enter_context(sync_playwright())
        browser = playwright.chromium.launch(executable_path=str(args.chrome), headless=True,
                                             args=["--no-sandbox", "--disable-dev-shm-usage"])
        stack.callback(browser.close)
        result["browser_version"] = browser.version
        for number in range(1, args.rounds + 1):
            context = browser.new_context(viewport={"width": 1000, "height": 740}, device_scale_factor=1)
            stack.callback(context.close)
            external, api, errors = [], [], []

            def route(request_route):
                host = urlsplit(request_route.request.url).hostname
                if host in {"127.0.0.1", "localhost"}:
                    if "/api/" in urlsplit(request_route.request.url).path:
                        api.append(urlsplit(request_route.request.url).path)
                    request_route.continue_()
                else:
                    external.append(host or "unknown")
                    request_route.abort()

            context.route("**/*", route)
            page = context.new_page()
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.goto(f"http://127.0.0.1:{server.server_port}/", wait_until="domcontentloaded")
            page.wait_for_function('typeof window.__mapBenchResult === "string"', timeout=90000)
            sample = json.loads(page.evaluate("window.__mapBenchResult"))
            if api or external or errors:
                raise RuntimeError(f"API/terceiros/erros detectados: api={len(api)}, terceiros={external}, erros={errors}")
            # The Dart fixture contains its original SDK pin; the collector records
            # the SDK that actually built this artifact at the top level.
            sample["sdk"] = result["sdk"]
            sample.update({"round": number, "api_requests": len(api), "third_party_attempts": len(external), "page_errors": errors})
            result["rounds"].append(sample)
            (report_dir / "mapa.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
            print(f"Rodada {number}/{args.rounds}: benchmark de marcadores concluído", flush=True)

    fields = ["run_id", "sha", "fase", "cenario", "rota_ou_marco", "cache", "repeticao", "amostras", "sucessos",
              "erros", "timeouts", "p50_ms", "p95_ms", "vazao", "vazao_unidade", "concorrencia_observada",
              "payload_bytes_medio", "limite_ms", "status", "evidencia"]
    run_id = report_dir.name
    with (report_dir / "mapa.csv").open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for round_data in result["rounds"]:
            for row in round_data["samples"]:
                writer.writerow({"run_id": run_id, "sha": result["sha"], "fase": "baseline",
                    "cenario": "map_marker_layout", "rota_ou_marco": f"AdaptivePlaceLayer_{row['places']}_places",
                    "cache": "warmup_excluded", "repeticao": round_data["round"], "amostras": row["layout_repetitions"],
                    "sucessos": row["layout_repetitions"], "erros": 0, "timeouts": 0,
                    "p50_ms": row["layout_median_us"] / 1000, "p95_ms": row["layout_p95_us"] / 1000,
                    "vazao": None, "vazao_unidade": None, "concorrencia_observada": 1, "payload_bytes_medio": None,
                    "limite_ms": None, "status": "EXPLORATORIO", "evidencia": "mapa.json#rounds"})
    result["finished_at"] = datetime.now(timezone.utc).isoformat()
    result["status"] = "executed"
    (report_dir / "mapa.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(report_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
