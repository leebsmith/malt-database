#!/usr/bin/env bash
# Generic sitemap-driven fetcher.
#
# Usage: fetch-sitemap.sh <maltster> <sitemap_url> <url_regex>
#
# Caches the sitemap to data/source/<maltster>/_sitemap.xml, extracts <loc>
# entries matching <url_regex>, dedupes, then fetches each page to
# data/source/<maltster>/<slug>.html (skip-if-cached). Honors SLEEP_SECONDS
# via bin/fetch.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

maltster="$1"
sitemap_url="$2"
url_regex="${3:-.}"

SRC="$ROOT/data/source/$maltster"
SITEMAP="$SRC/_sitemap.xml"

mkdir -p "$SRC"

if [ ! -s "$SITEMAP" ]; then
  "$ROOT/bin/fetch.sh" "$sitemap_url" "$SITEMAP"
fi

mapfile -t urls < <(
  grep -oE '<loc>[^<]+</loc>' "$SITEMAP" \
    | sed 's#</\?loc>##g' \
    | grep -E "$url_regex" \
    | sort -u \
    || true
)

if [ "${#urls[@]}" -lt 1 ]; then
  echo "layout check failed: no <loc> entries matched '$url_regex' in $SITEMAP" >&2
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

printf '%s: %d products, %d newly fetched\n' "$maltster" "${#urls[@]}" "$fetched"
touch "$SITEMAP"
