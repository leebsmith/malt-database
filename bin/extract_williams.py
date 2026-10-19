#!/usr/bin/env python3
"""Extract candi-syrup data from cached Williams Brewing product pages.

Each page embeds a schema.org Product JSON-LD block whose description contains
the colour (EBC range) and sugar content (Brix range). Brix is used as the
extract/yield percentage; colour is stored in EBC and converted by lib.malt.
"""

import html
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "data" / "source" / "williams"
OUT = ROOT / "data" / "maltsters" / "williams.json"

COLOR_RE = re.compile(r"Color rated at\s*([0-9.]+)\s*-\s*([0-9.]+)\s*EBC", re.I)
BRIX_RE = re.compile(r"([0-9.]+)\s*(?:to|-)\s*([0-9.]+)\s*Brix", re.I)
SIZE_RE = re.compile(r"^\s*\d+\s*(?:Lb|lbs?|pounds?)\.?\s*", re.I)


def clean_text(value: str) -> str:
    value = html.unescape(html.unescape(value))
    value = re.sub(r"<[^>]+>", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def main() -> int:
    if not SRC.exists():
        print(f"error: {SRC} not found; run `make williams` first", file=sys.stderr)
        return 1

    entries = []
    for path in sorted(SRC.glob("*.html")):
        if path.name == "candi-syrups.html":
            continue

        text = path.read_text(encoding="utf-8", errors="replace")
        blocks = re.findall(
            r'<script[^>]+type="application/ld\+json"[^>]*>(.*?)</script>',
            text,
            re.S | re.I,
        )
        product = None
        for block in blocks:
            try:
                obj = json.loads(block, strict=False)
            except json.JSONDecodeError:
                continue
            if isinstance(obj, dict) and obj.get("@type") == "Product":
                product = obj
                break
        if product is None:
            continue

        raw_name = (product.get("name") or "").strip()
        description = clean_text(product.get("description") or "")
        # Fix the source typo "78-5 to 80.5 brix".
        description = re.sub(r"(\d+)-(\d)\b", r"\1.\2", description)
        name = SIZE_RE.sub("", raw_name).strip() or raw_name

        color = COLOR_RE.search(description)
        color_min = float(color.group(1)) if color else None
        color_max = float(color.group(2)) if color else None

        # Normalize a source typo like "78-5 to 80.5 brix" -> "78.5 to 80.5".
        brix_text = re.sub(r"(\d+)-(\d)\b", r"\1.\2", description)
        brix = BRIX_RE.search(brix_text)
        if brix:
            bmin, bmax = float(brix.group(1)), float(brix.group(2))
            extract_pct = round((bmin + bmax) / 2, 2)
        else:
            extract_pct = None

        entries.append(
            {
                "name": name,
                "slug": path.stem,
                "maltster": "Williams Brewing",
                "product_type": "syrup",
                "description": description,
                "extract_pct": extract_pct,
                "color_unit": "ebc" if color_min is not None else None,
                "color_min": color_min,
                "color_max": color_max,
            }
        )

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(entries, indent=2, ensure_ascii=False) + "\n")
    print(f"wrote {len(entries)} syrups -> {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
