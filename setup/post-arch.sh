#!/usr/bin/env bash

# --------------------------------------------------------------
# Oh My Posh
# --------------------------------------------------------------
curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin

# --------------------------------------------------------------
# Vendored apps (no network) — stage into the runtime location so
# the on-demand installers (nvim, sddm, hyprland-settings) can use
# the local copies.
# --------------------------------------------------------------

apps_runtime="$HOME/.local/share/dotfiles/apps"
mkdir -p "$apps_runtime"
cp -rf "$repo_path/apps/." "$apps_runtime/"

# --------------------------------------------------------------
# Dotfiles Settings App (built from the vendored source)
# --------------------------------------------------------------

mkdir -p "$HOME/.local/bin"
make -C "$repo_path/apps/dotfiles-settings" install

# --------------------------------------------------------------
# Cursors
# --------------------------------------------------------------

source $repo_path/setup/_cursors.sh

# --------------------------------------------------------------
# Fonts
# --------------------------------------------------------------

source $repo_path/setup/_fonts.sh

# --------------------------------------------------------------
# Icons
# --------------------------------------------------------------

source $repo_path/setup/_icons.sh

# --------------------------------------------------------------
# Create XDG Directories
# --------------------------------------------------------------

xdg-user-dirs-update

