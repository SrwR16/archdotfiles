#!/usr/bin/env bash

# Non-interactive mode: pass -y/--yes to auto-confirm every prompt (used when
# install.sh drives this during post-install). Still requires sudo for the
# system-level config writes.
AUTO=""
case "$1" in
    -y|--yes) AUTO=1 ;;
esac

# Installs/configures SDDM with the where-is-my-sddm-theme-git and wires it to
# auto-sync the desktop wallpaper + matugen colors. Resolves the old
# conflicting Current= themes (dotfiles / matugen-minimal / where_is_my_sddm_theme)
# by writing ONE authoritative /etc/sddm.conf.d/theme.conf.

# --- 1. PRE-FLIGHT CHECKS ---
if ! command -v gum &> /dev/null; then
    echo "Error: 'gum' is not installed. Please install gum first."
    exit 1
fi

DISTRO="Arch Linux"
CHECK_PKG_CMD="pacman -Qi where-is-my-sddm-theme-git"

# aur helper (paru/yay) is required for the AUR package where-is-my-sddm-theme-git
if command -v paru &> /dev/null; then AUR_HELPER="paru"
elif command -v yay &> /dev/null; then AUR_HELPER="yay"
else AUR_HELPER=""; fi

INSTALL_CMD_OFFICIAL="sudo pacman -S --needed --noconfirm sddm qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg"
INSTALL_CMD_AUR="sudo ${AUR_HELPER} -S --needed --noconfirm where-is-my-sddm-theme-git"

primarycolor=$(cat ~/.config/dotfiles/colors/primary 2>/dev/null)
onsurfacecolor=$(cat ~/.config/dotfiles/colors/onsurface 2>/dev/null)
onprimarycolor=$(cat ~/.config/dotfiles/colors/onprimary 2>/dev/null)

THEME_DIR="/usr/share/sddm/themes/where_is_my_sddm_theme"
# World-readable, user-owned dir so the 'sddm' greeter can read the config
# and background (it cannot traverse ~/.cache). Fixes the blank white screen.
SDDM_DOTFILES_DIR="/var/lib/sddm/dotfiles"
GENERATED_CONF="$SDDM_DOTFILES_DIR/theme.conf"
SDDM_CONF_D="/etc/sddm.conf.d"

# Run a command as root WITHOUT an interactive terminal:
#   * prefer pkexec  — graphical polkit prompt, works in a Wayland/X11 session
#     with no tty (so this script succeeds when driven by the non-interactive
#     dotfiles installer / post-arch.sh).
#   * fall back to sudo — needs a tty + password.
rootdo() {
    if command -v pkexec >/dev/null 2>&1 && { [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; }; then
        pkexec "$@" 2>/dev/null && return 0
    fi
    sudo "$@"
}

check_sddm_installed() { $CHECK_PKG_CMD &> /dev/null; }
check_sddm_active()    { systemctl is-active --quiet display-manager; }

disable_other_dms() {
    for dm in gdm lightdm lxdm xdm mdm slim wdm; do
        if systemctl is-enabled --quiet "$dm" 2>/dev/null; then
            echo ":: Disabling conflicting DM: $dm..." && rootdo systemctl disable "$dm"
        fi
    done
}

install_sddm() {
    sudo -v || exit 1
    echo ":: Installing SDDM + qt deps on $DISTRO..." && bash -c "$INSTALL_CMD_OFFICIAL"
    if [ -n "$AUR_HELPER" ]; then
        echo ":: Installing where-is-my-sddm-theme-git (AUR) via $AUR_HELPER..." && bash -c "$INSTALL_CMD_AUR"
    else
        echo "ERROR: no AUR helper (paru/yay) found. Install 'where-is-my-sddm-theme-git' manually, then re-run."
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
    echo ":: Writing single SDDM config (theme=where_is_my_sddm_theme) and removing conflicts..."
    rootdo mkdir -p "$SDDM_CONF_D"
    for f in "$SDDM_CONF_D"/*.conf; do
        [ -e "$f" ] || continue
        if rootdo grep -qE '^[[:space:]]*Current[[:space:]]*=' "$f"; then
            echo "   removing conflicting: $f"
            rootdo rm -f "$f"
        fi
    done
    # A stray top-level /etc/sddm.conf would override .conf.d — drop it.
    if [ -f /etc/sddm.conf ]; then
        rootdo cp -f /etc/sddm.conf /etc/sddm.conf.bak
        rootdo rm -f /etc/sddm.conf
    fi
    # Write to a temp file, then move into place as root (avoids heredoc-through-pkexec).
    local tmp
    tmp="$(mktemp)"
    cat > "$tmp" <<EOF
[Theme]
Current=where_is_my_sddm_theme

[General]
DisplayServer=wayland
InputMethod=qtvirtualkeyboard
GreeterEnvironment=QT_WAYLAND_DISABLE_WINDOWDECORATION=1
EOF
    rootdo cp -f "$tmp" "$SDDM_CONF_D/theme.conf"
    rm -f "$tmp"
}

# Generate the matugen-driven theme.conf into a world-readable dir and symlink
# the theme to read it, so SDDM shows the live wallpaper + Material You colors.
link_astronaut_config() {
    echo ":: Deploying matugen-driven theme.conf for where_is_my_sddm_theme..."
    # Create a world-readable, user-owned dir for the generated config + background
    # so the 'sddm' greeter (which can't read ~/.cache) can load them.
    rootdo mkdir -p "$SDDM_DOTFILES_DIR"
    rootdo chown "$(id -u):$(id -g)" "$SDDM_DOTFILES_DIR"
    chmod 755 "$SDDM_DOTFILES_DIR"
    # Seed a sane default config if matugen hasn't generated one yet, so the
    # greeter never falls back to a broken/blank screen.
    if [ ! -f "$GENERATED_CONF" ]; then
        cat > "$GENERATED_CONF" <<'CFG'
[General]
passwordCharacter=*
passwordMask=true
passwordInputWidth=0.5
passwordInputBackground=#000000aa
passwordInputRadius=14
passwordInputCursorVisible=true
passwordFontSize=96
passwordCursorColor=#c0c7d5
passwordTextColor=#e5e2e2
showSessionsByDefault=false
sessionsFontSize=24
showUsersByDefault=false
usersFontSize=32
background=/var/lib/sddm/dotfiles/blurred_wallpaper.png
backgroundFill=#131314
backgroundFillMode=aspect
basicTextColor=#e5e2e2
CFG
    fi
    # Seed a background so SDDM is never blank: prefer the live blurred
    # wallpaper, then the bundled default wallpaper (scaled + lightly blurred).
    if [ ! -f "$SDDM_DOTFILES_DIR/blurred_wallpaper.png" ]; then
        if [ -f "$HOME/.cache/dotfiles/hyprland-dotfiles/blurred_wallpaper.png" ]; then
            cp "$HOME/.cache/dotfiles/hyprland-dotfiles/blurred_wallpaper.png" "$SDDM_DOTFILES_DIR/blurred_wallpaper.png" 2>/dev/null || true
        elif [ -f "$HOME/.config/dotfiles/wallpapers/default.jpg" ]; then
            if command -v convert >/dev/null 2>&1; then
                convert "$HOME/.config/dotfiles/wallpapers/default.jpg" -resize 1920x1080^ \
                    -gravity center -extent 1920x1080 -blur 0x18 "$SDDM_DOTFILES_DIR/blurred_wallpaper.png" 2>/dev/null \
                    || cp "$HOME/.config/dotfiles/wallpapers/default.jpg" "$SDDM_DOTFILES_DIR/blurred_wallpaper.png" 2>/dev/null || true
            else
                cp "$HOME/.config/dotfiles/wallpapers/default.jpg" "$SDDM_DOTFILES_DIR/blurred_wallpaper.png" 2>/dev/null || true
            fi
        fi
    fi
    chmod 644 "$GENERATED_CONF" "$SDDM_DOTFILES_DIR/blurred_wallpaper.png" 2>/dev/null || true
    # Point the theme's theme.conf at our generated, world-readable file.
    rootdo ln -sf "$GENERATED_CONF" "$THEME_DIR/theme.conf"
}

# --- 4. MAIN LOGIC ---
if [ -z "$AUTO" ]; then clear; figlet -f smslant "Dotfiles SDDM"; fi

if ! check_sddm_installed; then
    echo ":: Status: SDDM/where_is_my_sddm_theme not installed."
    if [ -n "$AUTO" ] || gum confirm --selected.background=$primarycolor --selected.foreground=$onprimarycolor --prompt.foreground=$onsurfacecolor "Install SDDM + where-is-my-sddm-theme-git?"; then
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
        ACTION="Re-apply SDDM config"
    else
        ACTION=$(gum choose --selected.background=$primarycolor --selected.foreground=$onprimarycolor "Re-apply SDDM config" "Deactivate SDDM" "Exit")
    fi
    case $ACTION in
        "Re-apply SDDM config")
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
