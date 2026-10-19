#!/usr/bin/env bash
# Fetch the Bairds malt listing + every individual malt page into the cache.
#
# Discovery trail: robots.txt -> divi_mega_pro-sitemap.xml -> /divi_mega_pro/malt-menu/
# The malt-menu page lists all 29 malts; each is fetched to data/source/bairds/<slug>.html.
# Bairds robots.txt requests Crawl-delay: 10, which we honor.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SRC="$ROOT/data/source/bairds"
MENU_URL="https://www.bairds-malt.co.uk/divi_mega_pro/malt-menu/"
MENU="$SRC/malt-menu.html"

export SLEEP_SECONDS="${SLEEP_SECONDS:-10}"

mkdir -p "$SRC"

if [ ! -s "$MENU" ]; then
  "$ROOT/bin/fetch.sh" "$MENU_URL" "$MENU"
fi

mapfile -t links < <(pup '.entry-content ul:not(.et_mobile_menu) a attr{href}' < "$MENU" | sort -u)

if [ "${#links[@]}" -lt 1 ]; then
  echo "layout check failed: no malt links found on malt-menu page (Bairds markup changed?)" >&2
  exit 1
fi

fetched=0
for url in "${links[@]}"; do
  slug="${url%/}"
  slug="${slug##*/}"
  out="$SRC/$slug.html"
  if [ -s "$out" ]; then
    printf 'cached (exists) %s\n' "$out"
    continue
  fi
  "$ROOT/bin/fetch.sh" "$url" "$out"
  fetched=$((fetched + 1))
done

printf 'bairds: %d total malts, %d newly fetched\n' "${#links[@]}" "$fetched"
touch "$MENU"
