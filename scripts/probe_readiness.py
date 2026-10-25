"""A bounded probe: no URL/host, body or exception text is emitted into logs."""
import argparse
import json
import os
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen


def probe(url, host=None):
    parsed = urlsplit(url)
    if parsed.scheme not in {"http", "https"} or parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise ValueError("Use an HTTP(S) readiness URL without credentials or query.")
    started = time.monotonic()
    status = 0
    try:
        headers = {"Host": host} if host else {}
        with urlopen(Request(url, headers=headers), timeout=5) as response:
            status = response.status
            payload = json.loads(response.read(256))
            healthy = status == 200 and payload == {"status": "ok"}
    except HTTPError as error:
        status, healthy = error.code, False
    except (OSError, URLError, ValueError):
        healthy = False
    return {"event": "readiness_probe", "status": status, "healthy": healthy,
            "duration_ms": round((time.monotonic() - started) * 1000, 2)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--host", default=os.environ.get("PUBLIC_HOST"))
    args = parser.parse_args()
    result = probe(args.url, args.host)
    print(json.dumps(result, separators=(",", ":")))
    return 0 if result["healthy"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
