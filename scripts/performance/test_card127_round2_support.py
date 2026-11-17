import unittest

from card127_round2_support import RequestLifecycleProbe, bind_error, classify_http_outcome


class RequestLifecycleProbeTests(unittest.TestCase):
    def test_server_request_stays_active_until_response_iterable_is_consumed(self):
        def app(environ, start_response):
            start_response("200 OK", [("Content-Type", "text/plain")])
            return iter((b"first", b"second"))

        probe = RequestLifecycleProbe(app)
        checkpoint = probe.checkpoint()
        response = probe({"REQUEST_METHOD": "GET", "PATH_INFO": "/api/sample/"}, lambda *args: None)
        self.assertEqual(probe.active, 1)
        self.assertEqual([row.path for row in probe.pending_snapshot(checkpoint)], ["/api/sample/"])
        self.assertEqual(next(response), b"first")
        self.assertEqual(probe.active, 1)
        self.assertEqual(list(response), [b"second"])
        self.assertEqual(probe.active, 0)
        record = probe.snapshot()[0]
        self.assertEqual(record.response_bytes, 11)
        self.assertEqual(record.status, 200)
        self.assertEqual(record.outcome, "complete")
        self.assertEqual(probe.pending_snapshot(checkpoint), [])

    def test_only_visitor_bootstrap_401_is_expected(self):
        self.assertEqual(
            classify_http_outcome("/api/usuarios/me/", 401, "visitor_bootstrap"),
            "expected_unauthenticated_bootstrap",
        )
        self.assertEqual(classify_http_outcome("/api/usuarios/me/", 401, "suggestions"), "http_error")
        self.assertEqual(classify_http_outcome("/api/locais/", 503, "suggestions"), "http_error")

    def test_port_error_includes_actionable_loopback_message(self):
        error = bind_error("API local", "127.0.0.1", 8123, OSError("occupied"))
        self.assertIn("127.0.0.1:8123", str(error))
        self.assertIn("--*-port 0", str(error))


if __name__ == "__main__":
    unittest.main()
