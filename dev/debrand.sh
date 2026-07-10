#!/usr/bin/env bash
# De-brand the dotfiles: ml4w/ML4W -> dotfiles/Dotfiles, drop ml4w- script
# prefixes, ML4W* QML wrappers -> Shell*, vendored xi-* dirs -> neutral names.
# Deterministic + idempotent-ish. Run once from the repo root.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

FILTER="dev/_debrand_filter.pl"
SCOPE=(dotfiles setup apps README.md hyprland-dotfiles-stable.dotinst)

echo ":: De-brand: transforming file contents..."
# Text files only (skip binaries), tracked + untracked, within scope.
while IFS= read -r -d '' f; do
    if grep -Iq . "$f" 2>/dev/null; then
        perl -i "$FILTER" "$f"
    fi
done < <(find "${SCOPE[@]}" -type f -print0 2>/dev/null)

echo ":: De-brand: renaming files and directories (deepest first)..."
# Depth-first so children are renamed before their parent directories.
find "${SCOPE[@]}" -depth \( -iname '*ml4w*' -o -name 'Ml4w*' -o -name 'xi-*' \) -print0 2>/dev/null \
  | while IFS= read -r -d '' path; do
        dir=$(dirname "$path")
        base=$(basename "$path")
        newbase=$(printf '%s' "$base" | perl "$FILTER")
        if [ "$base" != "$newbase" ]; then
            git mv -k "$path" "$dir/$newbase" 2>/dev/null || mv "$path" "$dir/$newbase"
            echo "   renamed: $path -> $dir/$newbase"
        fi
    done

echo ":: De-brand complete."
