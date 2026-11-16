"""Shared, privacy-conscious lifecycle instrumentation for Card 127 round two."""

from __future__ import annotations

from dataclasses import dataclass, field
import threading
import time
from typing import Callable, Iterable


@dataclass
class RequestRecord:
    method: str
    path: str
    status: int | None = None
    duration_ms: float | None = None
    response_bytes: int = 0
    sql_queries: int | None = None
    outcome: str = "in_flight"
    sequence: int = -1


class RequestLifecycleProbe:
    """Counts a WSGI request through full iterable consumption/close."""

    def __init__(self, app: Callable, query_count: Callable[[], int] | None = None,
                 on_finish: Callable[[], None] | None = None):
        self.app = app
        self.query_count = query_count
        self.on_finish = on_finish
        self.lock = threading.Lock()
        self.active = 0
        self.maximum = 0
        self.records: list[RequestRecord] = []
        self.pending: dict[int, RequestRecord] = {}
        self.total_started = 0

    def __call__(self, environ, start_response):
        before_queries = self.query_count() if self.query_count else None
        started = time.perf_counter()
        with self.lock:
            sequence = self.total_started
            self.total_started += 1
            record = RequestRecord(environ.get("REQUEST_METHOD", "?"),
                                   environ.get("PATH_INFO", ""), sequence=sequence)
            self.active += 1
            self.maximum = max(self.maximum, self.active)
            self.pending[id(record)] = record

        def capture_status(status, headers, exc_info=None):
            try:
                record.status = int(status.split(" ", 1)[0])
            except (ValueError, AttributeError):
                record.status = None
            return start_response(status, headers, exc_info)

        try:
            response: Iterable[bytes] = self.app(environ, capture_status)
        except BaseException:
            self._finish(record, started, before_queries, "application_error")
            raise

        def consume():
            outcome = "complete"
            try:
                for chunk in response:
                    record.response_bytes += len(chunk)
                    yield chunk
            except BaseException:
                outcome = "stream_error"
                raise
            finally:
                close = getattr(response, "close", None)
                try:
                    if close is not None:
                        close()
                finally:
                    self._finish(record, started, before_queries, outcome)

        return consume()

    def _finish(self, record, started, before_queries, outcome):
        record.duration_ms = round((time.perf_counter() - started) * 1000, 3)
        record.sql_queries = (
            self.query_count() - before_queries
            if self.query_count is not None and before_queries is not None
            else None
        )
        record.outcome = outcome
        with self.lock:
            self.active -= 1
            self.records.append(record)
            self.pending.pop(id(record), None)
        if self.on_finish is not None:
            self.on_finish()

    def wait_idle(self, timeout: float = 5) -> bool:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            with self.lock:
                if self.active == 0:
                    return True
            time.sleep(0.01)
        with self.lock:
            return self.active == 0

    def reset(self):
        with self.lock:
            if self.active:
                raise RuntimeError(f"cannot reset probe with {self.active} requests in flight")
            self.maximum = 0
            self.records.clear()

    def snapshot(self):
        with self.lock:
            return list(self.records)

    def pending_snapshot(self, start_sequence: int = 0):
        with self.lock:
            return [record for record in self.pending.values()
                    if record.sequence >= start_sequence]

    def checkpoint(self) -> int:
        with self.lock:
            return self.total_started

    def reset_maximum(self):
        with self.lock:
            if self.active:
                raise RuntimeError(f"cannot reset maximum with {self.active} requests in flight")
            self.maximum = 0

    def query_metrics(self):
        rows = self.snapshot()
        counts = [row.sql_queries for row in rows if row.sql_queries is not None]
        return {
            "requests_completed": len(rows),
            "requests_with_sql_probe": len(counts),
            "queries_total": sum(counts),
            "queries_per_request_max": max(counts, default=None),
            "queries_per_request_mean": round(sum(counts) / len(counts), 2) if counts else None,
            "request_body_bytes_total": sum(row.response_bytes for row in rows),
            "note": "SQLite/DEBUG query logging; response iterable fully consumed; not PostgreSQL EXPLAIN evidence.",
        }


def classify_http_outcome(path: str, status: int | None, phase: str) -> str:
    """Keep the documented visitor bootstrap 401 separate from API failures."""
    if path == "/api/usuarios/me/" and status == 401 and phase == "visitor_bootstrap":
        return "expected_unauthenticated_bootstrap"
    if status is None:
        return "transport_error"
    if 200 <= status < 300:
        return "success"
    return "http_error"


@dataclass
class ScenarioState:
    name: str = "normal"
    artificial_delay_ms: int = 0
    forced_status: int | None = None
    empty_results: bool = False
    lock: threading.Lock = field(default_factory=threading.Lock)

    def set(self, name: str, *, artificial_delay_ms=0, forced_status=None, empty_results=False):
        with self.lock:
            self.name = name
            self.artificial_delay_ms = artificial_delay_ms
            self.forced_status = forced_status
            self.empty_results = empty_results

    def get(self):
        with self.lock:
            return self.name, self.artificial_delay_ms, self.forced_status, self.empty_results


def bind_error(label: str, host: str, port: int, error: OSError) -> RuntimeError:
    return RuntimeError(
        f"Não foi possível iniciar {label} em {host}:{port}. "
        "Porta ocupada ou indisponível; use --*-port 0 para uma porta dinâmica. "
        f"Detalhe: {type(error).__name__}"
    )
