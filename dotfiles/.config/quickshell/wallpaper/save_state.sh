#!/usr/bin/env bash
# Usage: save_state.sh <key> <value>
# Persists a small piece of wallpaper-picker state (e.g. "dir" or "last")
# under the quickshell state dir so it survives reboots.
set -euo pipefail

KEY="$1"
VAL="$2"
D="$HOME/.local/state/quickshell/wallpaper_picker"
mkdir -p "$D"
printf '%s' "$VAL" > "$D/$KEY.txt"
