#!/usr/bin/env bash
# Process cached Weyermann product pages + spec PDFs into intermediate JSON.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 "$ROOT/bin/extract_weyermann.py"
