#!/usr/bin/env python3
"""Unify per-maltster intermediate JSON into data/db/malts.json.

Each maltster's intermediate file (data/maltsters/<maltster>.json) holds raw,
maltster-native fields validated against schema/<maltster>.schema.json. This
script maps those to the canonical schema (schema/malt.schema.json), assigns
categories (lib.malt), and writes the merged, validated database.
"""

import html
import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lib.malt import (
    SCHEMA_PATH,
    classify_category,
    color_to_lovibond,
    extract_to_yield,
    normalize_name,
)

MALTSTERS_DIR = ROOT / "data" / "maltsters"
DB_PATH = ROOT / "data" / "db" / "malts.json"


def load_schema(path: Path):
    with path.open() as f:
        return json.load(f)


def main():
    canonical_validator = Draft202012Validator(load_schema(SCHEMA_PATH))
    malts = []
    errors = []

    files = sorted(MALTSTERS_DIR.glob("*.json"))
    if not files:
        print(
            "no maltster files found in data/maltsters/; "
            "run `make source` then `make <maltster>`",
            file=sys.stderr,
        )
        return 1

    for path in files:
        key = path.stem  # e.g. "briess"
        intermediate_schema = ROOT / "schema" / f"{key}.schema.json"
        int_validator = (
            Draft202012Validator(load_schema(intermediate_schema))
            if intermediate_schema.exists()
            else None
        )

        entries = json.loads(path.read_text())
        for entry in entries:
            if int_validator is not None:
                problems = [e.message for e in int_validator.iter_errors(entry)]
                if problems:
                    errors.append((entry.get("name", "?"), problems))
                    continue

            maltster = entry.get("maltster") or key.title()
            name = html.unescape(normalize_name(maltster, entry.get("name", "")))
            slug = entry.get("slug", "")

            color = color_to_lovibond(maltster, entry)
            yield_fraction = extract_to_yield(maltster, entry)

            malt = {
                "name": name,
                "maltster": maltster,
                "category": classify_category(
                    maltster, name, slug, entry.get("category_hint")
                ),
            }
            if entry.get("description"):
                malt["description"] = html.unescape(entry["description"])
            if entry.get("notes"):
                malt["notes"] = html.unescape(entry["notes"])
            if color is not None:
                malt["color_lovibond"] = color
            if yield_fraction is not None:
                malt["yield_fraction"] = yield_fraction
            if entry.get("sold_out") is not None:
                malt["sold_out"] = entry["sold_out"]

            problems = [e.message for e in canonical_validator.iter_errors(malt)]
            if problems:
                errors.append((name, problems))
                continue

            malts.append(malt)

    if errors:
        for name, problems in errors:
            print(f"validation failed: {name}: {problems}", file=sys.stderr)
        return 1

    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    DB_PATH.write_text(json.dumps(malts, indent=2, ensure_ascii=False) + "\n")

    by_category = {}
    for malt in malts:
        by_category[malt["category"]] = by_category.get(malt["category"], 0) + 1

    print(f"wrote {len(malts)} malts -> {DB_PATH}")
    print("categories:", by_category)
    return 0


if __name__ == "__main__":
    sys.exit(main())
