#!/usr/bin/env bash
# Fetch Gambrinus malts from its product sitemap (18 products).
# robots.txt requests no crawl-delay, so the default 2s sleep applies.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT/bin/fetch-sitemap.sh" gambrinus \
  "https://gambrinusmalting.com/product-sitemap.xml" \
  'gambrinusmalting.com/[^/]+/$'
