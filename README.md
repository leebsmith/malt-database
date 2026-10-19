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

## Canonical schema

Required fields: `name`, `maltster`, `category`.
Optional: `yield_fraction` (0..1), `color_lovibond`, `notes`, `description`.

`category` is one of `BASE`, `ROASTED`, `CRYSTAL`, `ACIDULATED`.

## Normalization (intermediate -> canonical)

Per-maltster normalization lives in `lib/malt.py` and is dispatched by
`bin/unify.py`:

- **Briess** — `color_srm` -> `color_lovibond` (pass-through; Briess's "SRM"
  matches its Lovibond product naming); `yield_on_grind` or `fermentability`
  -> `yield_fraction`.
- **Bairds** — the ASBC tab's `°SRM` colour range is collapsed to its midpoint
  (`color_srm_min`/`color_srm_max` -> `color_lovibond`); `extract_pct` ->
  `yield_fraction`; names are title-cased (Bairds stores mixed-case text in
  the DOM and title-cases it via CSS).
- **Simpsons** — the ASBC tab's `Colour ° Lovibond` range is collapsed to its
  midpoint (`color_lovibond_min`/`color_lovibond_max` -> `color_lovibond`);
  `extract_pct` -> `yield_fraction`. No unit conversion needed.
- `category` assigned by `lib.malt.classify_category()`.

## Crawling etiquette

`bin/fetch.sh` identifies as `BotMaltHomebrewer/0.1 (+leeb@lee-smith.org)` with
a `From: leeb@lee-smith.org` header, and sleeps `SLEEP_SECONDS` (default 2)
after each download. Maltsters may override it: Bairds sets `SLEEP_SECONDS=10`
to honor its robots.txt `Crawl-delay: 10`. Fetching is cached — `make <maltster>`
skips pages already present in `data/source/`; `make clean` forces a re-fetch.

## Known limitations

- Briess reports color as **SRM**, which matches their Lovibond product naming
  (e.g. "Caramel Malt 120L" -> SRM 120), so `color_to_lovibond()` is currently
  a pass-through. Other units (e.g. EBC) will need real conversion per maltster.
- Bairds colours are ranges collapsed to a midpoint; the range itself is not
  retained in the canonical DB.
- Some Bairds malts (High Enzyme Distilling, Organic, Toll) publish no
  extract/colour, so `yield_fraction`/`color_lovibond` are omitted.
- Simpsons colours are Lovibond ranges collapsed to a midpoint. Some peated /
  distilling malts have no `#asbc` tab, so their extract/colour are omitted.
- Simpsons `notes` is a best-effort heuristic (first `.substyles-list` text that
  isn't the packaging line); unmalted adjuncts are included as `BASE`.
- Briess dark roasted malts, flours, and rice hulls publish no
  yield/fermentability, so `yield_fraction` is omitted for those entries.
- Category classification is keyword-based with curated overrides
  (`lib/malt.py`). Non-malt products (extracts, adjuncts, flakes, syrups) do
  not fit the malt category enum and currently fall back to `BASE`; refine in
  `lib/malt.py` as needed.
