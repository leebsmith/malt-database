#!/usr/bin/env bash
# Process the cached Bairds malt pages into intermediate JSON.
#
# Output: data/maltsters/bairds.json (array of raw, maltster-native objects,
# validated against schema/bairds.schema.json). Each cached page is
# data/source/bairds/<slug>.html (malt-menu.html is skipped).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SRC="$ROOT/data/source/bairds"
OUT="$ROOT/data/maltsters/bairds.json"

mkdir -p "$(dirname "$OUT")"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

count=0
for html in "$SRC"/*.html; do
  slug="$(basename "$html" .html)"
  [ "$slug" = "malt-menu" ] && continue

  # Pre-parse layout check: every malt page must carry its name in an <h1>.
  if [ "$(pup '.et_pb_text_inner h1 json{}' < "$html" | jq 'length')" -lt 1 ]; then
    echo "layout check failed: $slug missing .et_pb_text_inner h1 (Bairds markup changed?)" >&2
    exit 1
  fi

  pup 'html json{}' < "$html" \
    | jq -c -f "$ROOT/bin/bairds.jq" --arg slug "$slug" >> "$tmp"
  count=$((count + 1))
done

if [ "$count" -lt 1 ]; then
  echo "no malt pages found in $SRC; run \`make bairds\` first" >&2
  exit 1
fi

jq -s '.' "$tmp" > "$OUT"

printf 'wrote %d malts -> %s\n' "$(jq 'length' "$OUT")" "$OUT"
