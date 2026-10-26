#!/usr/bin/env python3
"""Extract Weyermann malts from cached product pages and their spec PDFs.

Each product page (Enfold theme) has an <h2> name, a description block
(<div itemprop="text">) whose first paragraph is the description and whose
"Sensory:" line is the notes, and a link to its `_Specification.pdf`. The spec
PDF's `Parameter | Minimum | Maximum | Unit` table supplies extract, colour
(Lovibond + EBC) and moisture.

Duplicate WooCommerce slugs are collapsed by their shared spec-PDF URL; hops
(no spec PDF), Sour Wort (no colour) and the liquid extracts RME/Sinamar
(Lovibond > 1000) are dropped.
"""

import html
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "data" / "source" / "weyermann"
PDF_DIR = SRC / "pdf"
OUT = ROOT / "data" / "maltsters" / "weyermann.json"

SPEC_HREF_RE = re.compile(r"""href=["']([^"']*_Specification[^"']*\.pdf)["']""", re.I)
H2_RE = re.compile(r"""<h2[^>]*av-special-heading-tag[^>]*>\s*(.*?)\s*</h2>""", re.S)
P_RE = re.compile(r"<p[^>]*>(.*?)</p>", re.S)

PRODUCT_RE = re.compile(r"Product:\s*([^\n]+)")
LOV_RE = re.compile(r"^\s*Color\s*(?:\(Lovibond\))?\s*([\d.,]+)\s*([\d.,]+)\s*Lovibond", re.I | re.M)
EBC_RE = re.compile(r"^\s*Color\s*(?:\(EBC\))?\s*([\d.,]+)\s*([\d.,]+)\s*EBC", re.I | re.M)
EXTRACT_RE = re.compile(r"Extract\s*\(dry substance\)\s*([\d.,]+)", re.I)
MOISTURE_RE = re.compile(r"Moisture\s+content\s*([\d.,]+)", re.I)


def clean(value: str) -> str:
    value = html.unescape(value or "")
    value = re.sub(r"<[^>]+>", " ", value)
    value = value.replace("\xa0", " ")
    return re.sub(r"\s+", " ", value).strip()


def to_num(value: str):
    value = (value or "").replace(",", ".")
    return float(value) if value else None


def strip_brand(name: str) -> str:
    return re.sub(r"^Weyermann®?\s+", "", name, flags=re.I).strip()


def slug_from_pdf(url: str) -> str:
    base = url.rsplit("/", 1)[-1]
    base = re.sub(r"_Specification.*$", "", base, flags=re.I)
    base = re.sub(r"^Weyermann®?\s*[- ]?", "", base, flags=re.I)
    base = base.replace("®", "")
    return re.sub(r"[^a-z0-9]+", "-", base.lower()).strip("-")


def slugify_name(name: str) -> str:
    s = name.lower().replace("®", "")
    return re.sub(r"[^a-z0-9]+", "-", s).strip("-")


def norm_name(name: str) -> str:
    """Dedup key: the same product can appear under slightly different names
    (e.g. "Abbey Malt®" vs "Abbey Malt® (Biscuit Malt)") or at multiple spec
    PDF URLs, so lowercase, drop ® and parentheticals, collapse whitespace."""
    s = name.lower().replace("®", "")
    s = re.sub(r"\([^)]*\)", "", s)
    return re.sub(r"\s+", " ", s).strip()


def extract_description(raw: str):
    """Return (description, notes) from the page's textblock paragraphs.

    The main description block is the one containing a "Sensory:" line; some
    products precede it with a short subtitle block (e.g. "made from dehusked
    barley"), which is skipped.
    """
    blocks = re.findall(
        r"""<div[^>]*avia_textblock[^>]*itemprop="text"[^>]*>(.*?)</div>""", raw, re.S
    )
    best: list[str] = []
    for block in blocks:
        paras = [clean(p) for p in P_RE.findall(block)]
        paras = [p for p in paras if p]
        if any(p.lower().startswith("sensory") for p in paras):
            best = paras
            break
    if not best:
        for block in blocks:
            paras = [clean(p) for p in P_RE.findall(block)]
            paras = [p for p in paras if p]
            if paras:
                best = paras
                break
    sidx = next((i for i, p in enumerate(best) if p.lower().startswith("sensory")), -1)
    if sidx >= 0:
        description = "\n\n".join(best[:sidx])
        notes = re.sub(r"^Sensory\s*:?\s*", "", best[sidx], flags=re.I).strip()
    else:
        description = "\n\n".join(best[:1])
        notes = ""
    return description, notes


def parse_pdf(text: str) -> dict:
    out = {
        "extract_pct": None,
        "moisture_pct": None,
        "color_lovibond_min": None,
        "color_lovibond_max": None,
        "color_ebc_min": None,
        "color_ebc_max": None,
    }
    m = EXTRACT_RE.search(text)
    if m:
        out["extract_pct"] = to_num(m.group(1))
    m = MOISTURE_RE.search(text)
    if m:
        out["moisture_pct"] = to_num(m.group(1))
    m = LOV_RE.search(text)
    if m:
        out["color_lovibond_min"] = to_num(m.group(1))
        out["color_lovibond_max"] = to_num(m.group(2))
    m = EBC_RE.search(text)
    if m:
        out["color_ebc_min"] = to_num(m.group(1))
        out["color_ebc_max"] = to_num(m.group(2))
    return out


def main() -> int:
    if not SRC.exists():
        print(f"error: {SRC} not found; run `make weyermann` first", file=sys.stderr)
        return 1

    entries = []
    seen: set[str] = set()

    for path in sorted(SRC.glob("*.html")):
        if path.name == "_sitemap.html":
            continue
        raw = path.read_text(encoding="utf-8", errors="replace")

        href_m = SPEC_HREF_RE.search(raw)
        if not href_m:
            continue
        pdf_url = href_m.group(1)

        name = ""
        m = H2_RE.search(raw)
        if m:
            name = strip_brand(clean(m.group(1)))

        key = norm_name(name)
        if not key or key in seen:
            continue
        seen.add(key)

        # Distinct products (e.g. "Barke Pilsner Malt" vs "Pilsner Malt") can
        # share one spec PDF filename, so the slug is derived from the name;
        # fall back to the PDF filename only when the name is missing.
        slug = slugify_name(name) if name else slug_from_pdf(pdf_url)
        if not slug:
            continue

        description, notes = extract_description(raw)

        pdf_basename = pdf_url.rsplit("/", 1)[-1]
        pdf_file = PDF_DIR / pdf_basename
        txt_file = PDF_DIR / (pdf_file.stem + ".txt")
        if not txt_file.exists() and pdf_file.exists():
            subprocess.run(
                ["pdftotext", "-layout", str(pdf_file), str(txt_file)], check=False
            )
        if not txt_file.exists():
            continue

        text = txt_file.read_text(encoding="utf-8", errors="replace")
        spec = parse_pdf(text)

        if not name:
            m = PRODUCT_RE.search(text)
            if m:
                name = strip_brand(clean(re.sub(r"\s*Crop:.*$", "", m.group(1))))
        if not name:
            name = slug.replace("-", " ").title()

        lov = [
            v for v in (spec["color_lovibond_min"], spec["color_lovibond_max"]) if v is not None
        ]
        if not lov:
            continue
        if sum(lov) / len(lov) > 1000:
            continue

        entries.append(
            {
                "name": name,
                "slug": slug,
                "maltster": "Weyermann",
                "source_url": pdf_url,
                "description": description,
                "notes": notes,
                "extract_pct": spec["extract_pct"],
                "moisture_pct": spec["moisture_pct"],
                "color_lovibond_min": spec["color_lovibond_min"],
                "color_lovibond_max": spec["color_lovibond_max"],
                "color_ebc_min": spec["color_ebc_min"],
                "color_ebc_max": spec["color_ebc_max"],
            }
        )

    entries.sort(key=lambda e: e["name"].lower())
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(entries, indent=2, ensure_ascii=False) + "\n")
    print(f"wrote {len(entries)} malts -> {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
