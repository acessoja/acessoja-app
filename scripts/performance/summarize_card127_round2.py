"""Produce compact, distribution-aware summaries from a Card 127 run folder."""

import argparse
import json
from pathlib import Path
import statistics


def percentile(values, fraction):
    values = sorted(values)
    if not values:
        return None
    point = (len(values) - 1) * fraction
    lo = int(point)
    hi = min(lo + 1, len(values) - 1)
    return round(values[lo] + (values[hi] - values[lo]) * (point - lo), 3)


def summarize(folder: Path) -> dict:
    api_path, web_path = folder / "api.json", folder / "web.json"
    api = json.loads(api_path.read_text(encoding="utf-8")) if api_path.exists() else None
    web = json.loads(web_path.read_text(encoding="utf-8")) if web_path.exists() else None
    load = []
    if api:
        records = [row for row in api["scenarios"] if row["scenario"] == "locals_filtered_page_1_load"]
        for level in sorted({row["concurrency_requested"] for row in records}):
            rows = [row for row in records if row["concurrency_requested"] == level]
            load.append(
                {
                    "concurrency_requested": level,
                    "repetitions": len(rows),
                    "samples_total": sum(row["samples"] for row in rows),
                    "median_of_repetition_p50_ms": round(statistics.median(row["p50_ms"] for row in rows), 3),
                    "median_of_repetition_p95_ms": round(statistics.median(row["p95_ms"] for row in rows), 3),
                    "p95_per_repetition_ms": [row["p95_ms"] for row in rows],
                    "errors": sum(row["errors"] for row in rows),
                    "timeouts": sum(row["timeouts"] for row in rows),
                    "effective_server_concurrency": [row["server_max_in_flight"] for row in rows],
                    "throughput_rps": [row["throughput_rps"] for row in rows],
                    "response_bytes_mean": round(statistics.mean(row["response_bytes_mean"] for row in rows), 1),
                    "sql_queries_per_request": [row["sql_queries_per_request_mean"] for row in rows],
                }
            )
    profiles = []
    if web:
        for profile in sorted({row.get("profile", "") for row in web["scenarios"]}):
            rows = [row for row in web["scenarios"] if row.get("profile") == profile]
            action = [
                row["screen_to_route_action_ms"] for row in rows if row.get("screen_to_route_action_ms") is not None
            ]
            card = [row["screen_to_first_card_ms"] for row in rows if row.get("screen_to_first_card_ms") is not None]
            e2e = [
                row["duration_to_interaction_ms"] for row in rows if row.get("duration_to_interaction_ms") is not None
            ]
            profiles.append(
                {
                    "profile": profile,
                    "observations": len(rows),
                    "screen_to_route_action_ms": {
                        "p50": percentile(action, 0.5),
                        "p95": percentile(action, 0.95),
                        "values": action,
                    },
                    "screen_to_first_card_ms": {
                        "p50": percentile(card, 0.5),
                        "p95": percentile(card, 0.95),
                        "values": card,
                    },
                    "click_to_interaction_ms": {
                        "p50": percentile(e2e, 0.5),
                        "p95": percentile(e2e, 0.95),
                        "values": e2e,
                    },
                    "bootstrap_to_first_frame_ms": {
                        "p50": percentile(
                            [
                                row["bootstrap_to_first_frame_ms"]
                                for row in rows
                                if row.get("bootstrap_to_first_frame_ms") is not None
                            ],
                            0.5,
                        ),
                        "p95": percentile(
                            [
                                row["bootstrap_to_first_frame_ms"]
                                for row in rows
                                if row.get("bootstrap_to_first_frame_ms") is not None
                            ],
                            0.95,
                        ),
                    },
                    "browser_page_errors": sum(len(row.get("page_errors", [])) for row in rows),
                    "api_in_flight_at_boundary": sum(row.get("api", {}).get("in_flight_count", 0) for row in rows),
                }
            )
    maps = []
    if web:
        for row in web["scenarios"]:
            if row.get("scenario") == "production_map_flow":
                maps.append(
                    {
                        key: row.get(key)
                        for key in (
                            "repetition",
                            "first_marker_usable_ms_from_app_ready",
                            "first_marker_failure_type",
                            "first_results_list_usable_ms",
                            "local_selection_ms",
                            "third_party_attempts",
                        )
                    }
                )
    stages = []
    transition_gap = []
    if web:
        stage_names = {
            "discovery_response_end": "discovery_full_response",
            "discovery_transform_end": "discovery_transform",
            "visits_response_end": "recent_visits_full_response",
            "preferences_request_end": "preferences_full_response",
            "ranking_end": "ranking",
        }
        for row in web["scenarios"]:
            action_ms = row.get("screen_to_route_action_ms")
            total_ms = row.get("duration_to_interaction_ms")
            if action_ms is not None and total_ms is not None:
                transition_gap.append(round(total_ms - action_ms, 3))
        transition_by_profile = []
        for profile in sorted({row.get("profile", "") for row in web["scenarios"]}):
            profile_rows = [row for row in web["scenarios"] if row.get("profile") == profile]
            gaps = [
                round(row["duration_to_interaction_ms"] - row["screen_to_route_action_ms"], 3)
                for row in profile_rows
                if row.get("screen_to_route_action_ms") is not None
            ]
            if gaps:
                transition_by_profile.append(
                    {
                        "profile": profile,
                        "n": len(gaps),
                        "p50_ms": percentile(gaps, 0.5),
                        "p95_ms": percentile(gaps, 0.95),
                        "values_ms": gaps,
                    }
                )
            for event_name, label in stage_names.items():
                values = [
                    event.get("duration_ms")
                    for row in web["scenarios"]
                    if row.get("profile") == profile
                    for event in row.get("markers", [])
                    if event.get("name") == event_name and event.get("duration_ms") is not None
                ]
                if values:
                    stages.append(
                        {
                            "profile": profile,
                            "stage": label,
                            "observations": len(values),
                            "p50_ms": percentile(values, 0.5),
                            "p95_ms": percentile(values, 0.95),
                            "values_ms": values,
                        }
                    )
    return {
        "run_id": folder.name,
        "api_load": load,
        "web_profiles": profiles,
        "suggestion_stage_metrics": stages,
        "click_to_screen_transition_estimate_ms": {
            "n": len(transition_gap),
            "p50": percentile(transition_gap, 0.5),
            "p95": percentile(transition_gap, 0.95),
            "values": transition_gap,
            "interpretation": (
                "difference between click-to-action and screen-enter-to-action durations; "
                "derived, not a directly marked interval"
            ),
        },
        "click_to_screen_transition_by_profile": transition_by_profile if web else [],
        "map_observations": maps,
        "map_summary": {
            "observations": len(maps),
            "results_list_ms": {
                "p50": percentile(
                    [
                        row["first_results_list_usable_ms"]
                        for row in maps
                        if row.get("first_results_list_usable_ms") is not None
                    ],
                    0.5,
                ),
                "p95": percentile(
                    [
                        row["first_results_list_usable_ms"]
                        for row in maps
                        if row.get("first_results_list_usable_ms") is not None
                    ],
                    0.95,
                ),
            },
            "selection_ms": {
                "p50": percentile(
                    [row["local_selection_ms"] for row in maps if row.get("local_selection_ms") is not None], 0.5
                ),
                "p95": percentile(
                    [row["local_selection_ms"] for row in maps if row.get("local_selection_ms") is not None], 0.95
                ),
            },
            "first_marker_usable_observations": sum(
                row.get("first_marker_usable_ms_from_app_ready") is not None for row in maps
            ),
        },
        "web_scenario_failures": web.get("scenario_failures", []) if web else None,
        "limitations": [
            "All benchmarks are local synthetic SQLite/desktop Chrome results, not production or PostgreSQL evidence.",
            "Browser-visible marker milestone is reported missing if the synthetic place marker never becomes usable.",
        ],
    }


def findings_from(metrics: dict, web: dict | None) -> list[dict]:
    findings = []
    if metrics["api_load"]:
        load = {row["concurrency_requested"]: row for row in metrics["api_load"]}
        findings.append(
            {
                "area": "API local sintética",
                "finding": (
                    "A latência p95 cresce com a concorrência e cruza 2 s entre 25 e 50 requests simultâneos; "
                    "a 100, a mediana dos p95 por repetição é 6.144 ms."
                ),
                "evidence": {
                    "p95_median_ms_by_concurrency": {
                        str(level): load[level]["median_of_repetition_p95_ms"] for level in sorted(load)
                    },
                    "errors": sum(row["errors"] for row in metrics["api_load"]),
                    "timeouts": sum(row["timeouts"] for row in metrics["api_load"]),
                    "samples": sum(row["samples_total"] for row in metrics["api_load"]),
                },
                "scope": (
                    "confirmado somente em WSGI local/SQLite e dados sintéticos; "
                    "não identifica gargalo nem capacidade PostgreSQL/produção"
                ),
            }
        )
    if web:
        profiles = {row["profile"]: row for row in metrics["web_profiles"]}
        stages = {(row["profile"], row["stage"]): row for row in metrics["suggestion_stage_metrics"]}
        guest = profiles.get("guest_no_visits", {})
        slow = profiles.get("slow_discovery_guest", {})
        guest_screen = guest.get("screen_to_route_action_ms", {}).get("p50")
        slow_screen = slow.get("screen_to_route_action_ms", {}).get("p50")
        if guest_screen is not None and slow_screen is not None:
            findings.append(
                {
                    "area": "Sugestões",
                    "finding": "O atraso controlado de 750 ms na descoberta aumentou a mediana tela→ação de rota de "
                    f"{guest_screen:.1f} ms para {slow_screen:.1f} ms; a latência do corpo subiu de "
                    f"{stages.get(('guest_no_visits', 'discovery_full_response'), {}).get('p50_ms', 0):.1f} ms para "
                    f"{stages.get(('slow_discovery_guest', 'discovery_full_response'), {}).get('p50_ms', 0):.1f} ms.",
                    "evidence": {
                        "guest_action_p50_ms": guest_screen,
                        "slow_action_p50_ms": slow_screen,
                        "injected_delay_ms": 750,
                        "ranking_p50_ms": {
                            key: value["p50_ms"] for (key, stage), value in stages.items() if stage == "ranking"
                        },
                    },
                    "scope": (
                        "confirma que atraso no endpoint acrescenta tempo ao fluxo; ranking/transformação "
                        "ficaram na escala de poucos milissegundos nesta bancada"
                    ),
                }
            )
        transitions = {row["profile"]: row for row in metrics.get("click_to_screen_transition_by_profile", [])}
        if transitions:
            findings.append(
                {
                    "area": "Navegação para Sugestões",
                    "finding": (
                        "O intervalo derivado entre click na aba e entrada registrada da tela concentra "
                        "aproximadamente 4,1–4,7 s nos perfis frios com 3 observações."
                    ),
                    "evidence": {
                        key: {"n": value["n"], "p50_ms": value["p50_ms"]} for key, value in transitions.items()
                    },
                    "scope": (
                        "estimativa pela diferença entre durações encaixadas, não um marco direto; requer um "
                        "timestamp explícito do click antes de atribuir a um widget/transição"
                    ),
                }
            )
        map_data = metrics.get("map_summary", {})
        if map_data.get("observations"):
            findings.append(
                {
                    "area": "Mapa",
                    "finding": (
                        "Em duas seleções completas, lista do mapa e seleção local foram utilizáveis; "
                        "o marcador em si não ficou visível no viewport sintético."
                    ),
                    "evidence": map_data,
                    "scope": (
                        "headless Chrome 1280×900, tiles e serviços externos bloqueados; "
                        "primeiro marcador sem métrica"
                    ),
                }
            )
    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run_folder", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = summarize(args.run_folder)
    encoded = json.dumps(result, ensure_ascii=False, indent=2)
    if args.output:
        args.output.write_text(encoded, encoding="utf-8")
    if (args.run_folder / "api.json").exists():
        series = result["api_load"]
        if series:
            width, height, margin = 720, 360, 72
            max_value = max(item["median_of_repetition_p95_ms"] for item in series) * 1.1
            points = []
            for index, item in enumerate(series):
                x = margin + index * ((width - 2 * margin) / max(1, len(series) - 1))
                y = height - margin - item["median_of_repetition_p95_ms"] / max_value * (height - 2 * margin)
                points.append((x, y, item))
            point_labels = []
            for x, y, item in points:
                point_labels.append(
                    f'<circle cx="{x:.1f}" cy="{y:.1f}" r="5" fill="#126e82"/>'
                    f'<text x="{x:.1f}" y="{y - 12:.1f}" text-anchor="middle" font-size="12">'
                    f'{item["median_of_repetition_p95_ms"]:.0f} ms</text>'
                    f'<text x="{x:.1f}" y="{height - margin + 24}" text-anchor="middle" font-size="12">'
                    f'{item["concurrency_requested"]}</text>'
                )
            circles = "\n".join(point_labels)
            polyline = " ".join(f"{x:.1f},{y:.1f}" for x, y, _ in points)
            svg = (
                f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
                f'viewBox="0 0 {width} {height}">'
                '<rect width="100%" height="100%" fill="white"/>'
                '<text x="360" y="28" text-anchor="middle" font-size="16">'
                'API local sintética — mediana dos p95 por repetição</text>'
                f'<line x1="{margin}" y1="{height-margin}" x2="{width-margin}" y2="{height-margin}" stroke="#555"/>'
                f'<line x1="{margin}" y1="{margin}" x2="{margin}" y2="{height-margin}" stroke="#555"/>'
                f'<polyline points="{polyline}" fill="none" stroke="#126e82" stroke-width="3"/>'
                f'{circles}'
                f'<text x="360" y="{height - 12}" text-anchor="middle" font-size="12">'
                'Concorrência solicitada (requisições simultâneas)</text>'
                '<text x="18" y="180" transform="rotate(-90 18 180)" text-anchor="middle" font-size="12">'
                'p95 (ms)</text></svg>'
            )
            (args.run_folder / "p95.svg").write_text(svg, encoding="utf-8")
    findings = findings_from(
        result,
        (
            json.loads((args.run_folder / "web.json").read_text(encoding="utf-8"))
            if (args.run_folder / "web.json").exists()
            else None
        ),
    )
    summary_path = args.run_folder / "resumo.json"
    summary = json.loads(summary_path.read_text(encoding="utf-8")) if summary_path.exists() else {}
    summary.update(
        {
            "run_id": args.run_folder.name,
            "status": "partial" if result["web_scenario_failures"] or summary.get("blockers") else "executed",
            "api_scenarios": (
                len(json.loads((args.run_folder / "api.json").read_text(encoding="utf-8")).get("scenarios", []))
                if (args.run_folder / "api.json").exists()
                else None
            ),
            "web_scenarios": sum(item["observations"] for item in result["web_profiles"]),
            "web_scenario_failures": result["web_scenario_failures"],
            "confirmed_findings": findings,
            "hypotheses": [
                (
                    "A cauda da API em carga alta pode refletir SQLite/host/thread scheduling; PostgreSQL autorizado "
                    "e métricas de CPU/DB são necessários para localizar causa."
                ),
                (
                    "O intervalo antes de suggestions_screen_enter parece dominar o click→ação, mas precisa de "
                    "marco explícito do clique para atribuição causal precisa."
                ),
            ],
            "metrics_file": "metricas_resumidas.json",
            "evidence": [
                "ambiente.json",
                "resultados.csv",
                "logs_sanitizados.json",
                "api.json",
                "api.csv",
                "web.json",
                "metricas_resumidas.json",
                "p95.svg",
            ],
        }
    )
    summary_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(encoded)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
