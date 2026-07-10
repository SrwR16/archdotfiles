# Quickshell Config — Shell QML desktop widgets

## Entrypoint

`shell.qml` — loaded by `quickshell`. Top-level `ShellRoot` with a `PanelWindow` (clock bar) and `ControlCenter` (overlay panel).

## Architecture

| Directory | Purpose |
|---|---|
| `overlay/` | OverlayRoot, DynamicIsland clock bar, ControlCenter, Search, Notifications |
| `widgets/` | Reusable QML components: calendar, media, system usage, power panel, etc. |
| `services/` | QML service singletons: media, notifications, VPN, hardware, wallpaper, etc. |
| `theme/` | Theme.qml, Fonts.qml, matugen-driven `colors.json` |
| `scripts/` | Shell helper scripts: askpass, wallpaper.sh, nightlight |
| `Overview/` | Standalone workspace overview module |
| `screenshots/` | Shell screenshots |

## Services (singletons loaded in `shell.qml`)

All live in `services/` and are instantiated as QML singletons on ShellRoot:

| Service | File | Purpose |
|---|---|---|
| MediaService | `MediaService.qml` | MPRIS player tracking, cover art, playback control |
| NotificationService | `NotificationService.qml` | mako-compatible notification history + state |
| StatusService | `StatusService.qml` | Hardware status aggregator (brightness, volume, mic, etc.) |
| SystemUsageService | `SystemUsageService.qml` | CPU, RAM, disk usage polling |
| WallpaperService | `WallpaperService.qml` | Wallpaper filesystem watcher + swanky logo painter |
| ModeService | `ModeService.qml` | Power/profile mode toggling |
| PrivacyService | `PrivacyService.qml` | Webcam/mic/screen-share privacy indicators |
| ActivityManager | `ActivityManager.qml` | User activity tracking (idle timer, presence) |
| AppLauncherService | `AppLauncherService.qml` | Desktop file search for rofi launcher |
| HardwareMonitor | `HardwareMonitor.qml` | Thermal/fan monitoring |
| VpnService | `VpnService.qml` | WireGuard VPN connection monitor |
| PomodoroService | `PomodoroService.qml` | Pomodoro timer state |
| AskpassService | `AskpassService.qml` | Graphical SSH/GPG askpass dialogs |

## Config tips

- **Colors**: edit `theme/colors.json` or regenerate with `matugen image <wallpaper>` → `theme/colors.scss`
- **Fonts**: edit `theme/Fonts.qml` (family, size, weight)
- **Shell visibility**: `DynamicIsland.qml` is the always-visible top bar; the rest lives in `ControlCenter.qml`
- **Keybinds** are in Hyprland config (`dotfiles/.config/hypr/conf/keybindings/default.lua`), not in QML
