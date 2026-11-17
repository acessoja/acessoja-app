import unittest

from card127_round2_support import RequestRecord
from card127_round2_web import _api_snapshot, _safe_failure_diagnostics, _usable_map_marker


class _Candidate:
    def __init__(self, label, *, visible=True, enabled=True, box=None):
        self.label = label
        self.visible = visible
        self.enabled = enabled
        self.box = box or {"x": 20.0, "y": 30.0, "width": 48.0, "height": 48.0}
        self.trial_clicked = False

    def is_visible(self):
        return self.visible

    def is_enabled(self):
        return self.enabled

    def bounding_box(self):
        return self.box

    def click(self, *, trial, timeout):
        self.trial_clicked = trial

    def get_attribute(self, name):
        return self.label if name == "aria-label" else None

    def inner_text(self):
        return self.label

    def wait_for(self, *, state, timeout):
        if state == "visible" and not self.visible:
            raise TimeoutError("not visible")


class _Locator:
    def __init__(self, candidates):
        self.candidates = candidates

    def count(self):
        return len(self.candidates)

    def nth(self, index):
        return self.candidates[index]

    @property
    def first(self):
        return self.candidates[0] if self.candidates else _Candidate("", visible=False)

    def wait_for(self, *, state, timeout):
        if not self.candidates:
            raise TimeoutError("no candidate")


class _Page:
    def __init__(self, places=(), clusters=(), *, inside=True):
        self.places = _Locator(list(places))
        self.clusters = _Locator(list(clusters))
        self.inside = inside

    def get_by_role(self, role, name):
        if "Card127 Principal" in name.pattern:
            return self.places
        return self.clusters

    def evaluate(self, _script, _box):
        return (
            self.inside and _box["x"] >= 0 and _box["y"] >= 0
            and _box["x"] + _box["width"] <= 1280
            and _box["y"] + _box["height"] <= 900
        )


class _DiagnosticPage:
    def get_by_role(self, *_args, **_kwargs):
        class Tabs:
            def count(self):
                return 0
        return Tabs()

    def evaluate(self, *_args, **_kwargs):
        return []


class _Probe:
    def __init__(self, records):
        self.records = records

    def snapshot(self):
        return self.records

    def pending_snapshot(self, _start):
        return []


class Round3HarnessTests(unittest.TestCase):
    def test_marker_requires_visible_enabled_in_viewport_hit_target(self):
        target = _Candidate("Card127 Principal. Abrir local")
        evidence = _usable_map_marker(_Page(places=[target]), timeout_ms=10)
        self.assertEqual(evidence["marker_kind"], "place")
        self.assertTrue(evidence["hit_testable"])
        self.assertTrue(target.trial_clicked)

    def test_cluster_is_fallback_when_named_place_is_not_visible(self):
        hidden = _Candidate("Card127 Principal", visible=False)
        cluster = _Candidate("12 locais. Abrir agrupamento.")
        evidence = _usable_map_marker(_Page(places=[hidden], clusters=[cluster]), timeout_ms=10)
        self.assertEqual(evidence["marker_kind"], "cluster")
        self.assertTrue(cluster.trial_clicked)

    def test_offscreen_or_disabled_candidates_are_not_measured(self):
        offscreen = _Candidate("Card127 Principal", box={"x": -70, "y": 0, "width": 48, "height": 48})
        disabled = _Candidate("Card127 Principal", enabled=False)
        with self.assertRaisesRegex(RuntimeError, "no_visible_hit_testable_marker"):
            _usable_map_marker(_Page(places=[offscreen, disabled]), timeout_ms=10)

    def test_failure_diagnostics_redact_synthetic_password(self):
        data = _safe_failure_diagnostics(
            _DiagnosticPage(), {"requests": [], "event_counts": {}},
            "login", RuntimeError("bad SyntheticOnly!127"),
        )
        self.assertNotIn("SyntheticOnly!127", data["error_message"])
        self.assertEqual(data["phase"], "login")

    def test_only_pre_login_anonymous_401_is_expected_in_authenticated_flow(self):
        probe = _Probe([
            RequestRecord("GET", "/api/usuarios/me/", 200, 20, sequence=3),
            RequestRecord("POST", "/auth/session/login/", 200, 30, sequence=2),
            RequestRecord("GET", "/api/usuarios/me/", 401, 10, sequence=1),
        ])
        snapshot = _api_snapshot(probe, 0, "map_bootstrap_to_marker")
        me_outcomes = [row["outcome"] for row in snapshot["requests"]
                       if row["path"] == "/api/usuarios/me/"]
        self.assertEqual(me_outcomes, ["expected_unauthenticated_bootstrap", "success"])

    def test_authenticated_401_after_login_is_an_http_error(self):
        probe = _Probe([
            RequestRecord("POST", "/auth/session/login/", 200, 30, sequence=1),
            RequestRecord("GET", "/api/usuarios/me/", 401, 10, sequence=2),
        ])
        snapshot = _api_snapshot(probe, 0, "map_bootstrap_to_marker")
        self.assertEqual(snapshot["requests"][-1]["outcome"], "http_error")
        self.assertEqual(snapshot["http_error_count"], 1)


if __name__ == "__main__":
    unittest.main()
