"""Shared helpers for the malt database toolchain.

The category classification here is hand-curated ("discover once"): when a
new maltster is added, its keyword rules and slug overrides are written once
and committed, then simply looked up at build time. Nothing is discovered
dynamically.

Normalization (raw intermediate -> canonical) is also per-maltster, since each
maltster reports colour/extract in different units (Briess: SRM + yield%/
fermentability%; Bairds: an SRM range + extract%).
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCHEMA_PATH = ROOT / "schema" / "malt.schema.json"

CANONICAL_CATEGORIES = ("BASE", "ROASTED", "CRYSTAL", "ACIDULATED")

# Ordered keyword rules. First match wins. Applied to "slug name" lowercased.
KEYWORD_RULES = (
    ("ACIDULATED", ("acidulated", "acid malt", "sauermalz")),
    ("ROASTED", ("black", "roast", "chocolate", "midnight", "blackprinz", "roasted")),
    ("CRYSTAL", ("caramel", "cara", "crystal", "carapils", "honey malt")),
)

# Per-maltster slug -> canonical category overrides for names the keyword
# rules get wrong or cannot disambiguate.
CATEGORY_MAP = {
    "briess": {
        "extra-special-malt": "ROASTED",
        "victory-malt": "ROASTED",
        "organic-victory-malt": "ROASTED",
    },
    "bairds": {
        "amber-malt": "ROASTED",
        "brown-malt": "ROASTED",
        "dextrin-malt": "CRYSTAL",
    },
    "simpsons": {
        "amber-malt": "ROASTED",
        "brown-malt": "ROASTED",
        "export-pale-brown": "ROASTED",
        "dextrin-malt": "CRYSTAL",
        "simpsons-drc": "CRYSTAL",
    },
    "fawcett": {
        "dextrin-malt": "CRYSTAL",
    },
    "great western": {
        "brumalt": "CRYSTAL",
        "dextra-pils": "CRYSTAL",
        "biscuit-rye-malt": "ROASTED",
        "mela-malt": "ROASTED",
    },
    "bestmalz": {
        "best-biscuit": "ROASTED",
        "best-melanoidin": "ROASTED",
        "best-melanoidin-light": "ROASTED",
        "best-red-x": "CRYSTAL",
        "best-special-x": "ROASTED",
        "best-rostaed-wheat-medium": "ROASTED",
    },
    "dingemans": {
        "aroma-100-md": "ROASTED",
        "aroma-150-md": "ROASTED",
        "melanoidin-md": "ROASTED",
        "amber-aromatic%C2%AE-md": "ROASTED",
        "organic-biscuit%C2%AE-md": "ROASTED",
        "organic-mroost-1400-md": "ROASTED",
    },
    "crisp": {
        "amber-malt": "ROASTED",
        "brown-malt": "ROASTED",
        "dextrin-malt": "CRYSTAL",
        "06-smooth-coffee": "ROASTED",
    },
}

# Per-maltster category headings -> canonical category. Used when the catalog
# page groups products under headings (e.g. Fawcett's h2 "Base Malts").
CATEGORY_HINT_MAP = {
    "fawcett": {
        "base malts": "BASE",
        "crystal malts": "CRYSTAL",
        "roast malts": "ROASTED",
        "specialty malts": "BASE",
    },
    "dingemans": {
        "kilned malts": "BASE",
        "caramalised malts": "CRYSTAL",
        "roasted malts": "ROASTED",
    },
    "canada malting": {
        "base malts": "BASE",
        "specialty malts": "BASE",
        "adjunct grains": "BASE",
        "other": "BASE",
    },
}


def classify_category(
    maltster: str, name: str, slug: str, hint: str | None = None
) -> str:
    maltster = (maltster or "").lower()
    overrides = CATEGORY_MAP.get(maltster, {})
    if slug in overrides:
        return overrides[slug]
    if hint:
        hinted = CATEGORY_HINT_MAP.get(maltster, {}).get(hint.strip().lower())
        if hinted:
            return hinted
    text = f"{slug} {name}".lower()
    for category, keywords in KEYWORD_RULES:
        if any(keyword in text for keyword in keywords):
            return category
    return "BASE"


def normalize_name(maltster: str, name: str) -> str:
    """Canonicalize a raw name. Bairds displays titles in title case via CSS
    but stores mixed-case text in the DOM (e.g. "Maris Otter BLEnd"), so
    title-casing recovers the intended name."""
    if (maltster or "").lower() == "bairds":
        return name.title()
    return name


# --- Raw intermediate -> canonical normalization -------------------------


def _briess_color(entry: dict) -> float | None:
    # Briess "SRM" values already match their Lovibond product naming.
    return entry.get("color_srm")


def _bairds_color(entry: dict) -> float | None:
    vals = [
        v
        for v in (entry.get("color_srm_min"), entry.get("color_srm_max"))
        if v is not None
    ]
    if not vals:
        return None
    return round(sum(vals) / len(vals), 2)


def _briess_yield(entry: dict) -> float | None:
    extract = entry.get("yield_on_grind")
    if extract is None:
        extract = entry.get("fermentability")
    return round(extract / 100, 4) if extract is not None else None


def _bairds_yield(entry: dict) -> float | None:
    extract = entry.get("extract_pct")
    return round(extract / 100, 4) if extract is not None else None


def _simpsons_color(entry: dict) -> float | None:
    # Simpsons ASBC tab already reports Lovibond; collapse the range to a
    # midpoint (single values have min == max).
    vals = [
        v
        for v in (entry.get("color_lovibond_min"), entry.get("color_lovibond_max"))
        if v is not None
    ]
    if not vals:
        return None
    return round(sum(vals) / len(vals), 2)


def _simpsons_yield(entry: dict) -> float | None:
    extract = entry.get("extract_pct")
    return round(extract / 100, 4) if extract is not None else None


def _fawcett_color(entry: dict) -> float | None:
    # Prefer ASBC Lovibond; fall back to EBC (converted) when ASBC is absent.
    vals = [
        v
        for v in (entry.get("color_min"), entry.get("color_max"))
        if v is not None
    ]
    if not vals:
        return None
    value = sum(vals) / len(vals)
    if (entry.get("color_unit") or "").lower() == "ebc":
        value *= 0.508  # EBC -> ~Lovibond (SRM ~= Lovibond)
    return round(value, 2)


def _fawcett_yield(entry: dict) -> float | None:
    extract = entry.get("extract_pct")
    return round(extract / 100, 4) if extract is not None else None


def _gambrinus_color(entry: dict) -> float | None:
    # Prefer Lovibond; SRM passes through (~Lovibond); EBC is converted.
    vals = [
        v
        for v in (entry.get("color_min"), entry.get("color_max"))
        if v is not None
    ]
    if not vals:
        return None
    value = sum(vals) / len(vals)
    if (entry.get("color_unit") or "").lower() == "ebc":
        value *= 0.508
    return round(value, 2)


def _gambrinus_yield(entry: dict) -> float | None:
    extract = entry.get("extract_pct")
    return round(extract / 100, 4) if extract is not None else None


def _great_western_color(entry: dict) -> float | None:
    vals = [
        v
        for v in (entry.get("color_min"), entry.get("color_max"))
        if v is not None
    ]
    if not vals:
        return None
    value = sum(vals) / len(vals)
    if (entry.get("color_unit") or "").lower() == "ebc":
        value *= 0.508
    return round(value, 2)


def _great_western_yield(entry: dict) -> float | None:
    extract = entry.get("extract_pct")
    return round(extract / 100, 4) if extract is not None else None


def _bestmalz_color(entry: dict) -> float | None:
    vals = [
        v
        for v in (entry.get("color_min"), entry.get("color_max"))
        if v is not None
    ]
    if not vals:
        return None
    value = sum(vals) / len(vals)
    if (entry.get("color_unit") or "").lower() == "ebc":
        value *= 0.508
    return round(value, 2)


def _bestmalz_yield(entry: dict) -> float | None:
    extract = entry.get("extract_pct")
    return round(extract / 100, 4) if extract is not None else None


def _dingemans_color(entry: dict) -> float | None:
    value = entry.get("color_value")
    if value is None:
        return None
    if (entry.get("color_unit") or "").lower() == "ebc":
        value *= 0.508
    return round(value, 2)


def _dingemans_yield(entry: dict) -> float | None:
    extract = entry.get("extract_pct")
    return round(extract / 100, 4) if extract is not None else None


def _canada_malting_color(entry: dict) -> float | None:
    vals = [
        v
        for v in (entry.get("color_min"), entry.get("color_max"))
        if v is not None
    ]
    if not vals:
        return None
    value = sum(vals) / len(vals)
    if (entry.get("color_unit") or "").lower() == "ebc":
        value *= 0.508
    return round(value, 2)


def _canada_malting_yield(entry: dict) -> float | None:
    extract = entry.get("extract_pct")
    return round(extract / 100, 4) if extract is not None else None


def _crisp_color(entry: dict) -> float | None:
    vals = [
        v
        for v in (entry.get("color_min"), entry.get("color_max"))
        if v is not None
    ]
    if not vals:
        return None
    value = sum(vals) / len(vals)
    if (entry.get("color_unit") or "").lower() == "ebc":
        value *= 0.508
    return round(value, 2)


def _crisp_yield(entry: dict) -> float | None:
    extract = entry.get("extract_pct")
    return round(extract / 100, 4) if extract is not None else None


_COLOR = {
    "briess": _briess_color,
    "bairds": _bairds_color,
    "simpsons": _simpsons_color,
    "fawcett": _fawcett_color,
    "gambrinus": _gambrinus_color,
    "great western": _great_western_color,
    "bestmalz": _bestmalz_color,
    "dingemans": _dingemans_color,
    "canada malting": _canada_malting_color,
    "crisp": _crisp_color,
}

_YIELD = {
    "briess": _briess_yield,
    "bairds": _bairds_yield,
    "simpsons": _simpsons_yield,
    "fawcett": _fawcett_yield,
    "gambrinus": _gambrinus_yield,
    "great western": _great_western_yield,
    "bestmalz": _bestmalz_yield,
    "dingemans": _dingemans_yield,
    "canada malting": _canada_malting_yield,
    "crisp": _crisp_yield,
}


def color_to_lovibond(maltster: str, entry: dict) -> float | None:
    """Map a raw intermediate entry's colour to a single Lovibond value."""
    fn = _COLOR.get((maltster or "").lower())
    return fn(entry) if fn else None


def extract_to_yield(maltster: str, entry: dict) -> float | None:
    """Map a raw intermediate entry's extract to a 0..1 yield fraction."""
    fn = _YIELD.get((maltster or "").lower())
    return fn(entry) if fn else None
