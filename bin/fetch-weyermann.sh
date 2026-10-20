#!/usr/bin/env bash
# Fetch Weyermann's English catalog: sitemap -> product pages -> spec PDFs.
# robots.txt has no crawl-delay for *. Duplicate product slugs (WooCommerce
# appends -2/-3/... per category/locale) share one spec PDF, so PDFs are
# deduped by URL. Only the _Specification.pdf is downloaded (analysis + aroma
# wheel PDFs are unused).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/data/source/weyermann"
SITEMAP_URL="https://www.weyermann.de/en-gb/wp-sitemap-posts-portfolio-1.xml"
SITEMAP="$SRC/_sitemap.xml"
PDF_DIR="$SRC/pdf"

mkdir -p "$SRC" "$PDF_DIR"

if [ ! -s "$SITEMAP" ]; then
  "$ROOT/bin/fetch.sh" "$SITEMAP_URL" "$SITEMAP"
fi

mapfile -t urls < <(
  grep -oE '<loc>[^<]+</loc>' "$SITEMAP" \
    | sed 's#</\?loc>##g' \
    | grep -E '/en-gb/product/' \
    | sort -u \
    || true
)

if [ "${#urls[@]}" -lt 1 ]; then
  echo "layout check failed: no /en-gb/product/ URLs in $SITEMAP" >&2
  exit 1
fi

fetched=0
for url in "${urls[@]}"; do
  slug="${url%/}"; slug="${slug##*/}"
  out="$SRC/$slug.html"
  if [ -s "$out" ]; then
    continue
  fi
  "$ROOT/bin/fetch.sh" "$url" "$out"
  fetched=$((fetched + 1))
done

mapfile -t pdf_urls < <(
  grep -hoiE 'href="[^"]*_Specification[^"]*\.pdf[^"]*"' "$SRC"/*.html \
    | sed -E 's/^href="//; s/"$//' \
    | sort -u \
    || true
)

pdfs_fetched=0
for url in "${pdf_urls[@]}"; do
  name="$(basename "$url")"
  out="$PDF_DIR/$name"
  if [ -s "$out" ]; then
    continue
  fi
  enc="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=":/"))' "$url")"
  if "$ROOT/bin/fetch.sh" "$enc" "$out"; then
    pdfs_fetched=$((pdfs_fetched + 1))
  else
    echo "warning: skipping unavailable spec PDF: $url" >&2
  fi
done

touch "$SITEMAP"
printf 'weyermann: %d products, %d pages fetched, %d PDFs fetched\n' \
  "${#urls[@]}" "$fetched" "$pdfs_fetched"
