#!/usr/bin/env bash
# Fetch the Great Western product catalog + every product page.
#
# The /products/ page lists all malts under .product-archive (22 links to
# /product/<slug>/). robots.txt requests Crawl-delay: 10, so we honor it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SRC="$ROOT/data/source/great-western"
LISTING_URL="https://www.greatwesternmalting.com/products/"
LISTING="$SRC/_listing.html"

export SLEEP_SECONDS="${SLEEP_SECONDS:-10}"

mkdir -p "$SRC"

if [ ! -s "$LISTING" ]; then
  "$ROOT/bin/fetch.sh" "$LISTING_URL" "$LISTING"
fi

mapfile -t urls < <(
  pup '.product-archive a attr{href}' < "$LISTING" \
    | grep -oE 'https://[^ ]*/product/[^/]+/' \
    | sort -u \
    || true
)

if [ "${#urls[@]}" -lt 1 ]; then
  echo "layout check failed: no product links in .product-archive (Great Western markup changed?)" >&2
  exit 1
fi

fetched=0
for url in "${urls[@]}"; do
  slug="${url%/}"
  slug="${slug##*/}"
  out="$SRC/$slug.html"
  if [ -s "$out" ]; then
    continue
  fi
  "$ROOT/bin/fetch.sh" "$url" "$out"
  fetched=$((fetched + 1))
done

printf 'great-western: %d products, %d newly fetched\n' "${#urls[@]}" "$fetched"
touch "$LISTING"
