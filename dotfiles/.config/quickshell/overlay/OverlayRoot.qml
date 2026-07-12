import "../overlay"
import "../services"
import "../theme"
import "../widgets"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: overlayRoot

    property bool anyActive: island.anyOverlayActive || island.showControlCenter || island.showAppLauncher || island.showPowerSection
    property int islandHeight: island.height
    property alias island: island

    ActivityManager {
        id: activityManager
    }

    StatusService {
        id: statusSvc
    }

    NotificationService {
        id: notifService

        onNotificationReceived: function(data, notification) {
            activityManager.push("notification", data, activityManager.priorityPassive, 3500);
        }
    }

    Connections {
        function onActivityDismissed(activity) {
            if (activity.type === "notification" && activity.data)
                notifService.dismissBanner(activity.data);

        }

        target: activityManager
    }

    AppLauncherService {
        id: appLauncherSvc
    }

    ModeService {
        id: modeSvc
    }

    PrivacyService {
        id: privacySvc
    }

    VpnService {
        id: vpnSvc
    }

    HardwareMonitor {
        id: hwMonitor
    }

    // Transparent background interceptor for closing menus when clicking outside
    MouseArea {
        anchors.fill: parent
        enabled: overlayRoot.anyActive
        onClicked: {
            island.showPowerSection = false;
            activityManager.dismissByType("power");
            activityManager.dismissByType("battery");
            activityManager.dismissByType("notification");
            island.showControlCenter = false;
            island.showPomodoro = false;
            island.showSys = false;
            island.showTray = false;
            island.showVpn = false;
            island.isPinned = false;
            island.showProductivity = false;
            island.showAppLauncher = false;
        }

        Rectangle {
            anchors.fill: parent
            color: "#01000000"
            visible: parent.enabled
        }

    }

    DynamicIsland {
        id: island

        z: 10
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 10
        activityManager: activityManager
        notifService: notifService
        statusSvc: statusSvc
        modeSvc: modeSvc
        privacySvc: privacySvc
        vpnSvc: vpnSvc
        hwMonitor: hwMonitor

        // When the Control Center or App Launcher is open we need the layer-shell
        // window to grab keyboard focus so its TextInput fields work.
        Binding {
            target: mainWindow
            property: "keyboardNeeded"
            value: island.showControlCenter || island.showAppLauncher
        }

    }

    // Embed Search (formerly AppLauncher) directly in the same scene graph
    Item {
        z: 20
        width: 480
        height: 240
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 10
        visible: island.showAppLauncher
        opacity: island.showAppLauncher ? 1 : 0

        Search {
            id: searchOverlay

            anchors.fill: parent
            radius: 28
            appService: appLauncherSvc
            onCloseRequested: island.showAppLauncher = false
            onHoveredChanged: island.appLauncherHovered = hovered
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.durXS
            }

        }

    }

    Process {
        id: ipcChecker

        running: true
        command: ["stdbuf", "-oL", "sh", "-c", "while true; do " + "  out=''; " + "  IPC_DIR=\"${XDG_RUNTIME_DIR:-/tmp/runtime-$USER}\"; " + "  test -f \"$IPC_DIR/qs-power-menu\" && rm \"$IPC_DIR/qs-power-menu\" && out=\"${out}p\"; " + "  test -f \"$IPC_DIR/qs-app-launcher\" && rm \"$IPC_DIR/qs-app-launcher\" && out=\"${out}a\"; " + "  test -f \"$IPC_DIR/qs-mode-cycle\" && rm \"$IPC_DIR/qs-mode-cycle\" && out=\"${out}m\"; " + "  test -f \"$IPC_DIR/qs-toggle-cc\" && rm \"$IPC_DIR/qs-toggle-cc\" && out=\"${out}c\"; " + "  test -f \"$IPC_DIR/qs-productivity\" && rm \"$IPC_DIR/qs-productivity\" && out=\"${out}d\"; " + "  test -f \"$IPC_DIR/qs-pomodoro\" && rm \"$IPC_DIR/qs-pomodoro\" && out=\"${out}f\"; " + "  test -f \"$IPC_DIR/qs-sys\" && rm \"$IPC_DIR/qs-sys\" && out=\"${out}s\"; " + "  test -f \"$IPC_DIR/qs-tray\" && rm \"$IPC_DIR/qs-tray\" && out=\"${out}t\"; " + "  if [ -n \"$out\" ]; then echo \"$out\"; fi; " + "  inotifywait -qq -t 2 -e create,modify \"$IPC_DIR\" 2>/dev/null || sleep 0.2; " + "done"]

        stdout: SplitParser {
            onRead: (data) => {
                var flags = data.trim();
                if (flags.indexOf("p") >= 0 && !island.showAppLauncher)
                    island.showPowerSection = !island.showPowerSection;

                if (flags.indexOf("a") >= 0 && !island.showPowerSection && !activityManager.activeActivity)
                    island.showAppLauncher = true;

                if (flags.indexOf("m") >= 0) {
                    modeSvc.cycleMode();
                    island.showModeIndicator();
                }
                if (flags.indexOf("c") >= 0)
                    island.showControlCenter = !island.showControlCenter;

                if (flags.indexOf("d") >= 0)
                    island.showProductivity = !island.showProductivity;

                if (flags.indexOf("f") >= 0)
                    island.showPomodoro = !island.showPomodoro;

                if (flags.indexOf("s") >= 0)
                    island.showSys = !island.showSys;

                if (flags.indexOf("t") >= 0)
                    island.showTray = !island.showTray;

            }
        }

    }

}
