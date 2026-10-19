#!/usr/bin/env bash
# Generic curl wrapper: download a URL into the project cache.
#
# Usage: fetch.sh <url> <output_path>
#
# Identifies as a polite bot and, after each download, sleeps SLEEP_SECONDS
# (default 2) to be gentle on the target. Override per-maltster (e.g. Bairds
# requests a 10s crawl-delay).
set -euo pipefail

url="$1"
out="$2"

mkdir -p "$(dirname "$out")"

curl -fsSL \
  --compressed \
  --retry 3 \
  --retry-delay 2 \
  --user-agent "BotMaltHomebrewer/0.1 (+leeb@lee-smith.org)" \
  --header "From: leeb@lee-smith.org" \
  "$url" -o "$out"

printf 'cached %s -> %s\n' "$url" "$out"

sleep "${SLEEP_SECONDS:-2}"
