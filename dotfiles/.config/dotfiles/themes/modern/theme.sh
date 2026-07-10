#!/usr/bin/env bash
# Dotfiles Theme Modern

# Set nwg-dock-hyprland
echo "modern" > $HOME/.config/dotfiles/settings/dock-theme
$HOME/.config/nwg-dock-hyprland/launch.sh &

# Set swaync
echo '@import "themes/modern/style.css";' > $HOME/.config/swaync/style.css
swaync-client -rs

# Set launcher
echo 'rofi' > $HOME/.config/dotfiles/settings/launcher

# Set walker theme
echo 'modern' > $HOME/.config/dotfiles/settings/walker-theme

# Set Window Border
echo -e 'local name = "border-2.lua"\nload_variant(name,"windows")' > $HOME/.config/hypr/conf/window.lua

# Set rofi
echo '* { border-width: 2px; }' > $HOME/.config/dotfiles/settings/rofi-border.rasi

echo ":: Theme set to Modern"