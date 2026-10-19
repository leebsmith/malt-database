"""Shared helpers for the malt database toolchain.

The category classification here is hand-curated ("discover once"): when a
new maltster is added, its keyword rules and slug overrides are written once
and committed, then simply looked up at build time. Nothing is discovered
dynamically.
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
}


def classify_category(maltster: str, name: str, slug: str) -> str:
    maltster = (maltster or "").lower()
    overrides = CATEGORY_MAP.get(maltster, {})
    if slug in overrides:
        return overrides[slug]
    text = f"{slug} {name}".lower()
    for category, keywords in KEYWORD_RULES:
        if any(keyword in text for keyword in keywords):
            return category
    return "BASE"


def color_to_lovibond(maltster: str, srm: float | None) -> float | None:
    """Convert a raw color value to Lovibond.

    Briess reports "SRM" values that already match their Lovibond product
    naming (e.g. "Caramel Malt 120L" -> SRM 120), so for now this is a direct
    pass-through. Add per-maltster conversions here as other units are added
    (e.g. EBC for Weyermann/Dingemans: Lovibond ~= EBC * 0.508).
    """
    if srm is None:
        return None
    return round(float(srm), 2)
