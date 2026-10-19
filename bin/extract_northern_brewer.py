#!/usr/bin/env python3
"""Extract Belgian candi sugars/syrups from Northern Brewer's Shopify JSON.

Excludes products whose vendor is Candi Syrup, Inc. (out of business).
Colour is parsed from the description (EBC range, SRM, or Lovibond) and
yield/extract from PPG (1.032 PPG is assumed for syrups without an explicit
PPG; crystalline/soft sugars default to 46 PPG).
"""

import html
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "data" / "source" / "northern-brewer" / "products.json"
OUT = ROOT / "data" / "maltsters" / "northern-brewer.json"

EXCLUDE_VENDORS = {"Candi Syrup, Inc."}
SIZE_RE = re.compile(r"\s*(?:-\s*)?1\s*lb\.?\s*$", re.I)
EBC_RE = re.compile(r"(\d+(?:\.\d+)?)\s*[–-]\s*(\d+(?:\.\d+)?)\s*EBC", re.I)
SRM_RE = re.compile(r"(\d+(?:\.\d+)?)\s*SRM|SRM\s*(\d+(?:\.\d+)?)", re.I)
LOV_RE = re.compile(r"(\d+(?:\.\d+)?)\s*°L", re.I)
TITLE_LOV_RE = re.compile(r"(\d+(?:\.\d+)?)\s*Lovibond", re.I)
TITLE_D_RE = re.compile(r"D-(\d+)", re.I)
PPG_RE = re.compile(r"([0-9.]+)\s*PPG", re.I)


def clean(value: str) -> str:
    value = html.unescape(value or "")
    value = re.sub(r"<[^>]+>", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def parse_color(title: str, body: str):
    match = EBC_RE.search(body)
    if match:
        return "ebc", float(match.group(1)), float(match.group(2))

    match = SRM_RE.search(body)
    if match:
        value = float(match.group(1) or match.group(2))
        return "srm", value, value

    match = LOV_RE.search(body)
    if match:
        value = float(match.group(1))
        return "lovibond", value, value

    match = TITLE_LOV_RE.search(title)
    if match:
        value = float(match.group(1))
        return "lovibond", value, value

    match = TITLE_D_RE.search(title)
    if match:
        value = float(match.group(1))
        return "srm", value, value

    return None, None, None


def parse_extract(body: str, ptype: str) -> float:
    match = PPG_RE.search(body)
    if match:
        value = float(match.group(1))
        if value < 1.1:  # specific gravity (e.g. 1.032) -> 32 PPG points
            value = (value - 1.0) * 1000
        return round(value / 46 * 100, 2)
    if ptype == "syrup":
        # Candico/CSI-style candi syrups are typically 1.032 PPG = 32 points.
        return round(32 / 46 * 100, 2)
    return 100.0


def main() -> int:
    if not SRC.exists():
        print(f"error: {SRC} not found; run `make northern-brewer` first", file=sys.stderr)
        return 1

    products = json.loads(SRC.read_text())["products"]
    entries = []
    for product in products:
        vendor = (product.get("vendor") or "").strip()
        if vendor in EXCLUDE_VENDORS:
            continue

        title = (product.get("title") or "").strip()
        body = clean(product.get("body_html") or "")
        ptype = "syrup" if "syrup" in title.lower() else "sugar"
        unit, color_min, color_max = parse_color(title, body)
        name = SIZE_RE.sub("", title).strip() or title

        entries.append(
            {
                "name": name,
                "slug": product.get("handle"),
                "maltster": vendor,
                "product_type": ptype,
                "description": body,
                "extract_pct": parse_extract(body, ptype),
                "color_unit": unit,
                "color_min": color_min,
                "color_max": color_max,
            }
        )

    entries.sort(key=lambda e: e["name"].lower())
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(entries, indent=2, ensure_ascii=False) + "\n")
    print(f"wrote {len(entries)} products -> {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
