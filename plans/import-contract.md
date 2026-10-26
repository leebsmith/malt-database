# Import contract — a versioned, well-typed seam to the dag-calculator

**Status:** C.1, C.2, C.3, **C.4 done** (`malt_database` `afe1d4f`; consumer
side lands in the next `dag-calculator` pass). **Estimate:** ~3–4 h
(schema/envelope + null-vs-0 + a coordinated change in `dag-calculator`).

## 1. Goal

Make the export of `data/db/malts.json` a **versioned, well-typed contract** so
that the importer (`dag-calculator`) can consume it predictably: shape/type/unit
compatibility guaranteed, and any contract change a loud failure rather than a
silent reshape. This does **not** move the dag's dedupe/crosswalk/standard
classification into this repo — those remain importer-side; this contract only
governs the raw producer→consumer hand-off.

## 2. Background

Today:

- `data/db/malts.json` is a **bare array** with no version marker.
- `schema/malt.schema.json` is the canonical schema, but it is unversioned and
  `additionalProperties: true`; nothing pins a revision.
- "Not published" is encoded as **`0`** for `color_lovibond` and `moisture`
  (and occasionally elsewhere). The importer had to *invent* a colour-`0`
  backfill and a moisture `0 → absent` normalization to undo this.
- The importer re-implements the contract by hand (`tests/guards/
  fermentables-source-contract.test.js` `ALLOWED_KEYS` + enum lists), so the two
  repos can drift silently.

## 3. Decisions (resolved)

1. **Versioned envelope.** Emit `data/db/malts.json` as
   `{ schema_version, generated_at, entries: [...] }` (an object, not a bare
   array). A contract revision bump is then a loud failure in the importer, not a
   silent reshape.
2. **Null-vs-0.** "Not published" is `null`/absent — never `0` — for
   `color_lovibond`, `moisture`, `yield_fraction`. (The importer still tolerates
   `0` defensively, but the contract no longer relies on it.)
3. **Stable `source_id`.** Add a stable per-entry id (`maltster` + product slug)
   so the importer's dedupe/crosswalk keys stop churning on renames. Optional,
   lower priority.
4. **Single source of truth.** The importer vendors a pinned copy of
   `malt.schema.json` (with its `schema_version`) and validates against it,
   replacing its hand-rolled allowlist. `schema/malt.schema.json` remains the
   canonical contract; `schema_version` is bumped only on a breaking change.

## 4. Staging

### C.1 — Null-vs-0 (highest value, no envelope change)

- `bin/unify.py` — when a field is absent/unknown, emit `null`/omit, not `0`.
- Per-maltster `bin/<maltster>.jq` / `bin/extract_*.py` — stop writing `0` for
  "no value" (colour, moisture, yield).
- `bin/check.py` — report coverage; treat `null` (not `0`) as "missing".
- `schema/malt.schema.json` — fields stay optional; document that absent = null.

### C.2 — Versioned envelope (breaking; coordinated)

- `bin/unify.py` — write the envelope `{ schema_version, generated_at, entries }`.
- `schema/malt.schema.json` — add a `schema_version` (or sidecar) and pin it.
- `bin/check.py` — validate the envelope + `schema_version`.
- `README.md` — document the envelope + versioning policy.

**Coordinated importer side (`dag-calculator`):**
- `scripts/build-fermentables-seed.mjs` — read `source.entries` (and check
  `schema_version`).
- `tests/guards/fermentables-source-contract.test.js` — assert the envelope and
  `schema_version` match the pinned contract.
- `scripts/emit-sources-manifest.mjs` — count rows via `entries`.

### C.3 — Vendor + validate the canonical schema (importer side)

- Vendor `malt.schema.json` into `dag-calculator/data/sources/` (pinned).
- Replace/augment the hand-rolled guard with validation against the pinned
  schema (or derive `ALLOWED_KEYS` from it).
- The manifest records the pinned `schema_version`.

### C.4 — `source_id` and in-row provenance (done)

**Status:** done in `afe1d4f`, extracted from the local page cache (no live
fetch). The cache is `data/source/` (462 HTML + 59 PDFs), untracked; provenance
hashes are the link back to it. Coverage on the current database: 467/467
`source_id`, 400/467 yield citations, 22 captured fermentability values
(Bairds 4 min, Dingemans 15 min, Crisp 2 point, Simpsons 1 point; the 18 Briess
basis rows stay in `yield_fraction`). Weyermann and the remaining sources
publish no fermentability.

**Extraction gaps.** Dingemans' "Final attenuation" field repeats the NDMA
limit on 19 products, so only percent-bearing values are accepted (15 rows
survive). Simpsons' figure is "un-boiled" and carries that caveat in the
citation. Crisp's peated pot-still page publishes F without a parseable
extract. Yield bounds are `unknown` in this pass; Pass 2 parses the qualifier.

Every published figure gets a stable identity and a citation:

- `source_id = "<maltster-slug>/<product-slug>"` per entry, so importer
  dedupe/crosswalk keys stop churning on renames.
- `source_url` — the page the figure came from.
- `yield_fraction` keeps its `yield_basis` (`extract` | `fermentability`) and
  gains `yield_provenance`.
- `fermentability_fraction` (nullable) gains `fermentability_provenance`.
- Provenance objects are identical in shape to the consumer's in-row provenance:
  `{ bound, kind, vendor, url, retrieved_at, sha256 }` where
  `bound ∈ point | min | max` and `kind = "vendor"`. The consumer copies them
  verbatim; it does not translate.

**The `fermentability` basis is not a yield.** Briess publishes fermentability
for 18 extracts/adjuncts with no extract figure; those entries keep the number
in `yield_fraction` with `yield_basis: "fermentability"` so the published value
is stored once. The importer reinterprets such rows (moves the number to F, leaves
yield null and resolves a yield prior). No duplicated number in the export.

**Extraction matrix (cache rerun).**

| Maltster | Anchor | Bound |
|---|---|---|
| Bairds | `Fermentability:</strong> 87.0% min` | min |
| Dingemans | `Final attenuation: min. 80.0 %` | min |
| Crisp | `Fermentability 87.2%` (desktop + mobile markup) | point |
| Simpsons | table column `Fermentability % (un-boiled)` | point |
| Briess | `box_value("Fermentability")`, stays in `yield_fraction` | point |
| Weyermann | none — PDFs publish extract/moisture/colour only | — |

Expected coverage: 23 product pages (Bairds 4, Dingemans 15, Crisp 3,
Simpsons 1) plus the 18 Briess basis rows. Everything else stays `null`. Never
impute, never clamp: a missing figure is absent, and the consumer resolves priors.

**Fetch metadata (partial on this pass).** Cached pages carry no HTTP validators,
so each provenance records the page file's `sha256` and its mtime as
`retrieved_at` (approximate). `ETag`/`Last-Modified` per page are added on the
next live fetch, enabling the conditional-refetch workflow below.

### Rescrape detection (follow-on)

URL-ifying the cached pages alone does **not** tell you which sources need
re-scraping — a URL lets you fetch again, but not whether the content changed.
To make re-scraping cheap and targeted, store, alongside each cached page, its
fetch metadata (the source URL + `ETag`/`Last-Modified`). A conditional re-fetch
(`If-None-Match` / `If-Modified-Since`) then returns `304 Not Modified` for
unchanged pages, so only the pages that actually changed (the `200`s) need
re-processing — and the per-entry `source_id` maps those pages back to the
entries whose crosswalk/reps must be re-checked.

## 5. Notes / open points

- **Envelope vs sidecar:** resolved to the `{schema_version, entries}` wrapper;
  a sidecar (`malts.json.meta`) was considered but a single envelope is simpler
  to validate atomically.
- **`yield_basis`:** already emitted; C.4 makes the importer *consume* it
  (extract vs fermentability are not interchangeable). A `fermentability` basis
  means the number is F, not extract.
- **`diastatic_power` / pH:** deferred — web-facing coverage is spotty (PDFs
  aside, and only Weyermann's PDF is in scope), and the importer's engine has no
  per-malt consumer for them.
- **`source_url`:** C.4 emits it per entry alongside `source_id`; provenance for
  audit and re-scrape diffing.
