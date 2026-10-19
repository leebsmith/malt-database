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
make db         unify all maltster JSON -> data/db/malts.json (validated)
make clean      remove data/
```

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

## Canonical schema

Required fields: `name`, `maltster`, `category`.
Optional: `yield_fraction` (0..1), `color_lovibond`, `notes`, `description`.

`category` is one of `BASE`, `ROASTED`, `CRYSTAL`, `ACIDULATED`.

## Normalization (intermediate -> canonical)

- `color_srm` -> `color_lovibond` via `lib.malt.color_to_lovibond()`.
- `yield_on_grind` or `fermentability` (extracts/adjuncts) -> `yield_fraction`
  (percentage / 100).
- `category` assigned by `lib.malt.classify_category()`.

## Known limitations

- Briess reports color as **SRM**, which matches their Lovibond product naming
  (e.g. "Caramel Malt 120L" -> SRM 120), so `color_to_lovibond()` is currently
  a pass-through. Other units (e.g. EBC) will need real conversion per maltster.
- Dark roasted malts, flours, and rice hulls publish no yield/fermentability,
  so `yield_fraction` is omitted for those entries.
- Category classification is keyword-based with curated overrides
  (`lib/malt.py`). Non-malt products (extracts, adjuncts, flakes, syrups) do
  not fit the malt category enum and currently fall back to `BASE`; refine in
  `lib/malt.py` as needed.
