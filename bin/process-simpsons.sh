#!/usr/bin/env bash
# Process the cached Simpsons malt pages into intermediate JSON.
#
# Output: data/maltsters/simpsons.json (array of raw, maltster-native objects,
# validated against schema/simpsons.schema.json). Each cached page is
# data/source/simpsons/<slug>.html (our-malts.html is skipped).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SRC="$ROOT/data/source/simpsons"
OUT="$ROOT/data/maltsters/simpsons.json"

mkdir -p "$(dirname "$OUT")"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

count=0
for html in "$SRC"/*.html; do
  slug="$(basename "$html" .html)"
  [ "$slug" = "our-malts" ] && continue

  # Pre-parse layout check: every malt page must carry its name in an <h1>.
  if [ "$(pup 'h1 json{}' < "$html" | jq 'length')" -lt 1 ]; then
    echo "layout check failed: $slug missing <h1> (Simpsons markup changed?)" >&2
    exit 1
  fi

  pup 'html json{}' < "$html" \
    | jq -c -f "$ROOT/bin/simpsons.jq" --arg slug "$slug" >> "$tmp"
  count=$((count + 1))
done

if [ "$count" -lt 1 ]; then
  echo "no malt pages found in $SRC; run \`make simpsons\` first" >&2
  exit 1
fi

jq -s '.' "$tmp" > "$OUT"

printf 'wrote %d malts -> %s\n' "$(jq 'length' "$OUT")" "$OUT"
