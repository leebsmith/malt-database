#!/usr/bin/env bash
# Process the cached Bestmalz malt pages into intermediate JSON.
#
# Output: data/maltsters/bestmalz.json (array of raw, maltster-native objects,
# validated against schema/bestmalz.schema.json).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SRC="$ROOT/data/source/bestmalz"
OUT="$ROOT/data/maltsters/bestmalz.json"

mkdir -p "$(dirname "$OUT")"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

count=0
for html in "$SRC"/*.html; do
  slug="$(basename "$html" .html)"
  [ "$slug" = "_listing" ] && continue

  # Pre-parse layout check: every malt page must carry its name in an <h1>.
  if [ "$(pup 'div.kt-inside-inner-col h1 json{}' < "$html" | jq 'length')" -lt 1 ]; then
    echo "layout check failed: $slug missing h1 (Bestmalz markup changed?)" >&2
    exit 1
  fi

  pup 'html json{}' < "$html" \
    | jq -c -f "$ROOT/bin/bestmalz.jq" --arg slug "$slug" >> "$tmp"
  count=$((count + 1))
done

if [ "$count" -lt 1 ]; then
  echo "no malt pages found in $SRC; run \`make bestmalz\` first" >&2
  exit 1
fi

jq -s '.' "$tmp" > "$OUT"

printf 'wrote %d malts -> %s\n' "$(jq 'length' "$OUT")" "$OUT"
