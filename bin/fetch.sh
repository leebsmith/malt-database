#!/usr/bin/env bash
# Generic curl wrapper: download a URL into the project cache.
#
# Usage: fetch.sh <url> <output_path>
set -euo pipefail

url="$1"
out="$2"

mkdir -p "$(dirname "$out")"

curl -fsSL \
  --compressed \
  --retry 3 \
  --retry-delay 2 \
  --user-agent "malt-database/0.1 (+local scraper)" \
  "$url" -o "$out"

printf 'cached %s -> %s\n' "$url" "$out"
