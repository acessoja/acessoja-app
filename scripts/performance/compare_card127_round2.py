"""Compare Card 127 result folders only when measurement environments match."""

import argparse
import json
from pathlib import Path


def compare(first: Path, second: Path) -> dict:
    left = json.loads((first / "ambiente.json").read_text(encoding="utf-8"))
    right = json.loads((second / "ambiente.json").read_text(encoding="utf-8"))
    checks = {
        "database": (left.get("database"), right.get("database")),
        "flutter": (left.get("flutter"), right.get("flutter")),
        "browser": (left.get("browser"), right.get("browser")),
        "viewport": (left.get("viewport"), right.get("viewport")),
        "cache_state": (left.get("cache_state"), right.get("cache_state")),
        "python": (left.get("python"), right.get("python")),
    }
    differences = {key: {"first": a, "second": b} for key, (a, b) in checks.items() if a != b}
    return {"comparable": not differences, "differences": differences,
            "decision": "compare" if not differences else "comparison_refused_environment_mismatch",
            "first_run": left.get("run_id"), "second_run": right.get("run_id")}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("first", type=Path)
    parser.add_argument("second", type=Path)
    args = parser.parse_args()
    result = compare(args.first, args.second)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["comparable"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
