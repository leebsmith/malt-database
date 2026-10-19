#!/usr/bin/env bash
# Fetch Dingemans malts from its sitemap (36 /malt/<slug> pages).
# robots.txt requests Crawl-delay: 10, so we honor it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export SLEEP_SECONDS="${SLEEP_SECONDS:-10}"

"$ROOT/bin/fetch-sitemap.sh" dingemans \
  "https://www.dingemansmout.be/sitemap.xml" \
  '/malt/[^/]+$'
