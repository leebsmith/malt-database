#!/usr/bin/env bash
# Fetch the Briess product listing page into the cache.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT/bin/fetch.sh" \
  "https://brewingwithbriess.com/products/" \
  "$ROOT/data/source/briess/products.html"
