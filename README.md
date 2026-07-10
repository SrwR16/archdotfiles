<div align="center">

# 🌆 Sarwar's ArchDotfiles

### A lean, self-contained Hyprland desktop for Arch Linux

*Adaptive Material-You theming · Quickshell-only bar · one local `install.sh`*

<p>
  <img alt="Arch Linux"   src="https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white">
  <img alt="Hyprland"     src="https://img.shields.io/badge/Hyprland-00AAAE?style=for-the-badge&logo=wayland&logoColor=white">
  <img alt="Quickshell"   src="https://img.shields.io/badge/Quickshell-41CD52?style=for-the-badge&logo=qt&logoColor=white">
  <img alt="Shell"        src="https://img.shields.io/badge/Zsh-F15A24?style=for-the-badge&logo=gnubash&logoColor=white">
  <img alt="License"      src="https://img.shields.io/badge/License-GPL_3.0-blue?style=for-the-badge">
</p>

</div>

---

## ✨ Overview

**Sarwar's ArchDotfiles** is a personal, opinionated configuration of the
[Hyprland](https://hyprland.org/) tiling compositor. It began as a fork of the
excellent **ML4W** dotfiles and was then reshaped into a lightweight, fully
local setup:

- 🪶 **Dynamic Island bar** — a compact, animated top panel that expands on demand with media controls, system status, and notifications.
- 📦 **Fully self-contained** — everything installs from one `install.sh`; no
  external dotfiles installer, no remote repos pulled at install time.
- 🎨 **Material-You theming** — colors adapt to your wallpaper across every
  component via [matugen](https://github.com/InioX/matugen).
- 🔗 **Safe, idempotent deploy** — your customized settings are preserved and
  existing files are backed up before anything is linked.

---

## 📸 Screenshots

<div align="center">

<img width="800" alt="Desktop preview" src="dotfiles/.config/quickshell/screenshots/2026-07-01-175541_hyprshot.png" />

</div>

---

## 🚀 Installation

> [!WARNING]
> Intended for a fresh-ish Arch (or Arch-based) system running Hyprland.
> The installer backs up any files it replaces to
> `~/.mydotfiles/backups/<timestamp>/`, but review before running on a
> heavily customized setup.

```sh
git clone https://github.com/SrwR16/archdotfiles.git
cd archdotfiles

# Preview exactly what would happen — changes nothing:
./install.sh --dry-run

# Install / update:
./install.sh
```

Then log out and back in (or run `hyprctl reload`).

**What the installer does**

| Step | Action |
|------|--------|
| 1 | Installs base tools (`git jq rsync gum`) |
| 2 | Sets up an AUR helper and installs all packages |
| 3 | Deploys dotfiles to `~/.mydotfiles/` and symlinks them into `~` |
| 4 | Builds the bundled apps locally and applies cursors/fonts/icons |



---

## 🧩 What makes this fork different

- **Dynamic Island bar** — compact top panel with media controls, system status, notifications, and control center overlay.
- **Quickshell-based** — all shell widgets are QML, no Waybar.
- **Vendored apps** — nvim config and SDDM theme live under [`apps/`](apps/) and build locally.
- **Zero install-time network dependency** on any dotfiles/settings upstream.

---

## 📁 Repository layout

```
archdotfiles/
├── install.sh              # local, self-contained installer (stable)
├── dotfiles-stable.dotinst # profile manifest (id, restore list)
├── dotfiles/               # the actual config, symlinked into ~
│   └── .config/
│       ├── hypr/           # Hyprland config
│       ├── quickshell/     # the shell / bar / widgets
│       └── dotfiles/       # scripts, settings, assets
├── apps/                   # vendored, locally-built apps
└── setup/                  # packages, preflight/post, fonts, cursors, icons
```

---

## 🙏 Credits & Thanks

This configuration stands on the shoulders of **[ML4W](https://github.com/mylinuxforwork)**
by **Stephan Raabe** — the original ML4W Hyprland dotfiles are the base of my
Linux customization, and this fork would not exist without that work. Huge
thanks for building and openly sharing such a polished desktop. 💙

Also inspired by the wider Hyprland ricing community:

- [JaKooLit/Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots)
- [prasanthrangan/hyprdots](https://github.com/prasanthrangan/hyprdots)
- [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)
- [Shanu-Kumawat/quickshell-overview](https://github.com/Shanu-Kumawat/quickshell-overview)

---

## 📄 License

Released under the **GPL-3.0** license. See [LICENSE](LICENSE).

<div align="center">
<sub>Built on Arch, tiled with Hyprland. ⌘</sub>
</div>
