#!/usr/bin/env bash
# Process the cached Crisp malt pages into intermediate JSON.
#
# Output: data/maltsters/crisp.json (array of raw, maltster-native objects,
# validated against schema/crisp.schema.json).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SRC="$ROOT/data/source/crisp"
OUT="$ROOT/data/maltsters/crisp.json"

mkdir -p "$(dirname "$OUT")"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

count=0
for html in "$SRC"/*.html; do
  slug="$(basename "$html" .html)"

  # Pre-parse layout check: every malt page must carry its name in breadcrumb h1.
  if [ "$(pup 'section.breadcrumb h1 json{}' < "$html" | jq 'length')" -lt 1 ]; then
    echo "layout check failed: $slug missing section.breadcrumb h1 (Crisp markup changed?)" >&2
    exit 1
  fi

  pup 'html json{}' < "$html" \
    | jq -c -f "$ROOT/bin/crisp.jq" --arg slug "$slug" >> "$tmp"
  count=$((count + 1))
done

if [ "$count" -lt 1 ]; then
  echo "no malt pages found in $SRC; run \`make crisp\` first" >&2
  exit 1
fi

jq -s '.' "$tmp" > "$OUT"

printf 'wrote %d malts -> %s\n' "$(jq 'length' "$OUT")" "$OUT"
