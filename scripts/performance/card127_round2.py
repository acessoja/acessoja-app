"""Run the Card 127 round two synthetic API and browser benchmarks."""

from __future__ import annotations

import argparse
import csv
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import uuid


def _run(command: list[str], cwd: Path, timeout: int) -> dict:
    try:
        completed = subprocess.run(command, cwd=cwd, text=True, capture_output=True, timeout=timeout)
        is_partial_result = completed.returncode == 2 and any(
            line.startswith("Web Card 127: partial") for line in completed.stdout.splitlines()
        )
        status = "executed" if completed.returncode == 0 else ("partial" if is_partial_result else "failed")
        return {
            "status": status,
            "exit_code": completed.returncode,
            "stdout_tail": completed.stdout[-1200:] if status in {"partial", "failed"} else "",
            "stderr_line_count": len(completed.stderr.splitlines()),
            "stderr_tail": completed.stderr[-4000:] if status == "failed" else "",
            "stderr_classes": {
                "expected_unauthorized": sum(
                    line.startswith("Unauthorized:") for line in completed.stderr.splitlines()
                ),
                "geographic_stub": sum(line.startswith("geographic ") for line in completed.stderr.splitlines()),
            },
        }
    except (OSError, subprocess.TimeoutExpired) as error:
        return {"status": "blocked", "exit_code": None, "error_type": type(error).__name__, "message": str(error)[:500]}


def _rows(run_id: str, api: dict | None, web: dict | None, statuses: dict) -> list[dict]:
    rows = []
    if api:
        for record in api.get("scenarios", []):
            rows.append(
                {
                    "run_id": run_id,
                    "suite": "api",
                    "scenario": record["scenario"],
                    "profile": record["profile"],
                    "milestone": "full_response",
                    "repetition": record["repetition"],
                    "samples": record["samples"],
                    "p50_ms": record["p50_ms"],
                    "p95_ms": record["p95_ms"],
                    "throughput_rps": record["throughput_rps"],
                    "errors": record["errors"],
                    "effective_concurrency": record["server_max_in_flight"],
                    "status": "executed",
                    "evidence": "api.json#scenarios",
                }
            )
    if web:
        for record in web.get("scenarios", []):
            profile = record.get("profile", "map")
            repetition = record.get("repetition", "")
            metrics = [
                ("suggestions_to_route_action", record.get("duration_to_interaction_ms")),
                ("screen_to_first_card", record.get("screen_to_first_card_ms")),
                ("screen_to_route_action", record.get("screen_to_route_action_ms")),
                ("map_first_marker_from_main_screen", record.get("first_marker_usable_ms_from_app_ready")),
                ("map_results_list_usable", record.get("first_results_list_usable_ms")),
                ("map_local_selection", record.get("local_selection_ms")),
            ]
            for milestone, value in metrics:
                if value is not None:
                    rows.append(
                        {
                            "run_id": run_id,
                            "suite": "web",
                            "scenario": record.get("scenario"),
                            "profile": profile,
                            "milestone": milestone,
                            "repetition": repetition,
                            "samples": 1,
                            "p50_ms": value,
                            "p95_ms": value,
                            "throughput_rps": None,
                            "errors": len(record.get("page_errors", [])),
                            "effective_concurrency": None,
                            "status": "executed",
                            "evidence": "web.json#scenarios",
                        }
                    )
    for suite, state in statuses.items():
        if state["status"] != "executed":
            rows.append(
                {
                    "run_id": run_id,
                    "suite": suite,
                    "scenario": "suite_execution",
                    "profile": "local_synthetic",
                    "milestone": "not_measured",
                    "repetition": "",
                    "samples": "",
                    "p50_ms": "",
                    "p95_ms": "",
                    "throughput_rps": "",
                    "errors": "",
                    "effective_concurrency": "",
                    "status": state["status"],
                    "evidence": f"logs_sanitizados.json#{suite}",
                }
            )
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chrome", type=Path, required=True)
    parser.add_argument("--flutter", default="flutter")
    parser.add_argument("--repetitions", type=int, default=3)
    parser.add_argument("--route-samples", type=int, default=25)
    parser.add_argument("--concurrency-samples", type=int, default=100)
    parser.add_argument("--web-only", action="store_true")
    parser.add_argument("--api-only", action="store_true")
    parser.add_argument(
        "--reuse-api-report", type=Path, help="reuse a completed local API run; records source provenance"
    )
    parser.add_argument("--smoke", action="store_true", help="web smoke mode; do not use for baseline")
    args = parser.parse_args()
    if args.api_only and args.web_only:
        parser.error("--api-only e --web-only são incompatíveis")
    if args.reuse_api_report and (args.api_only or args.web_only):
        parser.error("--reuse-api-report exige execução combinada e não aceita --api-only/--web-only")
    root = Path(__file__).resolve().parents[2]
    report_root = root / "reports/performance"
    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-r2-" + uuid.uuid4().hex[:6]
    report_dir = report_root / run_id
    report_dir.mkdir(parents=True, exist_ok=False)
    statuses = {}
    api = web = None
    logs = {
        "run_id": run_id,
        "commands": [],
        "note": "Only bounded command output; no request payloads, credentials or user data.",
    }

    api_source_run_id = None
    if args.reuse_api_report:
        source = args.reuse_api_report.resolve()
        if not (source / "api.json").is_file() or not (source / "api.csv").is_file():
            parser.error("--reuse-api-report precisa conter api.json e api.csv")
        api = json.loads((source / "api.json").read_text(encoding="utf-8"))
        api_source_run_id = api.get("run_id", source.name)
        shutil.copy2(source / "api.json", report_dir / "api.json")
        shutil.copy2(source / "api.csv", report_dir / "api.csv")
        statuses["api"] = {
            "status": "executed",
            "mode": "reused_unchanged_raw_evidence",
            "source_run_id": api_source_run_id,
        }
        logs["commands"].append(
            {
                "suite": "api",
                "status": "reused_unchanged_raw_evidence",
                "source_run_id": api_source_run_id,
                "source_folder": str(source),
            }
        )
    elif not args.web_only:
        cmd = [
            sys.executable,
            str(Path(__file__).with_name("card127_round2_api.py")),
            "--report",
            str(report_dir),
            "--repetitions",
            str(args.repetitions),
            "--route-samples",
            str(args.route_samples),
            "--concurrency-samples",
            str(args.concurrency_samples),
        ]
        state = _run(cmd, root, 900)
        statuses["api"] = state
        logs["commands"].append({"suite": "api", "argv": cmd, **state})
        path = report_dir / "api.json"
        if path.exists():
            api = json.loads(path.read_text(encoding="utf-8"))

    if not args.api_only:
        cmd = [
            sys.executable,
            str(Path(__file__).with_name("card127_round2_web.py")),
            "--report",
            str(report_dir),
            "--chrome",
            str(args.chrome),
            "--flutter",
            args.flutter,
            "--repetitions",
            str(args.repetitions),
        ]
        if args.smoke:
            cmd.append("--smoke")
        state = _run(cmd, root, 1200)
        statuses["web"] = state
        logs["commands"].append({"suite": "web", "argv": cmd, **state})
        path = report_dir / "web.json"
        if path.exists():
            web = json.loads(path.read_text(encoding="utf-8"))

    try:
        flutter_version = subprocess.run(
            [args.flutter, "--version", "--machine"],
            cwd=root / "frontend",
            text=True,
            capture_output=True,
            timeout=30,
            check=False,
        )
        flutter_meta = json.loads(flutter_version.stdout) if flutter_version.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError):
        flutter_meta = None
    try:
        import django
        import rest_framework

        backend_meta = {"django": django.get_version(), "drf": rest_framework.VERSION}
    except Exception:
        backend_meta = None
    sha = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
    environment = {
        "run_id": run_id,
        "collected_at_utc": datetime.now(timezone.utc).isoformat(),
        "git_sha": sha,
        "branch": subprocess.check_output(["git", "branch", "--show-current"], cwd=root, text=True).strip(),
        "platform": platform.platform(),
        "python": platform.python_version(),
        "hardware": {"logical_cpu_count": os.cpu_count(), "processor": platform.processor() or None},
        "backend": backend_meta,
        "flutter": flutter_meta,
        "database": "disposable SQLite only for executed local synthetic suites; authorized PostgreSQL unavailable",
        "synthetic_seed": 127,
        "api_workers": "ThreadedWSGI loopback, observed concurrency recorded per request batch",
        "browser": web.get("browser_version") if web else None,
        "viewport": web.get("viewport") if web else None,
        "cache_state": "new Chrome context per cold scenario; separate same-context warm reopen",
        "android_device": None,
        "network": "loopback; outbound browser requests blocked",
        "api_source_run_id": api_source_run_id,
        "statuses": statuses,
    }
    (report_dir / "ambiente.json").write_text(json.dumps(environment, ensure_ascii=False, indent=2), encoding="utf-8")
    (report_dir / "logs_sanitizados.json").write_text(json.dumps(logs, ensure_ascii=False, indent=2), encoding="utf-8")
    rows = _rows(run_id, api, web, statuses)
    fields = [
        "run_id",
        "suite",
        "scenario",
        "profile",
        "milestone",
        "repetition",
        "samples",
        "p50_ms",
        "p95_ms",
        "throughput_rps",
        "errors",
        "effective_concurrency",
        "status",
        "evidence",
    ]
    with (report_dir / "resultados.csv").open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)

    blockers = []
    if not os.environ.get("DATABASE_URL"):
        blockers.append(
            "PostgreSQL homologado BLOQUEADO: DATABASE_URL autorizada ausente; nenhuma credencial foi inferida."
        )
    blockers.append("Android físico BLOQUEADO: adb/dispositivo não disponível nesta bancada.")
    blockers.append("Critérios literais CA127-01…08 não estavam anexados; confirmar com a equipe.")
    summary = {
        "run_id": run_id,
        "status": "partial" if blockers or any(v["status"] != "executed" for v in statuses.values()) else "executed",
        "suite_status": statuses,
        "api_scenarios": len(api.get("scenarios", [])) if api else None,
        "web_scenarios": len(web.get("scenarios", [])) if web else None,
        "confirmed_findings": [],
        "hypotheses": [
            (
                "Longa espera de primeira interação pode incluir build/runtime/renderização; "
                "os marcos R2 devem separar as parcelas observadas."
            ),
            (
                "Cauda de latência em concorrência alta precisa ser reproduzida em PostgreSQL "
                "autorizado antes de atribuir causa."
            ),
        ],
        "blockers": blockers,
        "historical_baseline_preserved": True,
        "api_source_run_id": api_source_run_id,
        "comparison_policy": (
            "Não comparar esta rodada sintética SQLite/Chrome às métricas históricas de "
            "ambiente/configuração diferentes sem confirmar protocolo e ferramenta."
        ),
        "evidence": ["ambiente.json", "resultados.csv", "logs_sanitizados.json", "api.json", "api.csv", "web.json"],
    }
    (report_dir / "resumo.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(report_dir)
    return 0 if all(v["status"] == "executed" for v in statuses.values()) else 2


if __name__ == "__main__":
    raise SystemExit(main())
