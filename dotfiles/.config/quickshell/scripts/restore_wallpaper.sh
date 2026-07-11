#!/usr/bin/env bash
# Re-applies the last wallpaper chosen in the picker on login/reboot.
# Reads the persisted path and sets it via the same code path used by the
# live picker (scripts/wallpaper.sh for images, set_video.sh for video),
# so the wallpaper AND its Matugen theme are restored.
set -uo pipefail

F="$HOME/.local/state/quickshell/wallpaper_picker/last.txt"
[ -f "$F" ] || exit 0

P="$(cat "$F")"
[ -n "$P" ] && [ -f "$P" ] || exit 0

SHELL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$P" in
    *.mp4|*.webm|*.mov|*.MP4|*.WEBM|*.MOV)
        bash "$SHELL_DIR/wallpaper/set_video.sh" "$P" ;;
    *)
        bash "$SHELL_DIR/scripts/wallpaper.sh" "$P" ;;
esac
