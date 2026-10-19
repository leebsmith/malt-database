#!/usr/bin/env bash
# Process the cached Fawcett malt pages into intermediate JSON.
#
# Output: data/maltsters/fawcett.json (array of raw, maltster-native objects,
# validated against schema/fawcett.schema.json). The index (slug, category,
# url) built by fetch-fawcett.sh drives extraction and supplies category_hint.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SRC="$ROOT/data/source/fawcett"
INDEX="$SRC/index.tsv"
OUT="$ROOT/data/maltsters/fawcett.json"

if [ ! -s "$INDEX" ]; then
  echo "no index at $INDEX; run \`make fawcett\` first" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

count=0
while IFS=$'\t' read -r slug category url; do
  html="$SRC/$slug.html"
  if [ ! -s "$html" ]; then
    echo "missing cached page: $html" >&2
    exit 1
  fi

  # Pre-parse layout check: every malt page must carry its name in an <h1>.
  if [ "$(pup 'h1 json{}' < "$html" | jq 'length')" -lt 1 ]; then
    echo "layout check failed: $slug missing <h1> (Fawcett markup changed?)" >&2
    exit 1
  fi

  pup 'html json{}' < "$html" \
    | jq -c -f "$ROOT/bin/fawcett.jq" --arg slug "$slug" --arg category "$category" >> "$tmp"
  count=$((count + 1))
done < "$INDEX"

jq -s '.' "$tmp" > "$OUT"

printf 'wrote %d malts -> %s\n' "$(jq 'length' "$OUT")" "$OUT"
