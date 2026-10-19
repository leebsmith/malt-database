#!/usr/bin/env bash
# Process the cached Williams Brewing candi-syrup pages into intermediate JSON.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 "$ROOT/bin/extract_williams.py"
