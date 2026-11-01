#!/usr/bin/env python3
"""Serve two compiled entries, measure both in the same real Chrome session."""

import argparse
from contextlib import ExitStack
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import platform
from threading import Thread
from urllib.parse import urlparse


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ["before", "after", "chrome", "report"]:
        p.add_argument("--" + name, required=True, type=Path)
    args = p.parse_args()
    from playwright.sync_api import sync_playwright

    result = {
        "base_commit": "2d3fdd2c7fcc33fb0de3b9a120787173d372a154",
        "platform": platform.platform(),
        "viewport": [1000, 740],
        "scope": "Same release benchmark entry on actual baseline and changed marker code; no tiles/services",
        "rounds": [],
    }

    class Quiet(SimpleHTTPRequestHandler):
        def log_message(self, *values):
            pass

    with ExitStack() as stack:
        for root, port in [(args.before, 8003), (args.after, 8004)]:
            server = ThreadingHTTPServer(("127.0.0.1", port), partial(Quiet, directory=str(root)))
            Thread(target=server.serve_forever, daemon=True).start()
            stack.callback(server.server_close)
            stack.callback(server.shutdown)
        playwright = stack.enter_context(sync_playwright())
        browser = playwright.chromium.launch(
            executable_path=str(args.chrome), headless=True, args=["--no-sandbox", "--disable-dev-shm-usage"]
        )
        stack.callback(browser.close)
        result["browser"] = browser.version
        for number in range(3):
            for version, port in [("before", 8003), ("after", 8004)]:
                with browser.new_context(viewport={"width": 1000, "height": 740}) as context:
                    api, external = [], []

                    def route(value):
                        url = urlparse(value.request.url)
                        if "/api/" in url.path:
                            api.append(url.path)
                        if url.hostname not in ["127.0.0.1", "localhost"]:
                            external.append(url.hostname)
                            value.abort()
                        else:
                            value.continue_()

                    context.route("**/*", route)
                    page = context.new_page()
                    errors = []
                    page.on("pageerror", lambda error: errors.append(str(error)))
                    page.goto(f"http://127.0.0.1:{port}/")
                    page.wait_for_function('typeof window.__mapBenchResult === "string"', timeout=90000)
                    sample = json.loads(page.evaluate("window.__mapBenchResult"))
                    sample.update(
                        {
                            "version": version,
                            "round": number + 1,
                            "api_attempts": len(api),
                            "external_attempts": len(external),
                            "page_errors": errors,
                        }
                    )
                    assert not api and not external and not errors, sample
                    result["rounds"].append(sample)
                    print(f"{version} round {number + 1} complete", flush=True)
                    args.report.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
