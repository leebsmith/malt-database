#!/usr/bin/env bash
# Fetch Williams Brewing's candi-syrup category and its two product pages
# (Belgian Dark and Amber candi syrup). robots.txt has no crawl-delay for *.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SRC="$ROOT/data/source/williams"
LISTING_URL="https://www.williamsbrewing.com/Home-Brewing-Supplies/Malted-Grain-Sugar/Candi-Syrups"
LISTING="$SRC/candi-syrups.html"

mkdir -p "$SRC"

if [ ! -s "$LISTING" ]; then
  "$ROOT/bin/fetch.sh" "$LISTING_URL" "$LISTING"
fi

mapfile -t paths < <(
  pup 'a attr{href}' < "$LISTING" \
    | grep -oiE '/Home-Brewing-Supplies/[^" ]*/[^/"]*Candi-Syrup/?$' \
    | sort -u \
    || true
)

if [ "${#paths[@]}" -lt 1 ]; then
  echo "layout check failed: no candi-syrup product links on $LISTING" >&2
  exit 1
fi

fetched=0
for p in "${paths[@]}"; do
  p="${p%/}"
  slug="${p##*/}"
  out="$SRC/$slug.html"
  if [ -s "$out" ]; then
    continue
  fi
  if [[ "$p" == http* ]]; then
    url="$p"
  else
    url="https://www.williamsbrewing.com$p"
  fi
  "$ROOT/bin/fetch.sh" "$url" "$out"
  fetched=$((fetched + 1))
done

touch "$LISTING"
printf 'williams: %d syrups, %d newly fetched\n' "${#paths[@]}" "$fetched"
