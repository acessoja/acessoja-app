#!/usr/bin/env python3
"""Local, repeatable Card 127 HTTP benchmark and result comparator.

Only loopback targets are accepted by default. A non-loopback destination needs
the explicit --authorized-host option and the host must match exactly.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import csv
from datetime import datetime, timezone
import hashlib
import json
import math
import os
import platform
import html
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_ROUTE = "/api/locais/?paginated=true&page_size=20&page=1&search=Card127&categorias=cafeteria"
CSV_FIELDS = [
    "run_id", "sha", "fase", "cenario", "rota_ou_marco", "cache", "repeticao",
    "amostras", "sucessos", "erros", "timeouts", "p50_ms", "p95_ms", "vazao",
    "vazao_unidade", "concorrencia_observada", "payload_bytes_medio", "limite_ms", "status", "evidencia",
]


def percentile(values: list[float], p: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    index = (len(ordered) - 1) * p
    low, high = math.floor(index), math.ceil(index)
    return round(ordered[low] + (ordered[high] - ordered[low]) * (index - low), 3)


def validate_target(value: str, authorized_host: str | None) -> str:
    parsed = urllib.parse.urlsplit(value)
    if parsed.scheme != "http" or not parsed.hostname or parsed.username or parsed.password:
        raise ValueError("Destino deve ser uma origem HTTP local sem credenciais ou query string.")
    if parsed.query or parsed.fragment:
        raise ValueError("Informe somente a origem da API; caminhos e parâmetros são definidos pelo cenário.")
    host = parsed.hostname.lower()
    if host not in {"127.0.0.1", "localhost", "::1"} and host != (authorized_host or "").lower():
        raise ValueError("Destino externo bloqueado. Use --authorized-host com o hostname controlado aprovado.")
    return value.rstrip("/")


def request_once(url: str, timeout: float) -> tuple[float, int | None, str | None, int, int | None]:
    started = time.perf_counter()
    try:
        request = urllib.request.Request(url, headers={"Accept": "application/json", "User-Agent": "AcessoJa-Card127/1.0"})
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read()
            status = response.status
        elapsed = (time.perf_counter() - started) * 1000
        try:
            decoded = json.loads(body)
            if not isinstance(decoded, dict) or not isinstance(decoded.get("results"), list):
                return elapsed, status, "unexpected_payload", len(body), None
            return elapsed, status, None, len(body), len(decoded["results"])
        except (json.JSONDecodeError, UnicodeDecodeError):
            return elapsed, status, "unexpected_payload", len(body), None
    except urllib.error.HTTPError as exc:
        body = exc.read()
        return (time.perf_counter() - started) * 1000, exc.code, "http_error", len(body), None
    except TimeoutError:
        return (time.perf_counter() - started) * 1000, None, "timeout", 0, None
    except Exception as exc:  # retain failed attempts in the denominator
        return (time.perf_counter() - started) * 1000, None, type(exc).__name__, 0, None


def run_phase(url: str, samples: int, concurrency: int, timeout: float) -> dict:
    barrier = threading.Barrier(concurrency) if concurrency > 1 else None
    active = 0
    maximum_overlap = 0
    lock = threading.Lock()

    def sample(_: int):
        nonlocal active, maximum_overlap
        if barrier:
            try:
                barrier.wait(timeout=timeout)
            except threading.BrokenBarrierError:
                return (0.0, None, "barrier_timeout", 0, None)
        with lock:
            active += 1
            maximum_overlap = max(maximum_overlap, active)
        try:
            return request_once(url, timeout)
        finally:
            with lock:
                active -= 1

    started = time.perf_counter()
    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as pool:
        outcomes = list(pool.map(sample, range(samples)))
    elapsed = time.perf_counter() - started
    latencies = [row[0] for row in outcomes]
    successes = sum(status is not None and 200 <= status < 400 and error is None for _, status, error, _, _ in outcomes)
    timeouts = sum(error == "timeout" for _, _, error, _, _ in outcomes)
    return {
        "samples": samples,
        "successes": successes,
        "errors": samples - successes,
        "timeouts": timeouts,
        "p50_ms": percentile(latencies, .50),
        "p95_ms": percentile(latencies, .95),
        "throughput": round(samples / elapsed, 3) if elapsed else None,
        "throughput_unit": "requests/s",
        "concurrency_observed": maximum_overlap,
        "elapsed_s": round(elapsed, 3),
        "http_statuses": dict(sorted((str(code), sum(1 for _, s, _, _, _ in outcomes if s == code)) for code in {s for _, s, _, _, _ in outcomes if s is not None})),
        "failure_kinds": dict(sorted((kind, sum(1 for _, _, err, _, _ in outcomes if err == kind)) for kind in {err for _, _, err, _, _ in outcomes if err})),
        "payload_bytes_mean": round(sum(size for _, _, _, size, _ in outcomes) / len(outcomes), 1),
        "results_per_response": sorted({count for _, _, _, _, count in outcomes if count is not None}),
        "expected_page_size": all(count == 20 for _, status, error, _, count in outcomes if status == 200 and error is None),
    }


def write_run(args: argparse.Namespace) -> Path:
    base_url = validate_target(args.base_url, args.authorized_host)
    run_id = args.run_id or datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid.uuid4().hex[:6]
    out = args.output.resolve() if args.output else ROOT / "reports" / "performance" / run_id
    out.mkdir(parents=True, exist_ok=False)
    sha = __import__("subprocess").check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    parsed = urllib.parse.urlsplit(base_url)
    protocol = {
        "run_id": run_id,
        "started_at": datetime.now(timezone.utc).isoformat(),
        "sha": sha,
        "instrumentation_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "target_origin": f"{parsed.scheme}://{parsed.netloc}",
        "target_scope": "explicitly authorized controlled local/staging API",
        "platform": platform.platform(),
        "hardware": {"architecture": platform.machine(), "processor": platform.processor() or None,
                     "logical_cpus": os.cpu_count(), "physical_memory_bytes": None,
                     "memory_probe": "Windows CIM permission denied; physical memory not collected"},
        "python": sys.version.split()[0],
        "database": args.database,
        "server_workers": args.server_workers,
        "network": "loopback" if parsed.hostname in {"127.0.0.1", "localhost", "::1"} else "controlled network (operator supplied)",
        "cache_policy": "one cold-request observation (excluded from phase metrics), followed by explicit warm samples",
        "warmup_requests": args.warmup,
        "samples_per_phase": args.samples,
        "concurrency_levels": args.concurrency,
        "timeout_s": args.timeout,
        "synthetic_dataset": {"seed": args.seed, "effective_entity_counts": args.entity_counts},
        "route": DEFAULT_ROUTE,
        "thresholds": {"api_p95_ms": 2000, "error_budget_pct": args.error_budget_pct},
        "caveat": "Server overlap is reported only when instrumented by the lab; local SQLite is diagnostic and does not certify production capacity.",
    }
    (out / "ambiente.json").write_text(json.dumps(protocol, ensure_ascii=False, indent=2), encoding="utf-8")

    url = base_url + DEFAULT_ROUTE
    cold = request_once(url, args.timeout)
    warmup = [request_once(url, args.timeout) for _ in range(args.warmup)]
    rows: list[dict] = []
    rows.append({
        "run_id": run_id, "sha": sha, "fase": "baseline", "cenario": "api_discovery",
        "rota_ou_marco": DEFAULT_ROUTE, "cache": "primeira_requisicao_estado_disco_desconhecido", "repeticao": 1,
        "amostras": 1, "sucessos": int(cold[1] == 200 and cold[2] is None),
        "erros": int(cold[1] != 200 or cold[2] is not None), "timeouts": int(cold[2] == "timeout"),
        "p50_ms": round(cold[0], 3), "p95_ms": None, "vazao": None, "vazao_unidade": None,
        "concorrencia_observada": None, "payload_bytes_medio": cold[3], "limite_ms": 2000, "status": "EXPLORATORIO",
        "evidencia": "resumo.json#cold_observation",
    })
    phases = [(repetition, concurrency, "warm")
              for repetition in range(1, args.repetitions + 1)
              for concurrency in args.concurrency]
    for repetition, concurrency, cache in phases:
        if getattr(args, "server_concurrency_reset", None):
            args.server_concurrency_reset()
        result = run_phase(url, args.samples, concurrency, args.timeout)
        error_pct = result["errors"] * 100 / result["samples"] if result["samples"] else 100
        status = "FALHOU"
        server_overlap = args.server_concurrency_probe() if getattr(args, "server_concurrency_probe", None) else None
        if server_overlap is not None:
            result["server_concurrency_observed"] = server_overlap
        if getattr(args, "server_query_count_probe", None):
            result["sql_queries"] = args.server_query_count_probe()
        measured_overlap = server_overlap if server_overlap is not None else result["concurrency_observed"]
        scenario_index = len(protocol.get("scenarios", []))
        evidence = f"resumo.json#scenarios[{scenario_index}]"
        rows.append({
            "run_id": run_id, "sha": sha, "fase": "baseline", "cenario": "api_discovery", "rota_ou_marco": DEFAULT_ROUTE,
            "cache": cache, "repeticao": repetition, "amostras": result["samples"], "sucessos": result["successes"],
            "erros": result["errors"], "timeouts": result["timeouts"], "p50_ms": result["p50_ms"], "p95_ms": result["p95_ms"],
            "vazao": result["throughput"], "vazao_unidade": result["throughput_unit"],
            "concorrencia_observada": measured_overlap, "payload_bytes_medio": result["payload_bytes_mean"],
            "limite_ms": 2000, "status": status, "evidencia": evidence,
        })
        result.update({"concurrency_requested": concurrency, "cache": cache, "repetition": repetition,
                       "error_pct": round(error_pct, 3), "error_budget_pct": args.error_budget_pct,
                       "threshold_passed": result["p95_ms"] is not None and result["p95_ms"] <= 2000 and error_pct <= args.error_budget_pct})
        rows[-1]["status"] = "PASSOU" if result["threshold_passed"] and result["successes"] == result["samples"] else "FALHOU"
        if concurrency == 100 and measured_overlap < 100:
            rows[-1]["status"] = "BLOQUEADO"
        if "scenarios" not in protocol:
            protocol["scenarios"] = []
        protocol["scenarios"].append(result)

    summary = {
        "run_id": run_id, "sha": sha, "status": "executed", "route": DEFAULT_ROUTE,
        "cold_observation": {"latency_ms": round(cold[0], 3), "http_status": cold[1], "failure": cold[2]},
        "warmup": {"requested": args.warmup, "successful": sum(1 for _, code, err, _, _ in warmup if code == 200 and err is None)},
        "scenarios": protocol.get("scenarios", []),
        "dataset": protocol["synthetic_dataset"],
        "limitations": ["SQLite/runserver/headless evidence is diagnostic only if used.", "Map and Flutter UI phases are separate from this HTTP run."],
    }
    if getattr(args, "server_query_metrics", None):
        protocol["diagnostic_sql"] = args.server_query_metrics()
        summary["diagnostic_sql"] = protocol["diagnostic_sql"]
    (out / "ambiente.json").write_text(json.dumps(protocol, ensure_ascii=False, indent=2), encoding="utf-8")
    (out / "resumo.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    make_chart(summary, out / "p95.svg")
    with (out / "resultados.csv").open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.DictWriter(handle, fieldnames=CSV_FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    print(out)
    return out


def make_chart(summary: dict, destination: Path) -> None:
    """Create a dependency-free SVG chart from measured p95 observations."""
    groups: dict[int, list[float]] = {}
    for row in summary.get("scenarios", []):
        if row.get("p95_ms") is not None:
            groups.setdefault(row["concurrency_requested"], []).append(row["p95_ms"])
    scenarios = [{"concurrency_requested": level, "p95_ms": percentile(samples, .50),
                  "samples": sum(1 for row in summary["scenarios"] if row.get("concurrency_requested") == level) * summary["scenarios"][0]["samples"]}
                 for level, samples in sorted(groups.items())]
    values = [row["p95_ms"] for row in scenarios]
    if not values:
        destination.write_text("<svg xmlns='http://www.w3.org/2000/svg' width='720' height='140'><text x='20' y='50'>Sem amostras p95 coletadas</text></svg>", encoding="utf-8")
        return
    height, width = 300, 760
    max_value = max(max(values), 2000)
    plot_height = 190
    bars = []
    for index, row in enumerate(scenarios):
        value = row.get("p95_ms")
        if value is None:
            continue
        x = 90 + index * 210
        bar_height = max(2, value / max_value * plot_height)
        color = "#b42318" if value > 2000 else "#16794b"
        label = html.escape(f"{row.get('concurrency_requested')} concorrentes; n={row.get('samples')}")
        bars.append(f"<rect x='{x}' y='{220-bar_height:.1f}' width='92' height='{bar_height:.1f}' fill='{color}'/><text x='{x}' y='244' font-size='13'>{label}</text><text x='{x}' y='{210-bar_height:.1f}' font-size='14'>{value:.1f} ms</text>")
    svg = (f"<svg xmlns='http://www.w3.org/2000/svg' width='{width}' height='{height}' viewBox='0 0 {width} {height}'>"
           "<rect width='100%' height='100%' fill='white'/><text x='20' y='28' font-size='18'>API descoberta — p95 por concorrência</text>"
           f"<text x='20' y='54' font-size='12'>Diagnóstico SQLite; referência de API: 2.000 ms</text><line x1='70' y1='220' x2='730' y2='220' stroke='#555'/>"
           f"{''.join(bars)}</svg>")
    destination.write_text(svg, encoding="utf-8")


def compare(args: argparse.Namespace) -> int:
    before, after = (json.loads(path.read_text(encoding="utf-8")) for path in (args.before, args.after))
    b_env = json.loads((args.before.parent / "ambiente.json").read_text(encoding="utf-8"))
    a_env = json.loads((args.after.parent / "ambiente.json").read_text(encoding="utf-8"))
    keys = ("instrumentation_sha256", "database", "server_workers", "network", "warmup_requests", "samples_per_phase", "concurrency_levels", "synthetic_dataset", "route")
    mismatches = [key for key in keys if b_env.get(key) != a_env.get(key)]
    old = before.get("scenarios", [])
    new = after.get("scenarios", [])
    if len(old) != len(new):
        mismatches.append("scenario_count")
    report = {"comparison": "valid" if not mismatches else "invalid_environment_mismatch", "mismatches": mismatches, "scenarios": []}
    for left, right in zip(old, new):
        l95, r95 = left.get("p95_ms"), right.get("p95_ms")
        report["scenarios"].append({"scenario": f"{left.get('concurrency_requested')} concorrentes, repetição {left.get('repetition')}", "before_p95_ms": l95, "after_p95_ms": r95,
            "p95_delta_ms": round(r95-l95, 3) if l95 is not None and r95 is not None else None,
            "p95_delta_pct": round((r95-l95)*100/l95, 2) if l95 not in (None, 0) and r95 is not None else None,
            "before_errors": left.get("errors"), "after_errors": right.get("errors"),
            "before_samples": left.get("samples"), "after_samples": right.get("samples")})
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if not mismatches else 2


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    api = sub.add_parser("api", help="Measure discovery against an explicitly controlled HTTP API")
    api.add_argument("--base-url", required=True)
    api.add_argument("--authorized-host", help="Exact approved hostname when target is not loopback")
    api.add_argument("--run-id")
    api.add_argument("--output", type=Path)
    api.add_argument("--database", default="unspecified; set truthfully in run metadata")
    api.add_argument("--server-workers", type=int, default=1)
    api.add_argument("--seed", type=int, default=127)
    api.add_argument("--entity-counts", default="not independently verified; provide seeded quantities")
    api.add_argument("--samples", type=int, default=100)
    api.add_argument("--repetitions", type=int, default=3)
    api.add_argument("--warmup", type=int, default=10)
    api.add_argument("--concurrency", type=int, nargs="+", default=[1, 10, 100])
    api.add_argument("--timeout", type=float, default=10)
    api.add_argument("--error-budget-pct", type=float, default=1)
    api.set_defaults(func=write_run)
    cmp = sub.add_parser("compare", help="Compare two Card 127 JSON runs; reject unlike protocols")
    cmp.add_argument("before", type=Path)
    cmp.add_argument("after", type=Path)
    cmp.add_argument("--output", type=Path, required=True)
    cmp.set_defaults(func=compare)
    args = parser.parse_args()
    if args.command == "api":
        if args.samples < 1 or args.repetitions < 1 or args.warmup < 0 or args.timeout <= 0 or not 0 <= args.error_budget_pct <= 100:
            parser.error("Amostras/timeout inválidos ou orçamento de erro fora de 0..100.")
        if any(level < 1 for level in args.concurrency) or (100 in args.concurrency and args.samples < 100):
            parser.error("Concorrência deve ser positiva; cenário simultâneo de 100 exige ao menos 100 amostras.")
    try:
        result = args.func(args)
        return result if isinstance(result, int) else 0
    except (ValueError, OSError, json.JSONDecodeError) as exc:
        print(f"BLOQUEADO: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
