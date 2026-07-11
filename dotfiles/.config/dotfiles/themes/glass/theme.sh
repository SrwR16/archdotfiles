#!/usr/bin/env bash
# Dotfiles Theme Glass

# Set launcher
echo 'rofi' > $HOME/.config/dotfiles/settings/launcher

# Set Window Border
echo -e 'local name = "default.lua"\nload_variant(name,"windows")' > $HOME/.config/hypr/conf/window.lua

# Set rofi
echo '* { border-width: 1px; }' > $HOME/.config/dotfiles/settings/rofi-border.rasi

echo ":: Theme set to Glass"