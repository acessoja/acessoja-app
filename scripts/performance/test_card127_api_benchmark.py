"""Regression tests for the Card 127 HTTP benchmark and its output files."""

import csv
import io
import json
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import MagicMock, patch
from urllib.error import HTTPError, URLError
from xml.etree import ElementTree

import card127


class Card127ApiBenchmarkTests(unittest.TestCase):
    url = "http://127.0.0.1:8000/api/locais/"

    def test_request_accepts_only_paginated_json(self):
        for body, expected in (
            (b'{"results": [{"id": 1}]}', (200, None, 1)),
            (b'[]', (200, "unexpected_payload", None)),
            (b'{"results": null}', (200, "unexpected_payload", None)),
            (b'not-json', (200, "unexpected_payload", None)),
            (b'\xff', (200, "unexpected_payload", None)),
        ):
            with self.subTest(body=body):
                response = MagicMock()
                response.__enter__.return_value = response
                response.status = 200
                response.read.return_value = body
                with patch.object(card127.urllib.request, "urlopen", return_value=response) as urlopen:
                    elapsed, status, failure, size, count = card127.request_once(self.url, 2)
                self.assertEqual((status, failure, count), expected)
                self.assertEqual(size, len(body))
                self.assertGreaterEqual(elapsed, 0)
                request = urlopen.call_args.args[0]
                self.assertEqual(request.full_url, self.url)
                self.assertEqual(request.get_header("Accept"), "application/json")
                self.assertEqual(urlopen.call_args.kwargs["timeout"], 2)

    def test_request_distinguishes_http_errors_timeouts_and_connection_errors(self):
        for exc, expected in (
            (HTTPError(self.url, 503, "Unavailable", None, io.BytesIO(b"oops")), (503, "http_error", 4, None)),
            (TimeoutError(), (None, "timeout", 0, None)),
            (URLError("connection refused"), (None, "URLError", 0, None)),
        ):
            with self.subTest(exc=type(exc).__name__):
                with patch.object(card127.urllib.request, "urlopen", side_effect=exc):
                    result = card127.request_once(self.url, 2)
                self.assertEqual(result[1:], expected)

    def test_phase_keeps_failures_in_the_sample_count(self):
        outcomes = [
            (10.0, 200, None, 100, 20),
            (20.0, 200, None, 60, 19),
            (30.0, 503, "http_error", 20, None),
            (40.0, None, "timeout", 0, None),
        ]
        with patch.object(card127, "request_once", side_effect=outcomes) as request:
            result = card127.run_phase(self.url, samples=4, concurrency=1, timeout=2)
        self.assertEqual(request.call_count, 4)
        self.assertEqual((result["samples"], result["successes"], result["errors"], result["timeouts"]), (4, 2, 2, 1))
        self.assertEqual(result["http_statuses"], {"200": 2, "503": 1})
        self.assertEqual(result["failure_kinds"], {"http_error": 1, "timeout": 1})
        self.assertEqual((result["p50_ms"], result["p95_ms"]), (25.0, 38.5))
        self.assertEqual(result["payload_bytes_mean"], 45.0)
        self.assertEqual(result["results_per_response"], [19, 20])
        self.assertFalse(result["expected_page_size"])

    def test_api_cli_writes_matching_json_csv_and_svg(self):
        with TemporaryDirectory() as temp:
            output = Path(temp) / "run"
            argv = [
                "card127", "api", "--base-url", "http://127.0.0.1:8000",
                "--output", str(output), "--run-id", "test-127", "--database", "SQLite",
                "--samples", "2", "--repetitions", "2", "--warmup", "1", "--concurrency", "1",
            ]
            outcomes = [
                (50.0, 200, None, 100, 20),  # cold observation
                (60.0, 200, None, 100, 20),  # warmup
                (10.0, 200, None, 100, 20),
                (20.0, 200, None, 100, 20),
                (30.0, 200, None, 100, 20),
                (40.0, None, "timeout", 0, None),
            ]
            with (
                patch.object(sys, "argv", argv),
                patch("subprocess.check_output", return_value="test-sha\n"),
                patch.object(card127, "request_once", side_effect=outcomes) as request,
            ):
                self.assertEqual(card127.main(), 0)
            self.assertEqual(request.call_count, 6)
            summary = json.loads((output / "resumo.json").read_text(encoding="utf-8"))
            protocol = json.loads((output / "ambiente.json").read_text(encoding="utf-8"))
            with (output / "resultados.csv").open(encoding="utf-8-sig", newline="") as handle:
                rows = list(csv.DictReader(handle))
            self.assertEqual(summary["run_id"], "test-127")
            self.assertEqual(summary["sha"], "test-sha")
            self.assertEqual(summary["warmup"], {"requested": 1, "successful": 1})
            self.assertEqual(summary["cold_observation"]["latency_ms"], 50.0)
            self.assertEqual(protocol["network"], "loopback")
            self.assertEqual(protocol["scenarios"], summary["scenarios"])
            self.assertEqual([row["status"] for row in rows], ["EXPLORATORIO", "PASSOU", "FALHOU"])
            self.assertEqual([row["timeouts"] for row in rows], ["0", "0", "1"])
            self.assertEqual(rows[2]["evidencia"], "resumo.json#scenarios[1]")
            chart = ElementTree.parse(output / "p95.svg").getroot()
            self.assertEqual(len(chart.findall("{http://www.w3.org/2000/svg}rect")), 2)

    def test_chart_without_samples_has_no_latency_bars(self):
        with TemporaryDirectory() as temp:
            output = Path(temp) / "empty.svg"
            card127.make_chart({"scenarios": []}, output)
            chart = ElementTree.parse(output).getroot()
        self.assertFalse(chart.findall("{http://www.w3.org/2000/svg}rect"))

    def test_cli_rejects_invalid_samples_and_concurrency(self):
        common = ["card127", "api", "--base-url", "http://127.0.0.1:8000"]
        for invalid in (["--samples", "0"], ["--concurrency", "0"], ["--samples", "99", "--concurrency", "100"]):
            with self.subTest(invalid=invalid), patch.object(sys, "argv", common + invalid):
                with self.assertRaises(SystemExit) as error:
                    card127.main()
                self.assertEqual(error.exception.code, 2)
