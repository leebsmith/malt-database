"""In-row provenance for the unified export (C.4).

Every published figure is cited by the document it was read from: the URL, the
document's sha256, its retrieval timestamp, the source's vendor label, and the
bound the source states ("point", "min", "max", or "unknown" when Pass 1 did not
capture the qualifier). The importer copies these objects verbatim; it never
translates them.

Provenance is keyed by the **source key** (the intermediate file stem:
bairds, northern-brewer, …), not by the row's brand. Some sources carry
products from more than one maltster — Northern Brewer's Shopify dump includes
L.D. Carlson products — and the citation belongs to the document, not the brand.

Documents are the cached files under data/source/ — HTML product pages, the
Briess listing, the Brewtarget SQLite database, the Northern Brewer products
JSON, and Weyermann specification PDFs. Nothing here fetches from the network.
"""

from __future__ import annotations

import hashlib
import html
import re
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote, unquote

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "data" / "source"

# Human label for the document's publisher.
SOURCE_VENDORS = {
    "bairds": "Bairds",
    "bestmalz": "Bestmalz",
    "brewtarget": "Brewtarget",
    "briess": "Briess",
    "canada-malting": "Canada Malting",
    "crisp": "Crisp",
    "dingemans": "Dingemans",
    "fawcett": "Fawcett",
    "gambrinus": "Gambrinus",
    "great-western": "Great Western",
    "northern-brewer": "Northern Brewer",
    "simpsons": "Simpsons",
    "weyermann": "Weyermann",
    "williams": "Williams Brewing",
}

# One cached HTML file covers every product in the source.
SINGLE_HTML = {
    "briess": "briess",
}

# Non-HTML documents with a fixed upstream URL.
SINGLE_FILES = {
    "brewtarget": (
        "brewtarget/default_db.sqlite",
        "https://raw.githubusercontent.com/Brewtarget/brewtarget/main/data/default_db.sqlite",
    ),
    "northern-brewer": (
        "northern-brewer/products.json",
        "https://www.northernbrewer.com/collections/belgian-candi-sugar/products.json?limit=250",
    ),
}

# One cached page per product: data/source/<source>/<slug>.html
PAGE_DIRS = {
    "bairds": "bairds",
    "bestmalz": "bestmalz",
    "canada-malting": "canada-malting",
    "crisp": "crisp",
    "dingemans": "dingemans",
    "fawcett": "fawcett",
    "gambrinus": "gambrinus",
    "great-western": "great-western",
    "simpsons": "simpsons",
    "williams": "williams",
}

CANONICAL = re.compile(
    r"""<link[^>]+rel=["']canonical["'][^>]*href=["']([^"']+)["']""", re.I
)
CANONICAL_REVERSED = re.compile(
    r"""<link[^>]+href=["']([^"']+)["'][^>]*rel=["']canonical["']""", re.I
)
OG_URL = re.compile(
    r"""<meta[^>]+property=["']og:url["'][^>]*content=["']([^"']+)["']""", re.I
)

_DIGESTS: dict[Path, tuple[str, str]] = {}


def _digest(path: Path) -> tuple[str, str]:
    """Return (sha256, retrieved_at) for a cached document, memoized."""
    cached = _DIGESTS.get(path)
    if cached is None:
        data = path.read_bytes()
        stamp = datetime.fromtimestamp(path.stat().st_mtime, timezone.utc)
        cached = (
            hashlib.sha256(data).hexdigest(),
            stamp.replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        )
        _DIGESTS[path] = cached
    return cached


def _html_url(path: Path) -> str:
    raw = path.read_text(encoding="utf-8", errors="replace")
    for pattern in (CANONICAL, CANONICAL_REVERSED, OG_URL):
        match = pattern.search(raw)
        if match:
            return html.unescape(match.group(1))
    raise ValueError(f"{path}: no canonical or og:url to cite")


def _only_html(directory: Path) -> Path:
    pages = sorted(directory.glob("*.html"))
    if len(pages) != 1:
        raise ValueError(f"{directory}: expected exactly one cached page, found {len(pages)}")
    return pages[0]


def document(source: str, slug: str, source_url: str | None = None) -> tuple[Path, str]:
    """Locate the cached document and its URL for one intermediate entry."""
    if source == "weyermann":
        if not source_url:
            raise ValueError(f"weyermann/{slug}: the spec PDF URL is required")
        name = unquote(source_url.rsplit("/", 1)[-1])
        return SOURCE / "weyermann" / "pdf" / name, source_url
    if source in SINGLE_HTML:
        path = _only_html(SOURCE / SINGLE_HTML[source])
        return path, _html_url(path)
    if source in SINGLE_FILES:
        relative, url = SINGLE_FILES[source]
        return SOURCE / relative, url
    directory = PAGE_DIRS.get(source)
    if directory is None:
        raise ValueError(f"{source}: no provenance source registered")
    base = SOURCE / directory
    for candidate in (slug, unquote(slug), quote(slug, safe="")):
        path = base / f"{candidate}.html"
        if path.exists():
            return path, _html_url(path)
    raise FileNotFoundError(f"{source}/{slug}: no cached page in {base}")


def slugify(value: str) -> str:
    value = unquote(value).replace("\u00ae", "").replace("\u2122", "")
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")


def source_id(source: str, slug: str) -> str:
    return f"{source}/{slugify(slug)}"


def citation(
    source: str, slug: str, source_url: str | None = None
) -> tuple[str, dict]:
    """Return (document_url, citation-without-bound) for one entry."""
    path, url = document(source, slug, source_url)
    sha256, retrieved_at = _digest(path)
    return url, {
        "kind": "vendor",
        "vendor": SOURCE_VENDORS.get(source, source),
        "url": url,
        "retrieved_at": retrieved_at,
        "sha256": sha256,
    }


def seal(base: dict, bound: str, note: str | None = None) -> dict:
    """Attach the bound (and an optional caveat) to a citation."""
    provenance = {"bound": bound, **base}
    if note:
        provenance["note"] = note
    return provenance
