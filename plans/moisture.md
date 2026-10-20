# Moisture retrofit — implementation plan

**Status:** draft (not implemented). **Estimate:** ~2.5–4 h (mostly editing
existing extractors + re-processing; little/no re-fetch).

## 1. Goal

Add a canonical **`moisture`** field (percent, e.g. 4.5) and capture it wherever
a source publishes it. Moisture is widely available in our **already-cached
HTML** — we simply never extracted it.

## 2. Scope (where moisture exists)

| Source | Location |
|---|---|
| Briess | "Moisture" data box |
| Bairds | IOB/EBC/ASBC table "Moisture %" |
| Simpsons | ASBC tab "Moisture %" |
| Fawcett | spec tables "Moisture %" |
| Gambrinus | specs "Moisture % Max" |
| Great Western | stats "Moisture" |
| Bestmalz | table "Moisture content" |
| Dingemans | technical specs "Moisture" |
| Canada Malting | "Moisture %" |
| Crisp | table "Moisture" |
| Brewtarget | `fermentable.moisture` column |
| Northern Brewer | soft sugars "Moisture ≤ 2.5%" (syrups: none) |
| Williams | none (syrups report Brix, not moisture) |
| Weyermann (Plan A) | `Moisture content` in the spec PDF |

## 3. Changes

- `schema/malt.schema.json` — add `moisture` (number 0–100, optional).
- Each `bin/<maltster>.jq` / `bin/extract_*.py` — also extract `moisture_pct`.
- Per-maltster `schema/*.schema.json` — add `moisture_pct`.
- `bin/unify.py` — map `moisture_pct` → `moisture` (pass-through; percent).
- `bin/check.py` — report moisture coverage **only** (no floor; many sources omit it).
- `README.md` — document the field and its availability.

## 4. Notes / decisions

- **Value convention:** store the reported value as a percent; moisture is
  typically a "max" spec (`≤ 4.0%` → 4.0). Where a source gives only one number,
  use it.
- **Rescrape vs re-process:** moisture is already in the cached HTML, so
  re-running `make <maltster>` (process-only, after the `.jq` change) populates
  it **without re-fetching**. Because `data/` is gitignored, a fresh clone or
  `make clean` will re-fetch and re-extract on the next full build — the
  "future build rescrape".
- **Omitted where absent:** syrups/sugars often have no moisture; leave
  `moisture` null there (coverage is reported by `check.py`, not enforced).

## 5. Decisions (resolved)

1. **Canonical field name:** `moisture` (percent, e.g. 4.5). Intermediate extractors
   keep emitting `moisture_pct`; `unify.py` maps it to `moisture`.
2. **Quality gate:** `make check` reports moisture coverage only; **no hard floor**,
   since syrups/sugars and several maltsters omit it. (Weyermann depends on this plan
   and provides `Moisture content` from its spec PDFs.)
