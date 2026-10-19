#!/usr/bin/env bash
# Process Northern Brewer's Shopify JSON into intermediate JSON.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 "$ROOT/bin/extract_northern_brewer.py"
