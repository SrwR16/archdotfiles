#!/usr/bin/env bash
# Usage: apply_target.sh <desktop|lockscreen|sddm> <image_path>
#
# Applies a chosen wallpaper image to a specific target:
#   desktop    — sets it as the live wallpaper (all workspaces) + Matugen theme (default)
#   lockscreen — copies it into hyprlock's cache as its background image
#   sddm       — copies it into the SDDM theme's background (best-effort, may sudo)
set -uo pipefail

TARGET="${1:-desktop}"
WALL="${2:-}"

[ -n "$WALL" ] && [ -f "$WALL" ] || { echo "apply_target.sh: missing/invalid file: '$WALL'" >&2; exit 1; }

SHELL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$HOME/.local/state/quickshell/wallpaper_picker"
mkdir -p "$STATE"

# Resize helper: make a 1920x1080 cover image (keeps SDDM / lockscreen sane).
fit_image() { # fit_image <src> <dst>
    if command -v convert >/dev/null 2>&1; then
        convert "$1" -resize 1920x1080^ -gravity center -extent 1920x1080 "$2" 2>/dev/null || cp "$1" "$2"
    else
        cp "$1" "$2"
    fi
}

case "$TARGET" in
    desktop)
        bash "$SHELL_DIR/scripts/wallpaper.sh" "$WALL"
        printf '%s' "$WALL" > "$STATE/last.txt"
        ;;
    lockscreen)
        DEST="$HOME/.cache/dotfiles/hyprland-dotfiles/blurred_wallpaper.png"
        mkdir -p "$(dirname "$DEST")"
        if command -v convert >/dev/null 2>&1; then
            # hyprlock only accepts PNG and looks nicer slightly blurred.
            convert "$WALL" -resize 1920x1080^ -gravity center -extent 1920x1080 \
                -blur 0x18 "$DEST" 2>/dev/null || cp "$WALL" "$DEST"
        else
            cp "$WALL" "$DEST"
        fi
        printf '%s' "$WALL" > "$STATE/lockscreen.txt"
        ;;
    sddm)
        # sddm-astronaut-theme reads this same file as its Background, so the
        # picker's "set as SDDM" just refreshes the already-synced wallpaper.
        DEST="$HOME/.cache/dotfiles/hyprland-dotfiles/blurred_wallpaper.png"
        if [ -w "$(dirname "$DEST" 2>/dev/null)/." ]; then
            fit_image "$WALL" "$DEST"
        elif command -v sudo >/dev/null 2>&1; then
            sudo bash -c "$(declare -f fit_image); fit_image '$WALL' '$DEST'"
        else
            echo "apply_target.sh: cannot write $DEST (no sudo)" >&2
            exit 1
        fi
        printf '%s' "$WALL" > "$STATE/sddm.txt"
        ;;
    *)
        echo "apply_target.sh: unknown target '$TARGET'" >&2
        exit 1
        ;;
esac
