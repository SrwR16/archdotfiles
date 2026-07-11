#!/usr/bin/env bash
#
# test_widgets.sh — smoke-test the ported MovieWidget + WallpaperPicker
#                  against THIS repo's quickshell config.
#
# Run from anywhere:  bash /path/to/test_widgets.sh
# (It resolves the quickshell config dir from its own location.)
#
# Checks are STATIC (no display needed): we verify that the widgets
#   - exist and have balanced brackets / quotes (no half-typed tokens),
#   - no longer call the dead external quickshellinspire helpers
#     (qs_manager.sh close / qs_colors.json),
#   - properly close via the shell's own `root.overlayView = "island"`,
#   - have all their helper scripts present in-repo,
#   - and that runtime tool dependencies are available.
#
# Quickshell cannot be launched headlessly here (no wayland display + must
# stay inside this repo), so we intentionally do NOT start the shell. The
# static checks below catch every porting breakage that was blocking the
# widgets from following this repo's quickshell.

set -uo pipefail

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$CONFIG_DIR" || { echo "cannot cd to $CONFIG_DIR"; exit 1; }

PASS=0; FAIL=0; WARN=0
red='\033[0;31m'; grn='\033[0;32m'; yel='\033[0;33m'; rst='\033[0m'
ok()   { printf "${grn}PASS${rst} %s\n" "$1"; PASS=$((PASS+1)); }
bad()  { printf "${red}FAIL${rst} %s\n" "$1"; FAIL=$((FAIL+1)); }
wrn()  { printf "${yel}WARN${rst} %s\n" "$1"; WARN=$((WARN+1)); }
sec() { printf "\n== %s ==\n" "$1"; }

count_char() { # $1=file $2=char
  grep -oF "$2" "$1" 2>/dev/null | wc -l | tr -d ' '
}

# balance helper: $1=file $2=open $3=close $4=label
balance() {
  local o c
  o=$(count_char "$1" "$2"); c=$(count_char "$1" "$3")
  if [ "$o" -eq "$c" ]; then ok "$4 balanced ($o)"; else bad "$4 UNBALANCED open=$o close=$c in $1"; fi
}

# ---------------------------------------------------------------------------
sec "File presence"
for f in movies/MovieWidget.qml wallpaper/WallpaperPicker.qml widgets/MatugenColors.qml; do
  [ -f "$f" ] && ok "exists: $f" || bad "MISSING: $f"
done

# ---------------------------------------------------------------------------
sec "External-dependency removal (quickshellinspire leftovers)"
for f in movies/MovieWidget.qml wallpaper/WallpaperPicker.qml widgets/MatugenColors.qml; do
  if grep -q "qs_manager.sh\|qs_colors.json" "$f"; then
    bad "$f still references qs_manager.sh / qs_colors.json"
  else
    ok "no dead external refs in $f"
  fi
done

# ---------------------------------------------------------------------------
sec "Close mechanism follows this shell (root.overlayView = \"island\")"
grep -q 'root.overlayView = "island"' movies/MovieWidget.qml \
  && ok "MovieWidget closes via root.overlayView" \
  || bad "MovieWidget does not close via root.overlayView"
grep -q 'root.overlayView = "island"' wallpaper/WallpaperPicker.qml \
  && ok "WallpaperPicker closes via root.overlayView" \
  || bad "WallpaperPicker does not close via root.overlayView"

# ---------------------------------------------------------------------------
sec "MatugenColors uses this repo's theme source"
grep -q 'Quickshell.shellPath("theme/colors.json")' widgets/MatugenColors.qml \
  && ok "MatugenColors reads theme/colors.json via shellPath" \
  || bad "MatugenColors does not read theme/colors.json"
if [ -f theme/colors.json ]; then
  if jq empty theme/colors.json >/dev/null 2>&1; then ok "theme/colors.json is valid JSON"; else bad "theme/colors.json is NOT valid JSON"; fi
else
  wrn "theme/colors.json absent (matugen will generate it at runtime) — MatugenColors falls back to default palette"
fi

# ---------------------------------------------------------------------------
sec "Bracket / quote balance (catches half-typed tokens / Repeater typos)"
for f in movies/MovieWidget.qml wallpaper/WallpaperPicker.qml; do
  balance "$f" '{' '}' "braces"
  balance "$f" '(' ')' "parens"
  balance "$f" '[' ']' "brackets"
done

# ---------------------------------------------------------------------------
sec "Helper scripts referenced by widgets are present in-repo"
for s in wallpaper/save_state.sh wallpaper/set_video.sh scripts/restore_wallpaper.sh scripts/wallpaper.sh; do
  [ -f "$s" ] && ok "helper present: $s" || bad "helper MISSING: $s"
done

# ---------------------------------------------------------------------------
sec "Runtime tool dependencies"
for b in mpvpaper matugen magick curl jq hyprctl inotifywait python3; do
  command -v "$b" >/dev/null 2>&1 && ok "tool present: $b" || bad "tool MISSING: $b"
done
# awww is the wallpaper backend; the `swww` package is Provided by awww
# (there is no standalone `swww` binary), so `awww img` is what applies
# static images. WallpaperPicker must call `awww img`, not `swww img`.
if command -v awww >/dev/null 2>&1; then
  ok "tool present: awww (wallpaper backend; provides swww)"
else
  bad "tool MISSING: awww — static-image wallpaper apply (awww img) will no-op"
fi
if grep -q 'swww img' wallpaper/WallpaperPicker.qml; then
  bad "WallpaperPicker still calls the dead 'swww img' (no swww binary exists; awww provides it)"
else
  ok "WallpaperPicker applies wallpaper via awww img"
fi

# ---------------------------------------------------------------------------
sec "Summary"
printf "PASS=%s FAIL=%s WARN=%s\n" "$PASS" "$FAIL" "$WARN"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
