#!/usr/bin/env bash
# Fetch Northern Brewer's Belgian candi sugar collection as Shopify products
# JSON (names, vendors, descriptions). CSI-branded products are filtered out
# later by the extractor.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OUT="$ROOT/data/source/northern-brewer/products.json"

"$ROOT/bin/fetch.sh" \
  "https://www.northernbrewer.com/collections/belgian-candi-sugar/products.json?limit=250" \
  "$OUT"
touch "$OUT"
