#!/usr/bin/env bash
# Fetch Canada Malting's English malt catalog (24 /malts/<slug> pages).
# The malts sitemap also lists French /fr/malts/ duplicates; the regex matches
# only the English URLs (canadamalting.com/malts/...). robots.txt requests
# Crawl-delay: 10, so we honor it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export SLEEP_SECONDS="${SLEEP_SECONDS:-10}"

"$ROOT/bin/fetch-sitemap.sh" canada-malting \
  "https://canadamalting.com/malts-sitemap.xml" \
  'canadamalting.com/malts/[^/]+/'
