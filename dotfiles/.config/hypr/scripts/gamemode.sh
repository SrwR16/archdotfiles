#!/usr/bin/env bash
#                                      __   
#   ___ ____ ___ _  ___ __ _  ___  ___/ /__ 
#  / _ `/ _ `/  ' \/ -_)  ' \/ _ \/ _  / -_)
#  \_, /\_,_/_/_/_/\__/_/_/_/\___/\_,_/\__/ 
# /___/                                     
# 


dotfiles_cache_folder="$HOME/.cache/dotfiles/hyprland-dotfiles"

# Notifications
source "$HOME/.config/dotfiles/scripts/notification-handler"
APP_NAME="System"
NOTIFICATION_ICON="joystick"

if [ -f $HOME/.config/dotfiles/settings/gamemode-enabled ]; then
  if [ -f $dotfiles_cache_folder/restart-wpauto ]; then
    rm $dotfiles_cache_folder/restart-wpauto
    $HOME/.config/dotfiles/scripts/wallpaper-automation &
  fi
  hyprctl reload
  rm $HOME/.config/dotfiles/settings/gamemode-enabled
  notify_user --a "${APP_NAME}" \
            --i "${NOTIFICATION_ICON}" \
            --s "Gamemode deactivated" \
            --m "Animations and blur are now enabled."
else
  if [ -f $dotfiles_cache_folder/wallpaper-automation ]; then
    touch $dotfiles_cache_folder/restart-wpauto
    $HOME/.config/dotfiles/scripts/wallpaper-automation
  fi
  hyprctl eval "activate_gamemode()"
  touch $HOME/.config/dotfiles/settings/gamemode-enabled
  notify_user --a "${APP_NAME}" \
          --i "${NOTIFICATION_ICON}" \
          --s "Gamemode activated" \
          --m "Animations and blur are now disabled."
fi