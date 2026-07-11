#!/usr/bin/env bash
# Usage: set_video.sh <video_path>
# Stops any running mpvpaper instance and sets <video_path> as an animated
# wallpaper across all outputs.
set -euo pipefail

WALL="$1"
[ -n "$WALL" ] && [ -f "$WALL" ] || { echo "set_video.sh: file not found: $WALL" >&2; exit 1; }

pkill -f mpvpaper 2>/dev/null || true
sleep 0.3

mpvpaper -o "no-audio --loop --keepaspect=no" "*" "$WALL" >/dev/null 2>&1 &
disown
