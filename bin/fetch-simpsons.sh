#!/usr/bin/env bash
# Fetch the Simpsons malt listing + every individual malt page into the cache.
#
# The /our-malts/ page has three .content .container elements; only the third
# (index 2) holds links. It contains 7 category-index links plus the 45
# individual malt links (/our-malts/<category>/<slug>/), which we keep.
# robots.txt returns 404, so the default polite delay (SLEEP_SECONDS=2) applies.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SRC="$ROOT/data/source/simpsons"
INDEX_URL="https://www.simpsonsmalt.co.uk/our-malts/"
INDEX="$SRC/our-malts.html"

mkdir -p "$SRC"

if [ ! -s "$INDEX" ]; then
  "$ROOT/bin/fetch.sh" "$INDEX_URL" "$INDEX"
fi

mapfile -t paths < <(
  pup '.content .container json{}' < "$INDEX" \
    | jq -r '.[2] | .. | objects | select(.tag == "a") | .href // empty' \
    | grep -E '^/our-malts/[^/]+/[^/]+/$' \
    | sort -u \
    || true
)

if [ "${#paths[@]}" -lt 1 ]; then
  echo "layout check failed: no malt links in third .content .container (Simpsons markup changed?)" >&2
  exit 1
fi

fetched=0
for p in "${paths[@]}"; do
  slug="${p%/}"
  slug="${slug##*/}"
  out="$SRC/$slug.html"
  if [ -s "$out" ]; then
    printf 'cached (exists) %s\n' "$out"
    continue
  fi
  "$ROOT/bin/fetch.sh" "https://www.simpsonsmalt.co.uk${p}" "$out"
  fetched=$((fetched + 1))
done

printf 'simpsons: %d total malts, %d newly fetched\n' "${#paths[@]}" "$fetched"
touch "$INDEX"
