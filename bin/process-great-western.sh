#!/usr/bin/env bash
# Process the cached Great Western product pages into intermediate JSON.
#
# Output: data/maltsters/great-western.json (array of raw, maltster-native
# objects, validated against schema/great-western.schema.json).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SRC="$ROOT/data/source/great-western"
OUT="$ROOT/data/maltsters/great-western.json"

mkdir -p "$(dirname "$OUT")"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

count=0
for html in "$SRC"/*.html; do
  slug="$(basename "$html" .html)"
  [ "$slug" = "_listing" ] && continue

  # Pre-parse layout check: every product page must carry its name in h1.name.
  if [ "$(pup 'h1.name json{}' < "$html" | jq 'length')" -lt 1 ]; then
    echo "layout check failed: $slug missing h1.name (Great Western markup changed?)" >&2
    exit 1
  fi

  pup 'html json{}' < "$html" \
    | jq -c -f "$ROOT/bin/great-western.jq" --arg slug "$slug" >> "$tmp"
  count=$((count + 1))
done

if [ "$count" -lt 1 ]; then
  echo "no product pages found in $SRC; run \`make great-western\` first" >&2
  exit 1
fi

jq -s '.' "$tmp" > "$OUT"

printf 'wrote %d malts -> %s\n' "$(jq 'length' "$OUT")" "$OUT"
