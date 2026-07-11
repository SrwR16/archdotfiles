#!/usr/bin/env bash

# Non-interactive mode: pass -y/--yes to auto-confirm every prompt (used when
# install.sh drives this during post-install). Still requires sudo for the
# system-level config writes.
AUTO=""
case "$1" in
    -y|--yes) AUTO=1 ;;
esac

# Installs/configures SDDM with the sddm-astronaut-theme and wires it to
# auto-sync the desktop wallpaper + matugen colors. Resolves the old
# conflicting Current= themes (dotfiles / matugen-minimal / where_is_my_sddm_theme)
# by writing ONE authoritative /etc/sddm.conf.d/theme.conf.

# --- 1. PRE-FLIGHT CHECKS ---
if ! command -v gum &> /dev/null; then
    echo "Error: 'gum' is not installed. Please install gum first."
    exit 1
fi

DISTRO="Arch Linux"
CHECK_PKG_CMD="pacman -Qi sddm-astronaut-theme"

# aur helper (paru/yay) is required for the AUR package sddm-astronaut-theme
if command -v paru &> /dev/null; then AUR_HELPER="paru"
elif command -v yay &> /dev/null; then AUR_HELPER="yay"
else AUR_HELPER=""; fi

INSTALL_CMD_OFFICIAL="sudo pacman -S --needed --noconfirm sddm qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg"
INSTALL_CMD_AUR="sudo ${AUR_HELPER} -S --needed --noconfirm sddm-astronaut-theme"

primarycolor=$(cat ~/.config/dotfiles/colors/primary 2>/dev/null)
onsurfacecolor=$(cat ~/.config/dotfiles/colors/onsurface 2>/dev/null)
onprimarycolor=$(cat ~/.config/dotfiles/colors/onprimary 2>/dev/null)

THEME_DIR="/usr/share/sddm/themes/sddm-astronaut-theme"
ASTRONAUT_CONF="$THEME_DIR/Themes/astronaut.conf"
GENERATED_CONF="$HOME/.cache/dotfiles/hyprland-dotfiles/sddm-astronaut.conf"
SDDM_CONF_D="/etc/sddm.conf.d"

check_sddm_installed() { $CHECK_PKG_CMD &> /dev/null; }
check_sddm_active()    { systemctl is-active --quiet display-manager; }

disable_other_dms() {
    for dm in gdm lightdm lxdm xdm mdm slim wdm; do
        if systemctl is-enabled --quiet "$dm" 2>/dev/null; then
            echo ":: Disabling conflicting DM: $dm..." && sudo systemctl disable "$dm"
        fi
    done
}

install_sddm() {
    sudo -v || exit 1
    echo ":: Installing SDDM + qt deps on $DISTRO..." && bash -c "$INSTALL_CMD_OFFICIAL"
    if [ -n "$AUR_HELPER" ]; then
        echo ":: Installing sddm-astronaut-theme (AUR) via $AUR_HELPER..." && bash -c "$INSTALL_CMD_AUR"
    else
        echo "ERROR: no AUR helper (paru/yay) found. Install 'sddm-astronaut-theme' manually, then re-run."
        exit 1
    fi
}

activate_sddm() {
    sudo -v || exit 1
    disable_other_dms
    echo ":: Enabling SDDM Service..." && if sudo systemctl enable sddm; then
        echo ":: SDDM Service Enabled. Reboot to apply changes."
    else
        echo "ERROR: Failed to enable SDDM systemd service."
        exit 1
    fi
}

# Write ONE authoritative SDDM config and remove every conflicting Current= file.
write_sddm_config() {
    echo ":: Writing single SDDM config (theme=astronaut) and removing conflicts..."
    sudo mkdir -p "$SDDM_CONF_D"
    for f in "$SDDM_CONF_D"/*.conf; do
        [ -e "$f" ] || continue
        if sudo grep -qE '^[[:space:]]*Current[[:space:]]*=' "$f"; then
            echo "   removing conflicting: $f"
            sudo rm -f "$f"
        fi
    done
    # A stray top-level /etc/sddm.conf would override .conf.d — drop it.
    if [ -f /etc/sddm.conf ]; then
        sudo cp -f /etc/sddm.conf /etc/sddm.conf.bak
        sudo rm -f /etc/sddm.conf
    fi
    sudo tee "$SDDM_CONF_D/theme.conf" > /dev/null <<EOF
[Theme]
Current=sddm-astronaut-theme

[General]
DisplayServer=wayland
InputMethod=qtvirtualkeyboard
GreeterEnvironment=QT_WAYLAND_DISABLE_WINDOWDECORATION=1
EOF
}

# Symlink the matugen-generated config into the theme so SDDM picks up live colors.
link_astronaut_config() {
    echo ":: Linking matugen-generated astronaut config into the theme..."
    sudo mkdir -p "$THEME_DIR/Themes"
    sudo ln -sf "$GENERATED_CONF" "$ASTRONAUT_CONF"
    # Seed the generated file from the package default so the symlink is never broken.
    mkdir -p "$(dirname "$GENERATED_CONF")"
    [ -f "$GENERATED_CONF" ] || cp "$THEME_DIR/Themes/astronaut.conf" "$GENERATED_CONF" 2>/dev/null || true
}

# --- 4. MAIN LOGIC ---
if [ -z "$AUTO" ]; then clear; figlet -f smslant "Dotfiles SDDM"; fi

if ! check_sddm_installed; then
    echo ":: Status: SDDM/astronaut not installed."
    if [ -n "$AUTO" ] || gum confirm --selected.background=$primarycolor --selected.foreground=$onprimarycolor --prompt.foreground=$onsurfacecolor "Install SDDM + sddm-astronaut-theme?"; then
        install_sddm
        if check_sddm_installed; then
            write_sddm_config
            link_astronaut_config
            if [ -n "$AUTO" ] || gum confirm --selected.background=$primarycolor --selected.foreground=$onprimarycolor --prompt.foreground=$onsurfacecolor "Activate SDDM now?"; then
                activate_sddm
            fi
        else
            echo "ERROR: Installation failed."
            exit 1
        fi
    else
        echo ":: Installation cancelled."
        exit 0
    fi
elif ! check_sddm_active; then
    echo ":: SDDM is installed but NOT active."
    write_sddm_config
    link_astronaut_config
    if [ -n "$AUTO" ] || gum confirm --selected.background=$primarycolor --selected.foreground=$onprimarycolor --prompt.foreground=$onsurfacecolor "Activate SDDM now?"; then
        activate_sddm
    fi
else
    echo ":: SDDM is installed and active."
    if [ -n "$AUTO" ]; then
        ACTION="Re-apply astronaut config"
    else
        ACTION=$(gum choose --selected.background=$primarycolor --selected.foreground=$onprimarycolor "Re-apply astronaut config" "Deactivate SDDM" "Exit")
    fi
    case $ACTION in
        "Re-apply astronaut config")
            write_sddm_config
            link_astronaut_config
            echo ":: Re-applied. Reboot to see changes." ;;
        "Deactivate SDDM")
            if [ -n "$AUTO" ] || gum confirm --selected.background=$primarycolor --selected.foreground=$onprimarycolor --prompt.foreground=$onsurfacecolor "Are you sure you want to deactivate SDDM?"; then
                sudo systemctl disable sddm
                echo ":: SDDM deactivated."
            fi ;;
        "Exit")
            echo "Exiting."; exit 0 ;;
    esac
fi

echo
if [ -z "$AUTO" ]; then echo ":: Done! Press [ENTER] to close."; read; fi
