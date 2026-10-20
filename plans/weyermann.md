# Weyermann — implementation plan

**Status:** draft (not implemented). **Estimate:** ~3–4 h active + ~15 min crawl.

**Dependency:** implement **after** `plans/moisture.md` (the canonical `moisture`
field + `unify.py` pass-through must exist so `moisture_pct` reaches the DB).

## 1. Goal

Add Weyermann malts to the database by parsing their `_Specification.pdf` sheets
(their site exposes no HTML spec data).

## 2. Findings (verified)

- `weyermann.de` is WooCommerce + multilingual (`de`, `en-gb`, `en-us`).
  **Use the English sitemap:** `https://www.weyermann.de/en-gb/wp-sitemap-posts-portfolio-1.xml`
  (150 `/en-gb/product/<slug>/` URLs). The bare `wp-sitemap-posts-portfolio-1.xml`
  is the German catalog (152 German slugs) — do not use it.
- The English sitemap contains **duplicate slugs**: WooCommerce appends a numeric
  suffix (`-2`, `-3`, `-5`, `-8`) to the same product across categories/locales.
  150 entries collapse to **~109 unique products** once the trailing `-\d+`
  suffix is stripped. The fetch script must dedupe on that basis.
- The catalog includes a few **non-malt items** (hops `zamba`/`willamette`,
  `sour-wort`, `roasted-malt-extract-rme`); they carry no malt spec table and are
  dropped by the product filter (§3).
- Each English malt page links `…_Specification.pdf` (English content). The
  German-slug pages link `…_Spezifikation.pdf` (German, comma decimals); targeting
  `en-gb` avoids them, but the fetch regex must match `_Specification.pdf`
  specifically. **The upload path varies** (`/2019/11/`, `/2021/05/`,
  `/2023/05/`), so scrape the PDF `href` from each page rather than reconstruct
  the URL.
- Spec PDF = 2 pages. Page 1 has a stable
  `Parameter | Minimum | Maximum | Unit` table below a `Product: <Name>` line.
  Base malts carry the full analysis; caramel/roasted carry a short table
  (moisture, extract, colour).
- **`Color (Lovibond)` is present directly** (min/max); `Color (EBC)` too;
  `Extract (dry substance)` is the yield %; `Moisture content` is the moisture %.
  English PDFs use dot decimals. Carafa Special Type 3 → Lovibond 490.6–566.

## 3. Scope / product filter

- Process only products whose page links a `_Specification.pdf` **with the
  standard malt table** (this excludes hops, sour-wort, RME, and yeast).
- **Non-malt products:** keep only if they map cleanly onto the existing
  `product_type` (e.g. Sinamar/RME → `extract`, uncategorized) *and* yield a
  parseable colour/extract; otherwise drop them. Such entries must set
  `product_type` explicitly (the `lib.malt.product_type()` heuristic will not
  classify them).
- **Caching scope:** fetch `_Specification.pdf` **only**. Skip
  `WEYERMANN_BREWERY_EN_*` (analysis, ~420 KB) and `MaltAromaWheel_*` (~200 KB)
  — they are unused and would roughly triple the crawl (~90 MB, ~300 extra
  requests). Expected cache: ~150 product HTML (~22 MB) + ~109 spec PDFs
  (~28 MB) ≈ **~50 MB**.

## 4. Fields captured

- `name`, `slug`, `maltster` ("Weyermann")
- `description` ← WooCommerce product description (required to hold the 90%
  completeness floor)
- `notes` ← "Aroma / Flavour" section, when present (holds the 65% floor)
- `extract_pct` ← `Extract (dry substance)` (min/max **midpoint**; min-only or
  max-only → that value)
- `color_lovibond_min`/`max` ← `Color (Lovibond)` (fallback `Color (EBC)` → SRM → Lovibond)
- `moisture_pct` ← `Moisture content` (unified to `moisture` per moisture.md)

## 5. Classification (no new field)

Husked vs dehusked is distinguished by **name** only (Carafa I/II/III vs
Carafa Special I/II/III); both map to ROASTED in the 4-value enum.

Implementation in `lib/malt.py`:
- Add `"carafa"` and `"melanoidin"` to the **global** `KEYWORD_RULES` ROASTED
  tuple. ROASTED is checked before CRYSTAL, so this resolves the `"cara"`
  substring collision (`"carafa …"` otherwise matches CRYSTAL). `chocolate` and
  `roast` are already covered; `acidulated` already matches ACIDULATED; `cara*`
  already matches CRYSTAL.
- Add `CATEGORY_MAP["weyermann"]` slug overrides:
  - `special-w` → CRYSTAL (no keyword match; would default to BASE)
- `smoked`/`beech`/`oak` → BASE requires no change (already the default fallback).

## 6. Files

- `bin/fetch-weyermann.sh` — fetch the `en-gb` sitemap → dedupe slugs (strip
  trailing `-\d+`) → fetch each English product page → scrape + download its
  `_Specification.pdf` (URL-encode every `®`/`CARAFA®`). Skip analysis/aroma PDFs.
- `bin/process-weyermann.sh` + `bin/extract_weyermann.py` — `pdftotext -layout` + label regex.
- `schema/weyermann.schema.json` — name, slug, maltster (const "Weyermann"),
  description, notes, extract_pct, color_lovibond_min/max, color_ebc_min/max,
  moisture_pct, product_type (optional; for Sinamar/RME).
- `lib/malt.py` — `_weyermann_color`, `_weyermann_yield`; dispatch key
  "weyermann"; plus the §5 classification changes.
- `schema/malt.schema.json` — **no enum change needed** ("Weyermann" already
  present). `moisture` added by moisture.md.
- `Makefile` — `MALSTERS += weyermann`, sentinel + process targets.
- `config/sources.tsv` — weyermann row (documentation only; nothing consumes it).
- `README.md` — Weyermann section + PDF-parsing note.

## 7. Edge cases / risks

- **Duplicate slugs** — strip trailing `-\d+` before dedupe (~109 unique).
- **Spec-PDF filename/language** — `_Specification.pdf` (English) vs
  `_Spezifikation.pdf` (German); match the former, scrape href (path varies).
- **`®` / `CARAFA®`** (multiple `®`) in filenames — URL-encode when downloading.
- min-only vs max-only values (`Extract 80.5` vs `Moisture ≤5`).
- Harvest-specific values ("Crop: 2026") — treat as a current snapshot.
- Parameter-set variation (base vs caramel/roasted) — parse by label, not position.
- Multi-locale — target `en-gb` only.

## 8. Crawl etiquette

Default `SLEEP_SECONDS=2` (no crawl-delay). ~150 product pages + ~109 spec PDFs ≈
260 requests ≈ 10–15 min.

## 9. Verification / acceptance

- `make weyermann` fetches + processes + `validate.py` passes.
- `make db` unifies (moisture lands via moisture.md); `make check` passes
  (completeness over malts — description/notes must be present, §4).
- Category sanity: ACIDULATED ≈ 1, CRYSTAL (Cara*) ≈ many, ROASTED
  (Carafa/Melanoidin/Chocolate*) ≈ many, BASE ≈ base malts.
- Spot-check Lovibond vs known values (e.g. Carafa Special III ≈ 500 SRM region).
