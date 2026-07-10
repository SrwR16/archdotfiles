#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Local, self-contained installer for these Hyprland dotfiles (STABLE).
#
# Does everything itself — package install, dotfile deployment (symlinks),
# vendored app install — with NO external dotfiles-installer binary and no
# network fetches of any upstream dotfiles/settings repo. OS/AUR packages and
# a few third-party tools (oh-my-posh, cursors, icons) are still fetched.
#
# Safe to re-run: existing files are backed up before linking, and your
# customised settings (the .dotinst "restore" list) are never overwritten.
#
#   ./install.sh            # install / update
#   ./install.sh --dry-run  # show what would happen, change nothing
# -----------------------------------------------------------------------------
set -euo pipefail

# --- Colors / UI ------------------------------------------------------------
BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[ OK ]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[FAIL]${NC} $1" >&2; exit 1; }

# --- Args -------------------------------------------------------------------
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        -n|--dry-run) DRY_RUN=1 ;;
        -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) error "Unknown argument: $arg" ;;
    esac
done
run() { if [ "$DRY_RUN" -eq 1 ]; then echo "   + $*"; else eval "$@"; fi; }

# --- Guards -----------------------------------------------------------------
[ "$(id -u)" -eq 0 ] && error "Do not run this installer as root."
command -v git >/dev/null || error "git is required."

repo_path="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
export repo_path
cd "$repo_path"

DOTINST="$repo_path/dotfiles-stable.dotinst"
[ -f "$DOTINST" ] || error "Missing $DOTINST"

# --- Distro detection -------------------------------------------------------
if command -v pacman >/dev/null; then DISTRO=arch
elif command -v dnf  >/dev/null; then DISTRO=fedora
elif command -v zypper >/dev/null; then DISTRO=opensuse
else error "Unsupported distribution (need pacman, dnf or zypper)."; fi
info "Detected distribution: $DISTRO"
[ "$DRY_RUN" -eq 1 ] && warn "DRY RUN — no changes will be made."

# --- Base tools needed by this script ---------------------------------------
if [ "$DRY_RUN" -eq 0 ]; then
    case "$DISTRO" in
        arch)     sudo pacman -S --needed --noconfirm git jq rsync gum ;;
        fedora)   sudo dnf install -y git jq rsync gum ;;
        opensuse) sudo zypper install -y git jq rsync gum ;;
    esac
fi
command -v jq >/dev/null || error "jq is required."

# --- Read the .dotinst ------------------------------------------------------
DOTFILES_ID=$(jq -r '.id' "$DOTINST")
SUBFOLDER=$(jq -r '.subfolder' "$DOTINST")
mapfile -t RESTORE < <(jq -r '.restore[].source' "$DOTINST")
SRC_DIR="$repo_path/$SUBFOLDER"
DEPLOY_DIR="$HOME/.mydotfiles/$DOTFILES_ID"
BACKUP_DIR="$HOME/.mydotfiles/backups/$(date +%Y%m%d_%H%M%S)"
info "Profile id : $DOTFILES_ID"
info "Deploy dir : $DEPLOY_DIR"
[ -d "$SRC_DIR" ] || error "Source dir not found: $SRC_DIR"

# ===========================================================================
# 1. Preflight (AUR helper on Arch, swww->awww, etc.)
# ===========================================================================
info "Running preflight for $DISTRO..."
if [ "$DRY_RUN" -eq 0 ]; then
    # shellcheck disable=SC1090
    source "$repo_path/setup/preflight-$DISTRO.sh"
fi
# aur_helper is exported by the Arch preflight; default to pacman otherwise.
aur_helper="${aur_helper:-}"

# ===========================================================================
# 2. Packages
# ===========================================================================
pkg_files=("$repo_path/setup/dependencies/packages")
case "$DISTRO" in
    arch)     pkg_files+=("$repo_path/setup/dependencies/packages-arch") ;;
    fedora)   pkg_files+=("$repo_path/setup/dependencies/packages-fedora") ;;
    opensuse) pkg_files+=("$repo_path/setup/dependencies/packages-opensuse") ;;
esac
mapfile -t PKGS < <(grep -vhE '^\s*#|^\s*$' "${pkg_files[@]}" 2>/dev/null | awk '{$1=$1};1' | sort -u)
if [ "$DRY_RUN" -eq 1 ]; then
    info "Installing ${#PKGS[@]} packages..."
    echo "   + install: ${PKGS[*]}"
else
    # On Arch, detect installed packages that conflict with our requested list.
    # Three cases per installed package × requested package pair:
    #   1. Same name              → skip (it IS the requested package)
    #   2. Provides, no conflict  → skip (already satisfied, e.g. rust provides cargo)
    #   3. Provides + conflicts   → conflict (e.g. blueman-git, illogical-impulse-quickshell-git)
    #   4. Conflicts only         → conflict (rare but handled)
    REMOVE_PKGS=()    # installed packages to remove
    SKIP_PKGS=()      # requested packages to skip
    if [ "$DISTRO" = arch ]; then
        mapfile -t installed_pkgs < <(pacman -Qq 2>/dev/null)
        CONFLICT_IPKGS=()   # installed package names
        CONFLICT_RPKGS=()   # requested package each conflicts with
        for ipkg in "${installed_pkgs[@]}"; do
            info="$(pacman -Qi "$ipkg" 2>/dev/null)" || continue
            provides="$(echo "$info" | sed -n 's/^Provides *: //p')"
            conflicts="$(echo "$info" | sed -n 's/^Conflicts With *: //p')"
            for rpkg in "${PKGS[@]}"; do
                [ "$ipkg" = "$rpkg" ] && continue
                _provides_it=false
                _conflicts_it=false
                if [ -n "$provides" ] && [ "$provides" != "None" ]; then
                    echo "$provides" | tr ' ' '\n' | grep -qx "$rpkg" && _provides_it=true
                fi
                if [ -n "$conflicts" ] && [ "$conflicts" != "None" ]; then
                    echo "$conflicts" | tr ' ' '\n' | grep -qx "$rpkg" && _conflicts_it=true
                fi
                if $_provides_it; then
                    if $_conflicts_it; then
                        # Provides AND conflicts → real conflict (needs user decision)
                        CONFLICT_IPKGS+=("$ipkg")
                        CONFLICT_RPKGS+=("$rpkg")
                    else
                        # Provides, no conflict → already satisfied
                        SKIP_PKGS+=("$rpkg")
                    fi
                    break
                fi
                if $_conflicts_it; then
                    # Conflicts without providing → real conflict
                    CONFLICT_IPKGS+=("$ipkg")
                    CONFLICT_RPKGS+=("$rpkg")
                    break
                fi
            done
        done

        if [ ${#CONFLICT_IPKGS[@]} -gt 0 ]; then
            echo ""
            warn "Found ${#CONFLICT_IPKGS[@]} conflicting package(s):"
            echo ""
            # Display unique pairs
            declare -A _shown
            for i in "${!CONFLICT_IPKGS[@]}"; do
                ipkg="${CONFLICT_IPKGS[$i]}"
                if [ -z "${_shown[$ipkg]+x}" ]; then
                    _shown[$ipkg]=1
                    printf "  ${YELLOW}%s${NC}  →  conflicts with  ${YELLOW}%s${NC}\n" \
                        "$ipkg" "${CONFLICT_RPKGS[$i]}"
                fi
            done

            choice=$(gum choose "Remove all conflicting (install stable)" "Choose for each" "Skip all (keep existing)")
            echo ""

            case "$choice" in
                "Remove all"*)
                    REMOVE_PKGS=("${CONFLICT_IPKGS[@]}")
                    ;;
                "Choose for each")
                    declare -A _dealt
                    for i in "${!CONFLICT_IPKGS[@]}"; do
                        ipkg="${CONFLICT_IPKGS[$i]}"
                        [ -n "${_dealt[$ipkg]+x}" ] && continue
                        _dealt[$ipkg]=1
                        rpkg="${CONFLICT_RPKGS[$i]}"
                        if gum confirm "Remove ${ipkg} and install ${rpkg}?"; then
                            REMOVE_PKGS+=("$ipkg")
                        else
                            SKIP_PKGS+=("$rpkg")
                            info "Keeping $ipkg — $rpkg will be skipped"
                        fi
                    done
                    ;;
                "Skip all"*)
                    for rpkg in "${CONFLICT_RPKGS[@]}"; do
                        SKIP_PKGS+=("$rpkg")
                    done
                    mapfile -t SKIP_PKGS < <(printf '%s\n' "${SKIP_PKGS[@]}" | sort -u)
                    info "Keeping existing packages — ${SKIP_PKGS[*]} will be skipped"
                    ;;
            esac

            # Remove chosen conflicting packages
            if [ ${#REMOVE_PKGS[@]} -gt 0 ]; then
                mapfile -t REMOVE_PKGS < <(printf '%s\n' "${REMOVE_PKGS[@]}" | sort -u)

                # Check reverse dependencies before removing
                REVDEPS=()
                for rp in "${REMOVE_PKGS[@]}"; do
                    while IFS= read -r rd; do
                        [ -z "$rd" ] && continue
                        # Is it already in our install list (will be resolved)?
                        in_list=false
                        for pkg in "${PKGS[@]}"; do [ "$rd" = "$pkg" ] && in_list=true && break; done
                        $in_list && continue
                        # Is it in the removal list already?
                        in_remove=false
                        for rm in "${REMOVE_PKGS[@]}"; do [ "$rd" = "$rm" ] && in_remove=true && break; done
                        $in_remove && continue
                        REVDEPS+=("$rd")
                    done < <(pactree -r -u "$rp" 2>/dev/null | tail -n +2)
                done
                if [ ${#REVDEPS[@]} -gt 0 ]; then
                    mapfile -t REVDEPS < <(printf '%s\n' "${REVDEPS[@]}" | sort -u)
                    echo ""
                    warn "Removing ${REMOVE_PKGS[*]} would break dependencies for:"
                    for rd in "${REVDEPS[@]}"; do
                        echo "    $rd"
                    done
                    echo ""
                    if gum confirm "Remove these too?"; then
                        REMOVE_PKGS+=("${REVDEPS[@]}")
                        mapfile -t REMOVE_PKGS < <(printf '%s\n' "${REMOVE_PKGS[@]}" | sort -u)
                    else
                        error "Cannot proceed — ${REMOVE_PKGS[*]} has unresolvable dependencies."
                    fi
                fi

                warn "Removing: ${REMOVE_PKGS[*]}"
                if [ -n "$aur_helper" ]; then
                    "$aur_helper" -Rns --noconfirm "${REMOVE_PKGS[@]}"
                else
                    sudo pacman -Rns --noconfirm "${REMOVE_PKGS[@]}"
                fi
            fi

            # Remove skipped packages from the install list
            if [ ${#SKIP_PKGS[@]} -gt 0 ]; then
                FILTERED_PKGS=()
                for pkg in "${PKGS[@]}"; do
                    skip=0
                    for sp in "${SKIP_PKGS[@]}"; do
                        [ "$pkg" = "$sp" ] && skip=1 && break
                    done
                    [ "$skip" -eq 0 ] && FILTERED_PKGS+=("$pkg")
                done
                PKGS=("${FILTERED_PKGS[@]}")
            fi
        fi
    fi

    info "Installing ${#PKGS[@]} packages..."

    # Show what will be installed vs already up-to-date
    if [ "$DISTRO" = arch ]; then
        mapfile -t _inst < <(pacman -Qq 2>/dev/null)
        _have=0
        for _p in "${PKGS[@]}"; do
            for _i in "${_inst[@]}"; do
                [ "$_p" = "$_i" ] && ((_have++)) && break
            done
        done
        _need=$((${#PKGS[@]} - _have))
        info "  → $_need new, $_have already installed"
    fi

    case "$DISTRO" in
        arch)
            if [ -n "$aur_helper" ]; then
                "$aur_helper" -S --needed --noconfirm "${PKGS[@]}"
            else
                sudo pacman -S --needed --noconfirm "${PKGS[@]}"
            fi ;;
        fedora)   sudo dnf install -y "${PKGS[@]}" ;;
        opensuse) sudo zypper install -y "${PKGS[@]}" ;;
    esac
fi

# Prebuilt fallback binaries (eza, matugen) -> ~/.local/bin (packages win on PATH).
run "mkdir -p \"\$HOME/.local/bin\""
if [ -d "$repo_path/setup/packages" ]; then
    for bin in "$repo_path"/setup/packages/*; do
        [ -f "$bin" ] || continue
        run "install -m 755 \"$bin\" \"\$HOME/.local/bin/$(basename "$bin")\""
    done
fi

# ===========================================================================
# 3. Deploy dotfiles to $DEPLOY_DIR and symlink into $HOME
# ===========================================================================

# --- Backup prompt ----------------------------------------------------------
DO_BACKUP=1
if [ "$DRY_RUN" -eq 0 ] && [ -d "$DEPLOY_DIR" ]; then
    # Count files that would be backed up
    _would_backup=0
    for _p in "$DEPLOY_DIR"/*; do
        _n="$(basename "$_p")"
        [ "$_n" = ".config" ] && continue
        [ -e "$HOME/$_n" ] || [ -L "$HOME/$_n" ] && ((_would_backup++))
    done
    if [ -d "$DEPLOY_DIR/.config" ]; then
        for _p in "$DEPLOY_DIR"/.config/*; do
            _n="$(basename "$_p")"
            [ -e "$HOME/.config/$_n" ] || [ -L "$HOME/.config/$_n" ] && ((_would_backup++))
        done
    fi
    if [ "$_would_backup" -gt 0 ]; then
        echo ""
        info "Found $_would_backup existing file(s) that would be backed up"
        if ! gum confirm "Backup existing dotfiles before deploying?"; then
            DO_BACKUP=0
            warn "Skipping backup — existing files will be overwritten"
        fi
    fi
fi

# --- Delete old backups? ----------------------------------------------------
if [ "$DRY_RUN" -eq 0 ]; then
    mapfile -t _old < <(find "$HOME/.mydotfiles/backups" -maxdepth 1 -type d -name "2*" 2>/dev/null | sort -r | tail -n +2)
    if [ ${#_old[@]} -gt 0 ]; then
        echo ""
        info "Found ${#_old[@]} old backup(s):"
        for _b in "${_old[@]}"; do
            _sz="$(du -sh "$_b" 2>/dev/null | cut -f1)"
            echo "    $(_b##*/)  ($_sz)"
        done
        echo ""
        if gum confirm "Delete old backups to free space?"; then
            for _b in "${_old[@]}"; do
                rm -rf "$_b"
            done
            success "Deleted ${#_old[@]} old backup(s)"
        fi
    fi
fi

# --- Deploy -----------------------------------------------------------------
info "Deploying dotfiles..."
run "mkdir -p \"$DEPLOY_DIR\""

# rsync repo -> deploy dir. --delete removes stale files (e.g. the old waybar
# tree) but the restore[] paths are excluded from BOTH sync and deletion, so
# user-customised settings survive updates.
RSYNC_EXCLUDES=()
for r in "${RESTORE[@]}"; do RSYNC_EXCLUDES+=(--exclude "/$r"); done
RSYNC_FLAGS=(-a --delete "${RSYNC_EXCLUDES[@]}")
[ "$DRY_RUN" -eq 1 ] && RSYNC_FLAGS+=(-n -v)
rsync "${RSYNC_FLAGS[@]}" "$SRC_DIR/" "$DEPLOY_DIR/"

# Seed any restore path that does not exist yet (fresh install defaults).
for r in "${RESTORE[@]}"; do
    if [ ! -e "$DEPLOY_DIR/$r" ] && [ -e "$SRC_DIR/$r" ]; then
        run "mkdir -p \"$(dirname "$DEPLOY_DIR/$r")\""
        run "cp -a \"$SRC_DIR/$r\" \"$DEPLOY_DIR/$r\""
    fi
done

# link_item <target-in-HOME> <source-in-DEPLOY_DIR>
link_item() {
    local link="$1" target="$2"
    if [ -L "$link" ] && [ "$(readlink -f "$link")" = "$(readlink -f "$target")" ]; then
        return 0   # already correct
    fi
    if [ -e "$link" ] || [ -L "$link" ]; then
        if [ "$DO_BACKUP" -eq 1 ]; then
            local rel="${link#"$HOME"/}"
            run "mkdir -p \"$(dirname "$BACKUP_DIR/$rel")\""
            run "mv \"$link\" \"$BACKUP_DIR/$rel\""
            warn "backed up existing $link"
        else
            run "rm -rf \"$link\""
        fi
    fi
    run "mkdir -p \"$(dirname "$link")\""
    run "ln -sfn \"$target\" \"$link\""
}

# Home-level dotfiles (everything directly under dotfiles/ except .config).
shopt -s dotglob nullglob
for path in "$DEPLOY_DIR"/*; do
    name="$(basename "$path")"
    [ "$name" = ".config" ] && continue
    link_item "$HOME/$name" "$path"
done
# Per-child under .config (leaves the rest of ~/.config untouched).
run "mkdir -p \"$HOME/.config\""
for path in "$DEPLOY_DIR"/.config/*; do
    link_item "$HOME/.config/$(basename "$path")" "$path"
done
shopt -u dotglob nullglob

# Mark this profile active (read by dotfiles-id and friends).
run "mkdir -p \"\$HOME/.config/dotfiles-installer\""
if [ "$DRY_RUN" -eq 1 ]; then
    echo "   + write active.json -> {\"active\":\"$DOTFILES_ID\"}"
else
    printf '{"active":"%s"}\n' "$DOTFILES_ID" > "$HOME/.config/dotfiles-installer/active.json"
fi

# ===========================================================================
# 4. Post install (oh-my-posh, vendored apps, cursors, fonts, icons, xdg dirs)
# ===========================================================================
info "Running post-install for $DISTRO..."
if [ "$DRY_RUN" -eq 0 ]; then
    # shellcheck disable=SC1090
    source "$repo_path/setup/post-$DISTRO.sh"
fi

# ===========================================================================
# 5. Migration cleanup
# ===========================================================================
if [ -f "$repo_path/setup/migration.sh" ] && [ "$DRY_RUN" -eq 0 ]; then
    info "Running migration cleanup..."
    bash "$repo_path/setup/migration.sh" || warn "migration.sh reported issues"
fi

success "Installation complete."
info "Log out and back in (or run: hyprctl reload) to apply the changes."
[ "$DRY_RUN" -eq 1 ] && info "This was a dry run — nothing was changed."
