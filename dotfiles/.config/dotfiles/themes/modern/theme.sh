#!/usr/bin/env bash
# Dotfiles Theme Modern

# Set launcher
echo 'rofi' > $HOME/.config/dotfiles/settings/launcher

# Set Window Border
echo -e 'local name = "border-2.lua"\nload_variant(name,"windows")' > $HOME/.config/hypr/conf/window.lua

# Set rofi
echo '* { border-width: 2px; }' > $HOME/.config/dotfiles/settings/rofi-border.rasi

echo ":: Theme set to Modern"