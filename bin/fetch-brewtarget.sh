#!/usr/bin/env bash
# Fetch Brewtarget's default ingredient database (GPLv3) as the open sugar
# source: https://github.com/Brewtarget/brewtarget
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OUT="$ROOT/data/source/brewtarget/default_db.sqlite"

"$ROOT/bin/fetch.sh" \
  "https://raw.githubusercontent.com/Brewtarget/brewtarget/main/data/default_db.sqlite" \
  "$OUT"
touch "$OUT"
