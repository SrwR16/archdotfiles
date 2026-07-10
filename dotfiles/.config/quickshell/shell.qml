//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QPA_PLATFORMTHEME=

import Quickshell
import Quickshell.Io
import "WelcomeApp"
import "PowerApp"
import "SidebarApp"
import "CalendarApp"
import "WallpaperApp"
import "StatusbarApp"
import "CustomTheme"
import "SettingsApp"
import "Overview/services/"
import "Overview/common/"
import "Overview/modules/overview/"

ShellRoot {
    // Test IPC tools: qs ipc show

    IpcHandler {
        target: "theme-manager"
        function reload(): void {
            Theme.reloadTheme()
        }
    }

    WelcomeWindow {}
    PowerWindow {}
    SidebarWindow {}
    CalendarWindow {}
    WallpaperWindow {}
    StatusbarWindow {}
    SettingsWindow {}
    Overview {}
}
