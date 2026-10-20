#!/usr/bin/env python3
"""Quality gate for the unified database.

Usage: check.py [path-to-db]

Checks the canonical DB for structural/range/entity/duplicate problems and
field completeness. Exits non-zero on any failure. Run automatically by
`make check` (and therefore `make db`).
"""

import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DB = ROOT / "data" / "db" / "malts.json"
SCHEMA = ROOT / "schema" / "malt.schema.json"

ENTITY = re.compile(r"&(?:[A-Za-z][A-Za-z0-9]*|#[0-9]+|#x[0-9A-Fa-f]+);")
CATEGORIES = {"BASE", "ROASTED", "CRYSTAL", "ACIDULATED"}

# Conservative completeness floors (fraction of entries that must have a value).
THRESHOLDS = {
    "color_lovibond": 0.90,
    "yield_fraction": 0.80,
    "description": 0.90,
    "notes": 0.65,
}


def norm_name(name: str) -> str:
    name = name.replace("\u00ae", "").replace("\u2122", "")
    return re.sub(r"\s+", " ", name).strip().lower()


def main(argv: list[str]) -> int:
    db_path = Path(argv[1]) if len(argv) > 1 else DEFAULT_DB
    if not db_path.exists():
        print(f"error: {db_path} not found; run `make db`", file=sys.stderr)
        return 1

    raw = json.loads(db_path.read_text())
    if not isinstance(raw, dict) or not isinstance(raw.get("entries"), list):
        print(f"error: {db_path} must be the {schema_version, entries} envelope", file=sys.stderr)
        return 1
    entries = raw["entries"]
    schema_version = raw.get("schema_version")
    if not isinstance(schema_version, int):
        print(f"error: {db_path} is missing an integer schema_version", file=sys.stderr)
        return 1
    validator = Draft202012Validator(json.loads(SCHEMA.read_text()))

    errors: list[str] = []
    seen: dict[tuple[str, str], list[str]] = defaultdict(list)

    for i, m in enumerate(entries):
        label = f"[{i}] {m.get('maltster', '?')} / {m.get('name', '?')}"

        for e in validator.iter_errors(m):
            errors.append(f"{label}: schema: {e.message}")

        name = m.get("name", "")
        if not name.strip():
            errors.append(f"{label}: empty name")

        ptype = m.get("product_type")
        if ptype not in ("malt", "extract", "adjunct", "syrup", "sugar"):
            errors.append(f"{label}: missing/invalid product_type {ptype!r}")

        category = m.get("category")
        if ptype in ("extract", "syrup", "sugar"):
            if category is not None:
                errors.append(
                    f"{label}: {ptype} should not be categorized (got {category!r})"
                )
        elif category not in CATEGORIES:
            errors.append(f"{label}: bad/missing category {category!r}")

        for field in ("name", "description", "notes"):
            val = m.get(field)
            if isinstance(val, str):
                match = ENTITY.search(val)
                if match:
                    errors.append(f"{label}: HTML entity in {field}: {match.group(0)}")

        color = m.get("color_lovibond")
        if color is not None and (
            not isinstance(color, (int, float)) or color < 0 or color > 1000
        ):
            errors.append(f"{label}: colour out of range: {color!r}")

        y = m.get("yield_fraction")
        if y is not None and (
            not isinstance(y, (int, float)) or not (0 < y <= 1)
        ):
            errors.append(f"{label}: yield out of range: {y!r}")

        basis = m.get("yield_basis")
        if y is not None:
            if basis not in ("extract", "fermentability"):
                errors.append(f"{label}: missing/invalid yield_basis {basis!r}")
        elif basis is not None:
            errors.append(f"{label}: yield_basis without yield_fraction")

        seen[(m.get("maltster", ""), norm_name(name))].append(name)

    for (maltster, _key), names in seen.items():
        if len(names) > 1:
            errors.append(f"{maltster}: duplicate name(s): {names}")

    # Completeness floors apply to the core malt dataset; sugar/extract/
    # adjunct/syrup sources are supplementary and often lack descriptions.
    core = [m for m in entries if m.get("product_type") == "malt"]
    n = len(core)
    print(f"checked {len(entries)} entries ({n} malts) in {db_path}")
    for field, floor in THRESHOLDS.items():
        have = sum(1 for m in core if m.get(field) not in (None, ""))
        frac = have / n if n else 0.0
        ok = frac >= floor
        print(
            f"  malt {field:16} {have:4}/{n}  {frac * 100:5.1f}%  "
            f"(floor {floor * 100:.0f}%)  {'ok' if ok else 'LOW'}"
        )
        if not ok:
            errors.append(
                f"completeness: {field} {frac * 100:.1f}% < {floor * 100:.0f}%"
            )

    # Moisture is reported for information only (many sources omit it; syrups/
    # sugars often have none), so there is deliberately no completeness floor.
    moisture_have = sum(1 for m in core if m.get("moisture") is not None)
    mfrac = moisture_have / n if n else 0.0
    print(
        f"  malt moisture      {moisture_have:4}/{n}  {mfrac * 100:5.1f}%  "
        f"(informational)"
    )

    if errors:
        for err in errors:
            print(f"FAIL: {err}", file=sys.stderr)
        print(f"quality check failed: {len(errors)} problem(s)", file=sys.stderr)
        return 1

    basis_counts = Counter(
        m["yield_basis"] for m in entries if m.get("yield_basis")
    )
    ptype_counts = Counter(
        m["product_type"] for m in entries if m.get("product_type")
    )
    print(f"  yield_basis     {dict(basis_counts)}")
    print(f"  product_type    {dict(ptype_counts)}")
    print("quality check passed")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
