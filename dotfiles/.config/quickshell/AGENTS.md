# Quickshell Config — Shell QML desktop widgets

## Entrypoint

`shell.qml` — loaded by `quickshell`. Top-level `ShellRoot` with a `PanelWindow` (clock bar) and `ControlCenter` (overlay panel).

## Architecture

| Directory | Purpose |
|---|---|
| `core/` | Singleton QML types: `Theme.qml` (colors, radii), `Fonts.qml` (Inter, JetBrainsMono Nerd Font) |
| `Widgets/clock/` | Smart island `ClockWidget.qml` — collapsible bar composing clock, `MediaSection`, `StatusCapsule`, inline cava bars, and power menu (Logout/Sleep/Reboot/Shutdown); uses `MediaService` for playerctl/cava data |
| `Widgets/media/` | `MediaSection.qml` (album art + track info + bars) + `MediaService.qml` (playerctl status/metadata + cava process) |
| `Widgets/status/` | `StatusCapsule.qml` (WiFi + battery% + charging icon; auto-switches to volume/brightness bar with slider on value change, reverts after 3s idle) + `StatusService.qml` (sysfs polls every 5s) |
| `Widgets/cava/` | `CavaVisualizer.qml` (4-bar row component) + `cava.conf` |
| `Widgets/power/` | `PowerMenu.qml` — power menu button grid (Logout/Sleep/Reboot/Shutdown) used by ClockWidget |
| `controlCenter/` | Full-featured `PanelWindow` overlay: Pipewire audio, nmcli WiFi (scan/connect/password/QR), Bluetooth, Night Light (gammastep), sysfs brightness, MPRIS media player, notification server, subpage navigation (main/wifi/bluetooth), password entry dialog |

## Running

```sh
quickshell
```

No build, lint, typecheck, or test commands — pure QML config loaded at runtime.

## External runtime deps

- `playerctl` (media status / metadata via `playerctld`)
- `cava` + `stdbuf` (audio visualizer)
- `iwgetid` (WiFi SSID)
- `nmcli` (WiFi scan/connect/manage — used by ControlCenter)
- `brightnessctl` (backlight control — used by ControlCenter)
- `gammastep` (night light — used by ControlCenter)
- `qrencode` (WiFi QR code — optional, used by ControlCenter)
- Sysfs at `/sys/class/power_supply/BAT*` (battery), `/sys/class/backlight/*` (brightness)

## ControlCenter notes

- Self-contained in `ControlCenter.qml` (~1300 lines). Uses inline QML `component` declarations (`ToggleTile`, `IconSlider`, `PageHeader`) within the same file.
- Subpages via `page` property: `"main"`, `"wifi"`, `"bluetooth"`. Each page is a `ScrollView` inside the panel.
- Pipewire audio uses `Quickshell.Services.Pipewire` (`PwNode`, `PwObjectTracker`).
- WiFi management shells out to `nmcli` via `Process` + `StdioCollector`. Password entry dialog uses `TextField` + `CheckBox` overlay.
- The old stub files (`pages/MainPage.qml`, `services/*.qml`, `components/*.qml`) are unused.

## ControlCenter Bluetooth page

- `btAdapter: Bluetooth.defaultAdapter` — devices in `btAdapter.devices.values`
- `BluetoothDeviceState`: `Disconnected`, `Connected`, `Disconnecting`, `Connecting` (no separate Paired state; use `dev.paired` boolean)
- `btScanning` property syncs with `btAdapter.discovering`; auto-reset via `Connections` on `discoveringChanged`/`enabledChanged`
- Actions: `dev.pair()`, `dev.forget()`, `dev.connect()`, `dev.disconnect()`

## ClockWidget notes

- `ClockWidget.qml` is the "smart island" — it has three layout zones in expanded mode: `MediaSection` (left), clock (center), `StatusCapsule` (right).
- Uses `SystemClock` for minute-precision time.
- Properties `isPlaying`, `barHeights`, `trackTitle`, `trackArtist`, `trackArt` are bound from `MediaService`.
- Animation easings use `Easing.OutQuart` for size transitions.
- Collapsed visualizer is inline (not the `CavaVisualizer` component) — it's the right-aligned bar group that animates width when music plays.
- Power menu overlay: `showPowerMenu` property expands island to 130×480 with Logout/Sleep/Reboot/Shutdown buttons in a row; 10s auto-dismiss with hover pause; triggered by `Alt+Q` via `Shortcut` in shell.qml (`Qt.ApplicationShortcut` context).

## Style notes

- Nerd Font icon glyphs used inline as strings (e.g. `"󰥔"`, `"󰕾"`)
- `pragma Singleton` on shared types in `core/`; referenced as `Theme.xxx` / `Fonts.xxx` elsewhere
- 2-space indentation, no comments
- `shellPath()` references paths relative to config root (e.g. `"widgets/cava/cava.conf"`)
