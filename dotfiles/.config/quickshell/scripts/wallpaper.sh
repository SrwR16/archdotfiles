#!/usr/bin/env bash
# Usage: wallpaper.sh <path>
# Sets wallpaper, generates Matugen palette (writes directly to config targets).
# Matugen's config.toml handles output paths and qs reload.
set -euo pipefail

WALL="$1"
[ -n "$WALL" ] && [ -f "$WALL" ] || { echo "wallpaper.sh: file not found: $WALL" >&2; exit 1; }

export PATH="$HOME/.cargo/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

if command -v awww &>/dev/null; then
  awww img "$WALL"
elif command -v feh &>/dev/null; then
  feh --bg-fill "$WALL"
fi

if ! command -v matugen &>/dev/null; then exit 0; fi

matugen image "$WALL" -m dark --prefer darkness --type scheme-fidelity -c "$HOME/.config/matugen/config.toml" 2>/dev/null || true

# Matugen writes its colors to ~/.config/dotfiles/colors/colors.json (per
# config.toml), but the live shell reads theme/colors.json for its palette.
# Normalize the matugen output into the flat key names MatugenColors.qml
# expects so the shell theme updates on apply.
SHELL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEME_JSON="$SHELL_DIR/theme/colors.json"
MATUGEN_JSON="$HOME/.config/dotfiles/colors/colors.json"

if [ -f "$MATUGEN_JSON" ]; then
  python3 - "$MATUGEN_JSON" "$THEME_JSON" <<'PY'
import json, sys
src, dst = sys.argv[1], sys.argv[2]
try:
    with open(src) as f:
        c = json.load(f)
except Exception:
    sys.exit(0)

def g(*keys, default="#000000"):
    v = c
    for k in keys:
        if not isinstance(v, dict) or k not in v:
            return default
        v = v[k]
    return v if isinstance(v, str) else default

out = {
    "background":        g("background"),
    "surface":          g("surface"),
    "surfaceBright":     g("surface_bright"),
    "surfaceDim":        g("surface_dim"),
    "surfaceContainer":  g("surface_container"),
    "surfaceVariant":    g("surface_variant"),
    "primary":           g("primary"),
    "primaryFg":         g("on_primary"),
    "secondary":         g("secondary"),
    "tertiary":          g("tertiary"),
    "backgroundFg":      g("on_background"),
    "surfaceFg":         g("on_surface"),
    "surfaceVariantFg":  g("on_surface_variant"),
    "outline":           g("outline"),
    "outlineVariant":    g("outline_variant"),
    "error":             g("error"),
}
with open(dst, "w") as f:
    json.dump(out, f, indent=2)
PY
fi

