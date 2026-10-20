# Import contract — a versioned, well-typed seam to the dag-calculator

**Status:** C.1, C.2, C.3 done (committed in both repos). **C.4 deferred** — do it
on the next rescrape. **Estimate:** ~3–4 h (schema/envelope + null-vs-0 + a
coordinated change in `dag-calculator`).

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

### C.4 — Stable `source_id` (deferred — TODO on next rescrape)

**TODO (do on the next rescrape):** emit `source_id = "<maltster-slug>/<product-slug>"`
per entry so the importer's dedupe/crosswalk keys stop churning on renames. Pair
this with **fetch metadata** (the exact fetched URL + HTTP `ETag`/`Last-Modified`
per cached page) — see the rescrape-detection note below — so a future re-run can
cheaply answer "which sources changed".

- Emit `source_id` per entry.
- Importer may later use it for dedupe/crosswalk stability (no immediate change).

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
- **`yield_basis`:** already emitted; the importer should *consume* it (extract
  vs fermentability are not interchangeable) — an importer-side follow-up, not a
  contract change.
- **`diastatic_power` / pH:** deferred — web-facing coverage is spotty (PDFs
  aside, and only Weyermann's PDF is in scope), and the importer's engine has no
  per-malt consumer for them.
- **`source_url`:** optional provenance for audit/re-scrape diffing; no engine
  consumer. Deferred.
