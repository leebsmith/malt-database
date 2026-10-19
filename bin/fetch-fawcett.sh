#!/usr/bin/env bash
# Fetch the Fawcett brewing-malt catalog + every individual malt page.
#
# The /our-malts/category/brewing-malts/ page groups malts into div.malt-type
# blocks; each block has an <h2> category and links to /malt/<slug>/. We cache
# the listing, build data/source/fawcett/index.tsv (slug, category, url), then
# fetch each malt page. robots.txt requests no crawl-delay, so SLEEP_SECONDS
# stays at the default (2s).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SRC="$ROOT/data/source/fawcett"
LISTING_URL="https://www.fawcett-maltsters.co.uk/our-malts/category/brewing-malts/"
LISTING="$SRC/brewing-malts.html"
INDEX="$SRC/index.tsv"

mkdir -p "$SRC"

if [ ! -s "$LISTING" ]; then
  "$ROOT/bin/fetch.sh" "$LISTING_URL" "$LISTING"
fi

pup 'div.malt-type json{}' < "$LISTING" \
  | jq -r '.[]
      | ([.. | objects | select(.tag=="h2") | .text][0] // ""
          | gsub("^[ \t\n\r]+|[ \t\n\r]+$"; "")) as $c
      | [.. | objects | select(.tag=="a")
          | select((.href // "") | test("/malt/[^/]+/")) | .href][]
      | . as $u
      | ($u | gsub("/$"; "") | split("/") | last) as $slug
      | [$slug, $c, $u] | @tsv' \
  | sort -u > "$INDEX"

n=$(wc -l < "$INDEX")
if [ "$n" -lt 1 ]; then
  echo "layout check failed: no malts found in div.malt-type (Fawcett markup changed?)" >&2
  exit 1
fi

fetched=0
while IFS=$'\t' read -r slug category url; do
  out="$SRC/$slug.html"
  if [ -s "$out" ]; then
    continue
  fi
  "$ROOT/bin/fetch.sh" "$url" "$out"
  fetched=$((fetched + 1))
done < "$INDEX"

printf 'fawcett: %d malts, %d newly fetched\n' "$n" "$fetched"
