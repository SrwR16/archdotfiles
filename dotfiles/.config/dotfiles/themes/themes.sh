#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
THEME_OPTIONS=$(find "$SCRIPT_DIR" -maxdepth 1 -mindepth 1 -type d | awk -F/ '{ print $NF }')
selected_theme=$(rofi -dmenu -replace -config ~/.config/rofi/config-themes.rasi -i -no-show-icons -l 5 -width 30 <<<"$THEME_OPTIONS")

source "$HOME/.config/dotfiles/themes/$selected_theme/theme.sh"