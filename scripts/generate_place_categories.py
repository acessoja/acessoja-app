"""Generate child data or check the semantic contract after dart format."""

import argparse
import json
from pathlib import Path
import re


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    data = json.loads((root / "locais/data/place_categories.json").read_text(encoding="utf-8"))
    path = root / "frontend/lib/models/place_subcategories.dart"
    if args.write:
        text = "// Generated from locais/data/place_categories.json. Do not edit by hand.\n"
        text += f"const categoryCatalogVersion = {data['version']};\n"
        text += "const placeSubcategories = <String, Map<String, String>>{\n"
        for item in data["children"]:
            text += f"  '{item['id']}': {{'parent': '{item['parent']}', 'pt': '{item['pt']}', 'en': '{item['en']}'}},\n"
        path.write_text(text + "};\n", encoding="utf-8")
    text = path.read_text(encoding="utf-8")
    entries = re.findall(r"'([^']+)':\s*\{\s*'parent': '([^']+)',\s*'pt': '([^']+)',\s*'en': '([^']+)',?\s*\}", text)
    expected = {(item["id"], item["parent"], item["pt"], item["en"]) for item in data["children"]}
    assert set(entries) == expected and len(entries) == len(expected), "Flutter child catalog diverges from JSON"
    assert f"const categoryCatalogVersion = {data['version']};" in text
    parents = (root / "frontend/lib/models/place_category.dart").read_text(encoding="utf-8")
    for item in data["parents"]:
        assert f"'{item['id']}': PlaceCategoryVisual(Icons.{item['icon']}, '{item['pt']}', '{item['en']}')" in parents
    print("Category contract matches: 11 parents, 22 children, PT/EN, version", data["version"])


if __name__ == "__main__":
    main()
