#!/usr/bin/env bash
# Process Brewtarget's SQLite database into the sugar intermediate JSON.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 "$ROOT/bin/extract_brewtarget.py"
