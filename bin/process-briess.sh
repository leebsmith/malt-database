#!/usr/bin/env bash
# Process the cached Briess listing HTML into intermediate JSON.
#
# Output: data/maltsters/briess.json (array of raw, maltster-native objects,
# validated against schema/briess.schema.json). Malts report "Yield on grind";
# extracts/adjuncts report "Fermentability" instead -- both are captured here
# and normalized to yield_fraction by unify.py.
#
# The extraction logic lives in bin/briess.jq so it can be edited and tested
# standalone (no bash string-quoting).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

IN="$ROOT/data/source/briess/products.html"
OUT="$ROOT/data/maltsters/briess.json"

# ---------------------------------------------------------------------------
# Pre-parse layout contract: fail early (with a clear message) if the cached
# HTML no longer matches the layout we depend on.
# ---------------------------------------------------------------------------
count=$(pup 'article.product json{}' < "$IN" | jq 'length')
if [ "$count" -lt 1 ]; then
  echo "layout check failed: expected at least one article.product, found $count (Briess page changed?)" >&2
  exit 1
fi

for sel in '.product-title' '.product-description' '.data-box-filled.srm'; do
  n=$(pup "$sel json{}" < "$IN" | jq 'length')
  if [ "$n" -lt 1 ]; then
    echo "layout check failed: selector '$sel' not found (Briess markup changed?)" >&2
    exit 1
  fi
done

titles=$(pup '.product-title json{}' < "$IN" | jq 'length')
if [ "$count" -ne "$titles" ]; then
  echo "layout check failed: $count article.product cards but $titles .product-title (a card lost its title?)" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"

pup 'article.product json{}' < "$IN" | jq -c -f "$ROOT/bin/briess.jq" > "$OUT"

printf 'wrote %d malts -> %s\n' "$(jq 'length' "$OUT")" "$OUT"
