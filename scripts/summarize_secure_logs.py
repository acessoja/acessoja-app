"""Aggregate status/latency only. Never echo original log lines or URLs."""
import argparse
import json
import math


def summarize(paths):
    durations, errors, requests, probes, unavailable = [], 0, 0, 0, 0
    for path in paths:
        with open(path, encoding='utf-8') as handle:
            for line in handle:
                if len(line) > 8192:
                    continue
                try:
                    data = json.loads(line)
                except ValueError:
                    continue
                if not isinstance(data, dict):
                    continue
                if data.get('event') == 'http_request':
                    requests += 1
                    errors += int(isinstance(data.get('status'), int) and data['status'] >= 500)
                    value = data.get('duration_ms')
                    if isinstance(value, (int, float)) and math.isfinite(value) and value >= 0:
                        durations.append(value)
                elif data.get('event') == 'readiness_probe':
                    probes += 1
                    unavailable += int(data.get('healthy') is not True)
    durations.sort()
    percentile = durations[min(len(durations) - 1, math.ceil(len(durations) * .95) - 1)] if durations else None
    return {'http_requests': requests, 'server_errors': errors, 'readiness_probes': probes,
            'unavailable_probes': unavailable,
            'latency_p95_ms': percentile,
            'availability_sla': 'not established'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('files', nargs='+')
    print(json.dumps(summarize(parser.parse_args().files), separators=(',', ':')))
