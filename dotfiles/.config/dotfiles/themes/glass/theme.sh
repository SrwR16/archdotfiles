#!/usr/bin/env bash
# Dotfiles Theme Glass

# Set nwg-dock-hyprland
echo "glass" > $HOME/.config/dotfiles/settings/dock-theme
$HOME/.config/nwg-dock-hyprland/launch.sh &

# Set swaync
echo '@import "themes/glass/style.css";' > $HOME/.config/swaync/style.css
swaync-client -rs

# Set launcher
echo 'rofi' > $HOME/.config/dotfiles/settings/launcher

# Set walker theme
echo 'glass' > $HOME/.config/dotfiles/settings/walker-theme

# Set Window Border
echo -e 'local name = "default.lua"\nload_variant(name,"windows")' > $HOME/.config/hypr/conf/window.lua

# Set rofi
echo '* { border-width: 1px; }' > $HOME/.config/dotfiles/settings/rofi-border.rasi

echo ":: Theme set to Glass"