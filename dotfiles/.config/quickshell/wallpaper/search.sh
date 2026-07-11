#!/usr/bin/env bash
# Usage: search.sh "<query>"
# Runs the DDG image scraper (get_ddg_links.py), downloads each thumbnail to a
# local cache, and prints "<local_thumb_path>|<full_image_url>" per result to
# stdout. No external caching framework required.
set -uo pipefail

QUERY="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_BASE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/wallpaper_picker"
SEARCH_DIR="$CACHE_BASE/search_thumbs"
mkdir -p "$SEARCH_DIR"

python3 -u "$SCRIPT_DIR/get_ddg_links.py" "$QUERY" 2>/dev/null | while IFS='|' read -r thumb_url full_url; do
    [ -z "${thumb_url:-}" ] && continue
    uuid="$(date +%s%N)"
    ext="${full_url##*.}"; ext="${ext%%\?*}"; ext="$(echo "$ext" | tr '[:upper:]' '[:lower:]')"
    case "$ext" in jpg|jpeg|png|webp|gif|bmp) ;; *) ext="jpg" ;; esac
    fname="ddg_${uuid}.${ext}"
    fpath="$SEARCH_DIR/$fname"
    tmp="${fpath}.tmp"

    curl -s -L -m 8 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" "$thumb_url" -o "$tmp" || continue
    [ -s "$tmp" ] || { rm -f "$tmp"; continue; }

    mime="$(file -b --mime-type "$tmp" 2>/dev/null)"
    case "$mime" in
        image/webp)
            if command -v magick >/dev/null 2>&1; then
                magick "$tmp" "$fpath" 2>/dev/null && rm -f "$tmp" || mv "$tmp" "$fpath"
            else
                mv "$tmp" "$fpath"
            fi
            ;;
        image/*) mv "$tmp" "$fpath" ;;
        *) rm -f "$tmp"; continue ;;
    esac

    echo "$fpath|$full_url"
done

echo "DONE"
