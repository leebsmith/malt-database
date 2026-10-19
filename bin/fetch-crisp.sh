#!/usr/bin/env bash
# Fetch Crisp malt pages from its sitemap (49 English /malts/<slug> pages).
# The sitemap also lists /en-us/malts/ duplicates; the regex matches only the
# non-locale URLs. robots.txt has no crawl-delay (default 2s sleep).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT/bin/fetch-sitemap.sh" crisp \
  "https://crispmalt.com/malts-sitemap.xml" \
  'crispmalt.com/malts/[^/]+/'
