#!/usr/bin/env bash
# Process the cached Canada Malting pages into intermediate JSON.
#
# Output: data/maltsters/canada-malting.json (array of raw, maltster-native
# objects, validated against schema/canada-malting.schema.json).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SRC="$ROOT/data/source/canada-malting"
OUT="$ROOT/data/maltsters/canada-malting.json"

mkdir -p "$(dirname "$OUT")"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

count=0
for html in "$SRC"/*.html; do
  slug="$(basename "$html" .html)"

  # Pre-parse layout check: every product page must carry its name in an <h1>.
  if [ "$(pup 'div.product-details h1 json{}' < "$html" | jq 'length')" -lt 1 ]; then
    echo "layout check failed: $slug missing div.product-details h1 (Canada Malting markup changed?)" >&2
    exit 1
  fi

  pup 'html json{}' < "$html" \
    | jq -c -f "$ROOT/bin/canada-malting.jq" --arg slug "$slug" >> "$tmp"
  count=$((count + 1))
done

if [ "$count" -lt 1 ]; then
  echo "no malt pages found in $SRC; run \`make canada-malting\` first" >&2
  exit 1
fi

jq -s '.' "$tmp" > "$OUT"

printf 'wrote %d malts -> %s\n' "$(jq 'length' "$OUT")" "$OUT"
