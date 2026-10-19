#!/usr/bin/env bash
# Fetch the Bestmalz malt catalog + every malt page.
#
# The English catalog page lists malts under div.malz-wrapper (43 unique links
# to /en/malts/<slug>/). robots.txt has no crawl-delay, so the default 2s
# sleep applies.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SRC="$ROOT/data/source/bestmalz"
LISTING_URL="https://bestmalz.de/en/bestmalz-bestmalts-the-best-in-beer/"
LISTING="$SRC/_listing.html"

mkdir -p "$SRC"

if [ ! -s "$LISTING" ]; then
  "$ROOT/bin/fetch.sh" "$LISTING_URL" "$LISTING"
fi

mapfile -t urls < <(
  pup 'div.malz-wrapper a attr{href}' < "$LISTING" \
    | grep -oE 'https://bestmalz.de/en/malts/[^/]+/' \
    | sort -u \
    || true
)

if [ "${#urls[@]}" -lt 1 ]; then
  echo "layout check failed: no malt links in div.malz-wrapper (Bestmalz markup changed?)" >&2
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

printf 'bestmalz: %d malts, %d newly fetched\n' "${#urls[@]}" "$fetched"
