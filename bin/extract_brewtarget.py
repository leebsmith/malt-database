#!/usr/bin/env python3
"""Extract sugar ingredients from Brewtarget's SQLite database (GPLv3).

Source: https://github.com/Brewtarget/brewtarget (data/default_db.sqlite).
Only rows with fermentable type "sugar" are used. Brewtarget stores colour in
SRM and extract as fine-grind yield (%).
"""

import json
import re
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / "data" / "source" / "brewtarget" / "default_db.sqlite"
OUT = ROOT / "data" / "maltsters" / "brewtarget.json"


def slugify(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def norm(text: str) -> str:
    text = text.replace("\u00ae", "").replace("\u2122", "")
    return re.sub(r"\s+", " ", text).strip().lower()


def main() -> int:
    if not DB.exists():
        print(f"error: {DB} not found; run `make brewtarget` first", file=sys.stderr)
        return 1

    con = sqlite3.connect(DB)
    con.row_factory = sqlite3.Row
    rows = con.execute(
        """
        select name, fine_grind_yield_pct, color
        from fermentable
        where ftype = 'sugar'
        order by name
        """
    ).fetchall()

    # Deduplicate by name, preferring a row that has both yield and colour.
    best: dict[str, sqlite3.Row] = {}
    for row in rows:
        key = norm(row["name"])
        if key not in best:
            best[key] = row
            continue
        score = lambda r: (r["fine_grind_yield_pct"] is not None) + (
            r["color"] is not None
        )
        if score(row) > score(best[key]):
            best[key] = row

    sugars = []
    for row in best.values():
        name = row["name"].strip()
        ptype = "syrup" if re.search(r"syrup|molasses", name, re.I) else "sugar"
        sugars.append(
            {
                "name": name,
                "slug": slugify(name),
                "maltster": "Brewtarget",
                "product_type": ptype,
                "extract_pct": row["fine_grind_yield_pct"],
                "color_unit": "srm" if row["color"] is not None else None,
                "color_min": row["color"],
                "color_max": row["color"],
            }
        )

    sugars.sort(key=lambda s: s["name"].lower())
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(sugars, indent=2, ensure_ascii=False) + "\n")
    print(f"wrote {len(sugars)} sugars -> {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
