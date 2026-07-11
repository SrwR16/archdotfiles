#!/usr/bin/env bash
# Usage: save_url.sh <url> <output_path>
# Downloads <url> to <output_path>, creating parent dirs. Used to fetch the
# full-resolution image for an online search result before applying it.
set -euo pipefail

URL="$1"
OUT="$2"

mkdir -p "$(dirname "$OUT")"
curl -s -L -m 40 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" "$URL" -o "$OUT"
