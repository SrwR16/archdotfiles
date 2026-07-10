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
# Oh-My-Zsh custom plugins (skip if oh-my-zsh not installed yet)
# --------------------------------------------------------------

if [ -d "$HOME/.oh-my-zsh/custom/plugins" ]; then
    if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
    fi
    if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
    fi
    if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/fast-syntax-highlighting" ]; then
        git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$HOME/.oh-my-zsh/custom/plugins/fast-syntax-highlighting"
    fi
fi

# --------------------------------------------------------------
# Create XDG Directories
# --------------------------------------------------------------

xdg-user-dirs-update

