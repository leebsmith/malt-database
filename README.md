# Malt Database

A local web scraper/processor that caches maltster assets (HTML/PDF) and unifies
them into a common JSON object. All scripts run locally; no cloud deployment.

## Layout

```
bin/          scripts: fetch-*, process-* (bash/pup), <maltster>.jq filters, unify.py
lib/          shared python helpers (category mapping, normalization)
schema/       malt.schema.json = canonical; <maltster>.schema.json = intermediate
config/       per-maltster source definitions (sources.tsv)
data/         cache + generated output (gitignored)
  source/     raw cached assets, one dir per maltster
  maltsters/  intermediate JSON, one file per maltster
  db/         unified database (malts.json)
```

Each maltster has its own **intermediate schema** (`schema/<maltster>.schema.json`)
describing its raw, native fields (e.g. Briess reports `color_srm`, and either
`yield_on_grind` for malts or `fermentability` for extracts/adjuncts). `unify.py`
validates the intermediate, then maps it to the canonical `malt.schema.json`.

## Targets

```
make source     download + cache raw assets for all maltsters
make <maltster> process cached source -> data/maltsters/<maltster>.json
make db         unify -> data/db/malts.json, then run the quality check
make check      run the quality gate on data/db/malts.json
make clean      remove data/
```

## Quality gate

`make check` (also run at the end of `make db`) validates `data/db/malts.json`:
the canonical schema, non-empty names, no HTML entities, colour in 0–1000,
yield in 0–1 with a valid `yield_basis`, a valid `product_type`, `category`
present for malt/adjunct (and absent for extract/syrup), no duplicate names
within a maltster, and completeness floors (colour ≥90%, yield ≥80%, description ≥90%,
notes ≥65%) computed over `product_type == "malt"` entries.

## Workflow (Briess example)

`make briess` (or `make db`) runs a two-stage, file-driven pipeline. Each stage
is idempotent; `make` only re-runs a step when its input changed.

1. **Fetch** — `bin/fetch-briess.sh` calls `bin/fetch.sh`, which runs
   `curl --compressed --retry 3` against `https://brewingwithbriess.com/products/`
   and caches the raw HTML to `data/source/briess/products.html`.

2. **Process** — `bin/process-briess.sh` first runs a **pre-parse layout
   check** (asserts the cached HTML still contains `article.product` and the
   key selectors, failing fast with a clear message if the page changed), then
   pipes the HTML through `pup 'article.product json{}'` into
   `jq -f bin/briess.jq` (extracts raw fields: `name`, `slug`, `description`,
   `notes`, `color_srm`, `yield_on_grind`, `fermentability`), writing
   `data/maltsters/briess.json`. `bin/validate.py briess` then validates that
   output against `schema/briess.schema.json`.

3. **Unify** (only via `make db`) — `bin/unify.py` validates each intermediate
   file against `schema/<maltster>.schema.json`, maps raw fields to the
   canonical schema, and writes `data/db/malts.json`.

```
Briess website
   |  curl (bin/fetch.sh)
   v
data/source/briess/products.html       <- raw cache
   |  pup 'article.product json{}' | jq -f bin/briess.jq
   v
data/maltsters/briess.json             <- raw malt objects (per-maltster schema)
   |  unify.py (map + validate)
   v
data/db/malts.json                     <- canonical, unified
```

### Bairds (two-level crawl)

`make bairds` follows the discovery trail `robots.txt -> sitemap ->
/divi_mega_pro/malt-menu/`. It caches the malt-menu page, extracts the 29 malt
links (`.entry-content ul:not(.et_mobile_menu) a`), then fetches each malt page
to `data/source/bairds/<slug>.html`. Processing reads each page's `<h1>` (name),
the description paragraph, the "Flavour profile:" line (notes), and the ASBC
tab's extract/colour particulars.

### Simpsons (third container crawl)

`make simpsons` caches `https://www.simpsonsmalt.co.uk/our-malts/`, then takes
the malt links from the **third `.content .container`** (the only one with
links), keeping `/our-malts/<category>/<slug>/` (45 malts). Processing reads the
`<h1>` (name), the `#malt-page-intro` paragraphs (description), the flavour line
inside `.substyles-list` (notes; packaging lines are skipped), and the ASBC tab
(`#asbc`) `Extract %` and `Colour ° Lovibond` (already Lovibond, range collapsed
to a midpoint).

### Fawcett (category-grouped listing)

`make fawcett` caches `/our-malts/category/brewing-malts/` (37 malts), whose
`div.malt-type` blocks group links under an `<h2>` category (Base/Crystal/Roast/
Specialty). `fetch-fawcett.sh` writes `index.tsv` (`slug`, `category`, `url`);
`process-fawcett.sh` passes the category as `category_hint`. Particulars come
from the IOB/EBC/ASBC spec tables: prefer ASBC (`ASBC Colour Lovibond`), fall
back to EBC, then IOB (LDK converted to %).

### Gambrinus (product sitemap)

`make gambrinus` reads `product-sitemap.xml` (18 malts) via the shared
`bin/fetch-sitemap.sh`. Each page has an `<h1>` name, a short blurb
(`p.section-single-product__short-desc`, often empty) and a long description
(`div.section-single-product__description`); specs are key/value pairs in
`.section-single-product__spec` (Colour Lovibond/SRM/EBC, Extract FG Min).
Colour prefers Lovibond, then SRM, then EBC.

### Great Western (product listing)

`make great-western` caches `/products/`, takes the 22 `/product/<slug>/` links
under `.product-archive` (honoring `Crawl-delay: 10`), and extracts `h1.name`,
`p.description`, `p.additional` (notes), and `div.stats-table p.attribute`
pairs (`span.title` + value, notably `Color SRM`).

### Bestmalz (catalog listing)

`make bestmalz` caches the English catalog and takes the 43 unique
`/en/malts/<slug>/` links under `div.malz-wrapper`. Each page has `h1` (name),
description in the sibling `div.*-dynamichtml` blocks, and a spec table
(`div.kt-inside-inner-col table`) with `Wort color` in `EBC / L` form (we take
the Lovibond after `/`) and `Extract ...` in %. European decimal commas are
normalized to dots. Bestmalz has no separate notes field.

### Dingemans (sitemap)

`make dingemans` reads `sitemap.xml` (36 `/malt/<slug>` pages, honoring the
10 s crawl-delay). Each page has `<h1>` (name), a `Type of malt` taxonomy term
(used as `category_hint`), a `field-name-body` description, a `Flavour` key
spec (notes), and `#group-specs` Drupal fields. `Lovibond` is taken directly
(decimal comma normalized), with `Colour EBC` as fallback; extract comes from
`Extract fine D.M.`.

### Canada Malting (sitemap, English only)

`make canada-malting` reads `malts-sitemap.xml`, keeping only the 24 English
`/malts/<slug>/` links (the sitemap also lists French `/fr/malts/` translations,
which are excluded). Honours the 10 s crawl-delay. Each page has
`div.product-details` `h1` (name), `h3` (type, used as `category_hint`), and
`p` paragraphs (description); particulars are `.product-table-row`
(`strong` + `span.product-data`), with `Colour °L` preferred over `Colour SRM`,
and `Extract %`.

### Crisp (sitemap, English only)

`make crisp` reads `malts-sitemap.xml`, keeping the 49 non-locale
`/malts/<slug>/` links (the sitemap also lists `/en-us/malts/` duplicates).
Each page has `section.breadcrumb h1` (name), `.malt-post__tasting` list items
(notes), `.malt-post__text` paragraphs (description), and a `.malt-post__table`
with Parameter/IoB/EBC/ASBC columns. Table shape varies: colour prefers a `°L`
cell, else the last EBC cell; extract uses the last `%` cell, else `L°/kg`
(`/3.866`). Products whose title image marks "Sold Out" get `sold_out: true`.

### Sugars (Brewtarget, open data)

`make brewtarget` downloads Brewtarget's GPLv3 `default_db.sqlite` and extracts
the `ftype = 'sugar'` rows (15 after deduplication): cane/beet sugar, dextrose,
brown sugar, demerara, invert, turbinado, molasses, corn/maple syrup, lactose,
and **Candi Sugar Clear/Amber/Dark**. Brewtarget stores colour in SRM and
fine-grind extract (%); both are normalized. These entries are `product_type`
`sugar`/`syrup`, carry `yield_basis: extract`, and are intentionally
uncategorized (late additions).

### Candi syrups (Williams Brewing)

`make williams` fetches Williams Brewing's candi-syrup category and its two
products — **Belgian Amber** and **Dark** candi syrup, produced by Candico.
The specs live in each page's schema.org Product JSON-LD description: colour
in EBC and sugar content in Brix. Brix is used as `extract_pct` /
`yield_fraction` (`yield_basis: extract`), and colour is converted
EBC -> SRM -> Lovibond. These are `product_type: syrup` and uncategorized.

## Canonical schema

Required fields: `name`, `maltster`, and `category` for malt and adjunct
products.
Optional: `yield_fraction` (0..1) with `yield_basis` (`extract` or
`fermentability`), `color_lovibond`, `notes`, `description`, `sold_out`
(only where the source reports availability), and `product_type`
(`malt` | `extract` | `adjunct` | `syrup` | `sugar`).

`yield_basis` says what `yield_fraction` means: `extract` = fine-grind extract
(includes Briess's "Yield on grind", verified against its Typical Analysis
sheet), `fermentability` = Briess extracts/adjuncts.

`product_type` separates actual malt from extracts, adjuncts (flakes,
torrefied/raw/unmalted grains, rice hulls), syrups, and sugars. `category` is
a mash-pH classification: it is set for `malt` and `adjunct` products, but
**intentionally omitted for `extract`, `syrup`, and `sugar`** because they are
not mashed (extracts are dissolved; syrups/sugars are late additions).
Consumers that use `category` directly should filter on `product_type`.

`category` is one of `BASE`, `ROASTED`, `CRYSTAL`, `ACIDULATED`.

## Normalization (intermediate -> canonical)

Per-maltster normalization lives in `lib/malt.py` and is dispatched by
`bin/unify.py`. A shared `_to_lovibond(value, unit)` converts SRM
(`°L = (SRM + 0.76)/1.3546`) and EBC (via SRM: `EBC/1.97`, then Lovibond);
only Briess's "SRM" is passed through because it already matches Lovibond.
Text fields are HTML-unescaped in `unify.py`.

- **Briess** — `color_srm` -> `color_lovibond` (pass-through; Briess's "SRM"
  matches its Lovibond product naming); `yield_on_grind` or `fermentability`
  -> `yield_fraction`.
- **Bairds** — the ASBC tab's `°SRM` colour range is collapsed to a midpoint,
  then converted to Lovibond (`color_srm_min`/`color_srm_max` ->
  `color_lovibond`); `extract_pct` -> `yield_fraction`; names are title-cased
  (Bairds stores mixed-case text in the DOM and title-cases it via CSS).
- **Simpsons** — the ASBC tab's `Colour ° Lovibond` range is collapsed to its
  midpoint (`color_lovibond_min`/`color_lovibond_max` -> `color_lovibond`);
  `extract_pct` -> `yield_fraction`. No unit conversion needed.
- **Fawcett** — prefers the ASBC table's Lovibond range (midpoint); falls back
  to EBC (converted via SRM) when ASBC is empty, or IOB (extract LDK `/3.866`,
  EBC colour). Category comes from the listing's `<h2>` via `category_hint`.
- **Gambrinus** — colour midpoint from `Colour Lovibond` (fallback SRM, then EBC,
  both converted); `extract_pct` from `Extract FG Min`. Uses the short blurb as
  `description` and the long prose as `notes` when both exist, otherwise the
  long prose is the description.
- **Great Western** — colour midpoint from `Color SRM`, converted to Lovibond.
  No extract is published, so `yield_fraction` is omitted.
- **Bestmalz** — colour midpoint from the `Wort color` row's Lovibond value
  (after `/`); `extract_pct` from `Extract ...`. Decimal commas become dots.
  No notes field.
- **Dingemans** — `Lovibond` (fallback EBC, converted via SRM) and `Extract fine D.M.`;
  decimal commas become dots. Category comes from the `Type of malt` term via
  `category_hint` (with slug overrides for organic/dark kilned specialties);
  notes from the `Flavour` field.
- **Canada Malting** — colour midpoint from `Colour °L` (fallback `Colour SRM`,
  converted); `extract_pct` from `Extract %`. Category comes from the `h3` type
  via `category_hint` (Base/Specialty/Adjunct/Other all map to `BASE`).
- **Crisp** — colour from a `°L` cell (else last EBC, converted via SRM); extract from the
  last `%` cell (else `L°/kg /3.866`). `sold_out` is carried into the DB.
- **Brewtarget** — sugar rows: `extract_pct` from `fine_grind_yield_pct`, colour
  from SRM; `product_type` is `sugar` or `syrup`; uncategorized.
- **Williams Brewing** — candi syrup: colour from the EBC range in the Product
  JSON-LD, extract from the Brix range; `product_type` is `syrup`;
  uncategorized.
- `yield_basis` is `extract` for all extract/yield-on-grind figures and
  `fermentability` for Briess extracts/adjuncts.
- `category` assigned by `lib.malt.classify_category()`.

## Crawling etiquette

`bin/fetch.sh` identifies as `BotMaltHomebrewer/0.1 (+leeb@lee-smith.org)` with
a `From: leeb@lee-smith.org` header, and sleeps `SLEEP_SECONDS` (default 2)
after each download. Maltsters may override it: Bairds, Great Western,
Dingemans, and Canada Malting set `SLEEP_SECONDS=10` to honor their robots.txt
`Crawl-delay: 10`. Fetching is cached — `make <maltster>` skips pages already
present in `data/source/`; `make clean` forces a re-fetch.

## Known limitations

- Briess reports color as **SRM**, but its values already match Lovibond
  product naming (e.g. "Caramel Malt 120L" -> SRM 120), so Briess alone is
  passed through unconverted. All other SRM/EBC sources are converted by
  `_to_lovibond()` (SRM->Lovibond uses `(SRM + 0.76)/1.3546`, which is an
  approximation, especially for very dark malts).
- Yield: all `extract` figures are fine-grind extract. Briess's web "Yield on
  grind" was checked against its Typical Analysis sheet and matches the
  `Extract FG` column (35/36); the exception is **Heritage Gold™ Malt**, where
  the website (75%) disagrees with the sheet (82%) — we keep the website value.
  A few LDK-derived extracts (Fawcett IOB, Crisp IOB-only) are converted and
  recorded as `extract`.
- Bairds colours are ranges collapsed to a midpoint and converted from SRM;
  the range itself is not retained in the canonical DB.
- Some Bairds malts (High Enzyme Distilling, Organic, Toll) publish no
  extract/colour, so `yield_fraction`/`color_lovibond` are omitted.
- Simpsons colours are Lovibond ranges collapsed to a midpoint. Some peated /
  distilling malts have no `#asbc` tab, so their extract/colour are omitted.
- Simpsons `notes` is a best-effort heuristic (first `.substyles-list` text that
  isn't the packaging line); unmalted adjuncts are included as `BASE`.
- Fawcett uses the **brewing** category (37), excluding its distilling malt and
  a duplicate spring-pale variant. Pages without an ASBC table use EBC
  (via SRM); IOB-only pages (Dextrin) convert LDK `/3.866`. EBC→Lovibond is an
  approximation.
- Gambrinus only publishes `Extract FG Min` on some malts, so `yield_fraction`
  is omitted for the rest (e.g. Vienna, Munich, Honey). Chit has no Lovibond, so
  its colour comes from SRM (converted).
- Great Western publishes no extract at all, so `yield_fraction` is always
  omitted; colour is SRM (converted to Lovibond).
- Bestmalz has no notes field; its `Wort color` is `EBC / L` (we take Lovibond).
  Some malts (e.g. Roasted Barley) publish no extract.
- Dingemans `Type of malt` groups some dark specialties under "Kilned" and mixes
  organics under "Organic"; slug overrides classify Aroma, Melanoidin,
  Amber-Aromatic, and the organic Biscuit/Mroost correctly. `Chocolate Rye` has
  no extract.
- Canada Malting French `/fr/malts/` pages are translations of the English
  catalog and are excluded. Flaked grains and Food Grade Malt publish no
  colour/extract. CMC is a base/specialty producer, so everything maps to
  `BASE`.
- Crisp includes 8 sold-out products (`sold_out: true`); they are kept for
  completeness. Some special-edition/duplicate pages exist (e.g. `chit-malt`
  vs `chitmalt`). A few products (flaked grains, rice hulls, peated/pot-still)
  publish no colour; "No 19 Maris Otter" publishes no extract.
- Sugar sources: Brewtarget (GPLv3) provides generic sugars and Candi Sugar
  Clear/Amber/Dark with yield/colour. Williams Brewing adds Belgian **Amber**
  and **Dark** candi syrup (Candico), using EBC colour and Brix as extract.
  Other candi grades (e.g. clear/special) are not yet included. Sugar rows have
  no descriptions/notes, so completeness floors are computed over malts only.
- EBC -> Lovibond is `(EBC/1.97 + 0.76)/1.3546` (via SRM); an earlier version
  used `EBC x 0.508`, which overestimated dark colours and was corrected when
  the candi syrups were added.
- Briess dark roasted malts, flours, and rice hulls publish no
  yield/fermentability, so `yield_fraction` is omitted for those entries.
- Category classification is keyword-based with curated overrides
  (`lib/malt.py`). Non-malt products (extracts, adjuncts, flakes, syrups) do
  not fit the malt category enum and currently fall back to `BASE`; refine in
  `lib/malt.py` as needed.
