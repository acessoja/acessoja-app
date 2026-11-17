"""Focused unit checks for the Card 127 measurement helpers (no app test suite)."""

import json
from pathlib import Path
import tempfile
import unittest
from argparse import Namespace

import card127


class Card127HelpersTest(unittest.TestCase):
    def test_percentiles_interpolate_and_empty_is_null(self):
        self.assertEqual(card127.percentile([10, 20, 30, 40], 0.95), 38.5)
        self.assertIsNone(card127.percentile([], 0.95))

    def test_remote_target_needs_exact_explicit_host(self):
        with self.assertRaises(ValueError):
            card127.validate_target("http://192.0.2.10:8000", None)
        self.assertEqual(
            card127.validate_target("http://192.0.2.10:8000", "192.0.2.10"),
            "http://192.0.2.10:8000",
        )

    def test_comparator_reports_delta_and_rejects_different_protocols(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            before_dir, after_dir = root / "before", root / "after"
            before_dir.mkdir()
            after_dir.mkdir()
            data = {
                "scenarios": [{"concurrency_requested": 1, "repetition": 1, "p95_ms": 100, "errors": 0, "samples": 100}]
            }
            for folder, summary in (
                (before_dir, data),
                (after_dir, {"scenarios": [{**data["scenarios"][0], "p95_ms": 80}]}),
            ):
                (folder / "resumo.json").write_text(json.dumps(summary), encoding="utf-8")
                environment = {
                    "database": "PostgreSQL 16",
                    "server_workers": 4,
                    "network": "loopback",
                    "warmup_requests": 10,
                    "samples_per_phase": 100,
                    "concurrency_levels": [1],
                    "synthetic_dataset": {"seed": 127},
                    "route": "/api/locais/",
                    "instrumentation_sha256": "same",
                }
                (folder / "ambiente.json").write_text(json.dumps(environment), encoding="utf-8")
            output = root / "comparison.json"
            self.assertEqual(
                card127.compare(
                    Namespace(before=before_dir / "resumo.json", after=after_dir / "resumo.json", output=output)
                ),
                0,
            )
            comparison = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(comparison["scenarios"][0]["p95_delta_ms"], -20)
            changed = json.loads((after_dir / "ambiente.json").read_text(encoding="utf-8"))
            changed["database"] = "SQLite"
            (after_dir / "ambiente.json").write_text(json.dumps(changed), encoding="utf-8")
            self.assertEqual(
                card127.compare(
                    Namespace(before=before_dir / "resumo.json", after=after_dir / "resumo.json", output=output)
                ),
                2,
            )


if __name__ == "__main__":
    unittest.main()
