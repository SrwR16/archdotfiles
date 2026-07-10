import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts


Rectangle {
  id: clockWidget
  clip: true

  property QtObject privacySvc
  property QtObject vpnSvc
  property QtObject activityManager: null
  property QtObject notifService: null
  property QtObject statusSvc: null

  function exclusiveOpen(menuName) {
    if (menuName !== "cc") showControlCenter = false;
    if (menuName !== "app") showAppLauncher = false;
    if (menuName !== "sys") showSys = false;
    if (menuName !== "tray") showTray = false;
    if (menuName !== "askpass") showAskpass = false;
    if (menuName !== "prod") showProductivity = false;
    if (menuName !== "powerSection") showPowerSection = false;
    if (menuName !== "vpn") showVpn = false;
  }

  property bool showControlCenter: false
  property bool showVpn: false
  onShowVpnChanged: {
    if (showVpn && activityManager) {
      activityManager.dismissAll();
    }
  }
  property bool _prevShowControlCenter: false
  onShowControlCenterChanged: {
    if (showControlCenter) {
      exclusiveOpen("cc");
      if (activityManager) activityManager.dismissAll();
    } else {
      if (_prevShowControlCenter && activityManager) activityManager.resumeAutoDismiss();
      isPinned = false;
    }
    _prevShowControlCenter = showControlCenter;
  }

  property bool isPinned: false
  property bool hasMedia: media.mediaState !== "Idle"
  property bool _powerHovered: false
  property bool isExpanded: mouseArea.containsMouse || statusCapsule.isHovered || (typeof mediaSectionItem !== "undefined" && mediaSectionItem.isHovered) || _powerHovered || (typeof timeMouseArea !== "undefined" && timeMouseArea.containsMouse) || (typeof dateMouseArea !== "undefined" && dateMouseArea.containsMouse) || isPinned || showControlCenter || showProductivity || showPowerSection
  signal toggleControlCenter()

  // --- Morph mode ---
  property string mode: "default"
  property bool _ready: false

  Timer {
    interval: 1000; running: true; repeat: false
    onTriggered: {
      _ready = true;
    }
  }

  // --- Audio ---
  readonly property PwNode audioSink: Pipewire.defaultAudioSink
  readonly property bool audioMuted: !!audioSink?.audio?.muted
  readonly property real volume: Math.min(1, Math.max(0, audioSink?.audio?.volume ?? 0))

  PwObjectTracker {
    objects: clockWidget.audioSink ? [clockWidget.audioSink] : []
  }

  onVolumeChanged: {
    if (_ready && !clockWidget.isExpanded) {
      mode = "volume";
      revertTimer.restart();
    }
  }

  onAudioMutedChanged: {
    if (_ready && !clockWidget.isExpanded) {
      mode = "volume";
      revertTimer.restart();
    }
  }

  function volumeIcon(vol, muted) {
    if (muted || vol <= 0) return "󰝟";
    if (vol < 0.34) return "󰕿";
    if (vol < 0.67) return "󰖀";
    return "󰕾";
  }

  // --- Combined polling: brightness, caps lock, num lock, kbd backlight ---
  property QtObject hwMonitor
  
  property real brightness: hwMonitor ? hwMonitor.brightness : 0
  property bool capsLock: hwMonitor ? hwMonitor.capsLock : false
  property bool numLock: hwMonitor ? hwMonitor.numLock : false
  property real kbdBrightness: hwMonitor ? hwMonitor.kbdBrightness : 0
  property Process brightnessSetProc: Process { command: ["true"]; running: false }

  onKbdBrightnessChanged: {
    if (_ready && !clockWidget.isExpanded) {
      mode = "kbdbacklight";
      revertTimer.restart();
    }
  }

  onBrightnessChanged: {
    if (_ready && !clockWidget.isExpanded) {
      mode = "brightness";
      revertTimer.restart();
    }
  }

  function brightnessIcon(val) {
    if (val < 0.34) return "󰃞";
    if (val < 0.67) return "󰃟";
    return "󰃠";
  }

  onNumLockChanged: {
    if (_ready && !clockWidget.isExpanded) {
      mode = "numlock";
      revertTimer.restart();
    }
  }

  onCapsLockChanged: {
    if (_ready && !clockWidget.isExpanded) {
      mode = "capslock";
      revertTimer.restart();
    }
  }

  property bool showPowerSection: false
  onShowPowerSectionChanged: {
    if (showPowerSection) {
      exclusiveOpen("powerSection");
      if (activityManager) activityManager.dismissAll();
    }
  }

  // --- Mode indicator ---
  property var modeSvc: null
  function showModeIndicator() {
    if (_ready && !isExpanded) {
      mode = "mode";
      revertTimer.restart();
    }
  }

  // --- App launcher state ---
  property bool showAppLauncher: false
  property bool appLauncherHovered: false
  property Timer appLauncherTimer: Timer {
    interval: 15000
    onTriggered: clockWidget.showAppLauncher = false
  }

  // --- Battery Alert (via ActivityManager queue) ---
  property bool showProductivity: false
  onShowProductivityChanged: {
    if (showProductivity && activityManager) {
      activityManager.dismissAll();
    }
  }
  property string productivityPage: "time"

  property bool showBatteryAlert: activityManager && activityManager.activeActivity && activityManager.activeActivity.type === "battery"
  property string batteryAlertMode: showBatteryAlert ? activityManager.activeActivity.data.mode : "charging"
  property bool anyOverlayActive: showBatteryAlert || showPomodoro || showSys || showTray || showPowerSection || showAppLauncher || showAskpass || showProductivity || showVpn || showingNotification

  property string _pendingBatteryMode: ""
  property bool _suppressMorph: false

  function pushBatteryAlert(mode) {
    if (!activityManager || !_ready) return
    if (clockWidget.isExpanded && !clockWidget.showBatteryAlert) {
      clockWidget._pendingBatteryMode = mode
      return
    }
    if (activityManager.activeActivity) {
      clockWidget._pendingBatteryMode = mode
      return
    }
    activityManager.push("battery", { mode: mode }, activityManager.priorityPassive, 2000)
  }

  Connections {
    target: activityManager
    function onActiveActivityChanged() {
      if (!clockWidget.showBatteryAlert && clockWidget._pendingBatteryMode) {
        var m = clockWidget._pendingBatteryMode
        clockWidget._pendingBatteryMode = ""
        clockWidget.pushBatteryAlert(m)
      }
    }
  }

  onIsExpandedChanged: {
    if (clockWidget.isExpanded) {
      collapseDelayTimer.stop()
      clockWidget._suppressMorph = false
      if (clockWidget.showBatteryAlert && activityManager && activityManager.activeActivity && activityManager.activeActivity.type === "battery") {
        clockWidget._pendingBatteryMode = activityManager.activeActivity.data.mode || "charging"
        activityManager.dismissByType("battery")
      }
    } else {
      clockWidget._suppressMorph = true
      if (clockWidget._pendingBatteryMode || (activityManager && activityManager.activeActivity)) {
        collapseDelayTimer.restart()
      } else {
        clockWidget._suppressMorph = false
      }
    }
  }

  Timer {
    id: collapseDelayTimer
    interval: 600
    onTriggered: {
      clockWidget._suppressMorph = false
      if (clockWidget._pendingBatteryMode && !clockWidget.showBatteryAlert) {
        var m = clockWidget._pendingBatteryMode
        clockWidget._pendingBatteryMode = ""
        clockWidget.pushBatteryAlert(m)
      } else {
        clockWidget._pendingBatteryMode = ""
      }
    }
  }

  Connections {
    target: statusSvc
    function onChargingChanged() {
      if (statusSvc) pushBatteryAlert(statusSvc.charging ? "charging" : "unplugged");
    }
    function onBatteryChanged() {
      if (statusSvc && !statusSvc.charging && statusSvc.battery <= 20) pushBatteryAlert("low");
    }
  }

  // --- Pomodoro, System, Tray state ---
  property bool showPomodoro: false
  property bool showSys: false
  property bool showTray: false
  
  onShowPomodoroChanged: {
    if (showPomodoro) {
      exclusiveOpen("pomodoro");
      if (activityManager) activityManager.dismissAll();
    }
  }

  onShowSysChanged: {
    if (showSys) {
      exclusiveOpen("sys");
      if (activityManager) activityManager.dismissAll();
    }
  }

  onShowTrayChanged: {
    if (showTray) {
      exclusiveOpen("tray");
      if (activityManager) activityManager.dismissAll();
    }
  }

  // --- Notification state (via ActivityManager queue) ---
  readonly property bool showingNotification: activityManager && activityManager.activeActivity && activityManager.activeActivity.type === "notification"

  property var _currentNotifData: showingNotification ? activityManager.activeActivity.data : null

  // --- App launcher lifecycle ---
  onShowAppLauncherChanged: {
    if (showAppLauncher) {
      exclusiveOpen("app");
      if (activityManager) activityManager.dismissAll();
      if (appLauncherTimer) appLauncherTimer.restart();
    }
  }

  onAppLauncherHoveredChanged: {
    if (appLauncherHovered && appLauncherTimer.running) {
      appLauncherTimer.stop();
    } else if (!appLauncherHovered && showAppLauncher) {
      appLauncherTimer.restart();
    }
  }

  // --- Notification lifecycle (via ActivityManager) ---
  readonly property bool notifHovered: (mouseArea && mouseArea.containsMouse) || (statusCapsule && statusCapsule.isHovered) || (notifBanner && notifBanner.bannerHovered)

  onNotifHoveredChanged: {
    if (notifHovered && activityManager) {
      activityManager.pauseAutoDismiss();
    } else if (!notifHovered && _ready && activityManager && showingNotification) {
      activityManager.resumeAutoDismiss();
    }
  }

  Timer {
    id: revertTimer
    interval: 2000
    onTriggered: mode = "default"
  }

  // --- Layout ---
  MediaService { id: media }

  // --- Askpass dialog state ---
  property var askpassSvc: null
  property bool showAskpass: askpassSvc && askpassSvc.pendingRequest !== null

  // Size changes are the core of the Dynamic Island morph.
  property string morphState: showProductivity ? "productivity" 
                            : showControlCenter ? "controlCenter" 
                            : showAppLauncher ? "appLauncher" 
                            : showAskpass ? "askpass" 
                            : showVpn ? "vpn" 
                            : showTray ? "tray" 
                            : showSys ? "sys" 
                            : showPowerSection ? "powerSection" 
                            : showPomodoro ? "pomodoro" 
                              : activityManager && activityManager.activeActivity && !clockWidget.isExpanded && !clockWidget._suppressMorph ? _queueState(activityManager.activeActivity.type)
                             : "default"

  function _queueState(type) {
    if (type === "notification") return "notification"
    if (type === "battery") return "batteryAlert"
    return "default"
  }

  state: morphState

  states: [
    State {
      name: "default"
      PropertyChanges { target: clockWidget; height: isExpanded ? 64 : 36; width: isExpanded ? 540 : (mode !== "default") ? indicatorRow.implicitWidth + 32 : collapsedContent.contentWidth + 86; radius: isExpanded ? 22 : 18 }
    },
    State {
      name: "productivity"
      PropertyChanges { target: clockWidget; height: typeof prodLoader !== "undefined" && prodLoader.item ? prodLoader.item.implicitHeight + 70 : 800; width: 540; radius: 28 }
    },
    State {
      name: "controlCenter"
      PropertyChanges { target: clockWidget; height: typeof ccLoader !== "undefined" && ccLoader.item ? ccLoader.item.implicitHeight + 70 : 870; width: 680; radius: 24 }
    },
    State {
      name: "appLauncher"
      PropertyChanges { target: clockWidget; height: 240; width: 480; radius: 28 }
    },
    State {
      name: "askpass"
      PropertyChanges { target: clockWidget; height: 200; width: 480; radius: 28 }
    },
    State {
      name: "vpn"
      PropertyChanges { target: clockWidget; height: 200; width: 480; radius: 28 }
    },
    State {
      name: "notification"
      PropertyChanges { target: clockWidget; height: Math.max(130, notifBanner.bannerHeight); width: 480; radius: 28 }
    },
    State {
      name: "powerSection"
      PropertyChanges { target: clockWidget; height: 160; width: 540; radius: 28 }
    },
    State {
      name: "tray"
      PropertyChanges { target: clockWidget; height: 120; width: 440; radius: 28 }
    },
    State {
      name: "sys"
      PropertyChanges { target: clockWidget; height: 100; width: 480; radius: 28 }
    },
    State {
      name: "pomodoro"
      PropertyChanges { target: clockWidget; height: 76; width: 380; radius: 28 }
    },
    State {
      name: "batteryAlert"
      PropertyChanges { target: clockWidget; height: 72; width: 360; radius: 24 }
    },
  ]

  color: Theme.background

  // Fluid morph animation for expansion/collapse (Apple-like)
  Behavior on height { NumberAnimation { duration: 350; easing.type: Easing.OutQuart } }
  Behavior on width  { NumberAnimation { duration: 350; easing.type: Easing.OutQuart } }
  Behavior on radius { NumberAnimation { duration: 350; easing.type: Easing.OutQuart } }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true

    onClicked: (mouse) => {
      if (clockWidget.showingNotification) return;
      if (clockWidget.showPowerSection) {
        clockWidget.showPowerSection = false;
        return;
      }
      if (clockWidget.showPomodoro) {
        clockWidget.showPomodoro = false;
        return;
      }
      if (clockWidget.showSys) {
        clockWidget.showSys = false;
        return;
      }
      if (clockWidget.showTray) {
        clockWidget.showTray = false;
        return;
      }
      if (clockWidget.showControlCenter) {
        return; // Do nothing if they click the background of the control center itself
      }
      if (clockWidget.showAppLauncher) return;
      if (clockWidget.isExpanded) {
        let mappedPos = mouseArea.mapToItem(expandedContent, mouse.x, mouse.y);
        let clickedItem = expandedContent.childAt(mappedPos.x, mappedPos.y);
        if (clickedItem !== null) return;
      }
      clockWidget.isPinned = !clockWidget.isPinned;
    }
  }

  // --- Collapsed: clock + cava (default) ---
  Item {
    id: collapsedContent
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 36

    opacity: clockWidget.isExpanded || clockWidget.mode !== "default" || (clockWidget.anyOverlayActive && !clockWidget.showBatteryAlert) ? 0.0 : 1.0
    visible: opacity > 0.0
    Behavior on opacity { NumberAnimation { duration: 200 } }

    property real leftWidth: media.playing ? visualizerContainer.width + 12 : 0
    property real rightWidth: (PomodoroService.sessionState !== "Idle" ? pomodoroRow.implicitWidth + 12 : 0) + (privacyContainer.targetWidth > 0 ? privacyContainer.targetWidth + 12 : 0)
    property real maxSide: Math.max(leftWidth, rightWidth)
    property real contentWidth: collapsedClockText.implicitWidth + maxSide * 2

    Text {
      id: collapsedClockText
      anchors.centerIn: parent
      text: Qt.formatDateTime(clock.date, "h:mm AP")
      color: Theme.text
      font { family: "Inter"; pixelSize: 14; weight: 500 }
    }

    Item {
      id: visualizerContainer
      anchors.right: collapsedClockText.left
      anchors.rightMargin: media.playing ? 12 : 0
      anchors.verticalCenter: parent.verticalCenter
      property real targetWidth: media.playing ? 14 : 0
      width: targetWidth
      height: 12
      clip: true

      Behavior on anchors.rightMargin { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }

      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        height: 12

        Rectangle { width: 2; height: Math.min(12, media.bars[0]); radius: 1; color: Theme.primary; anchors.bottom: parent.bottom }
        Rectangle { width: 2; height: Math.min(12, media.bars[1]); radius: 1; color: Theme.primary; anchors.bottom: parent.bottom }
        Rectangle { width: 2; height: Math.min(12, media.bars[2]); radius: 1; color: Theme.primary; anchors.bottom: parent.bottom }
        Rectangle { width: 2; height: Math.min(12, media.bars[3]); radius: 1; color: Theme.primary; anchors.bottom: parent.bottom }
      }
    }

    // Live Activity: Pomodoro
    RowLayout {
      id: pomodoroRow
      anchors.left: collapsedClockText.right
      anchors.leftMargin: PomodoroService.sessionState !== "Idle" ? 12 : 0
      anchors.verticalCenter: parent.verticalCenter
      visible: PomodoroService.sessionState !== "Idle"
      spacing: 6
      
      Behavior on anchors.leftMargin { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }

      Rectangle {
        Layout.preferredWidth: 2
        Layout.preferredHeight: 14
        Layout.alignment: Qt.AlignVCenter
        radius: 1
        color: Theme.border
      }

      Text {
        text: ""
        color: PomodoroService.sessionState === "Work" ? Theme.primary : Theme.tertiary
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
      }
      Text {
        text: PomodoroService.formatTime()
        color: PomodoroService.sessionState === "Work" ? Theme.primary : Theme.tertiary
        font.family: "JetBrains Mono"
        font.pixelSize: 13
        font.weight: 700
      }
    }

    Item {
      id: privacyContainer
      anchors.left: PomodoroService.sessionState !== "Idle" ? pomodoroRow.right : collapsedClockText.right
      anchors.leftMargin: active ? 12 : 0
      anchors.verticalCenter: parent.verticalCenter
      property bool active: (clockWidget.vpnSvc && clockWidget.vpnSvc.isActive) || (clockWidget.privacySvc && (clockWidget.privacySvc.isMicActive || clockWidget.privacySvc.isWebcamActive))
      property real targetWidth: active ? privacyRow.implicitWidth : 0
      width: targetWidth
      height: 18
      clip: true

      Behavior on anchors.leftMargin { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }

      Row {
        id: privacyRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Text {
          text: "󰒄"
          color: Theme.primary
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
          visible: clockWidget.vpnSvc && clockWidget.vpnSvc.isActive
        }

        Rectangle {
          width: 6; height: 6; radius: 3; color: "#f5a623"
          visible: clockWidget.privacySvc && clockWidget.privacySvc.isMicActive
          anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
          width: 6; height: 6; radius: 3; color: "#34c759"
          visible: clockWidget.privacySvc && clockWidget.privacySvc.isWebcamActive
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        visible: clockWidget.vpnSvc && clockWidget.vpnSvc.isActive
        onClicked: {
          clockWidget.exclusiveOpen("vpn");
          clockWidget.showVpn = !clockWidget.showVpn;
        }
      }
    }

  }

  // --- Collapsed: volume / brightness indicator ---
  RowLayout {
    id: indicatorRow
    anchors.centerIn: parent
    spacing: 8

    opacity: !clockWidget.isExpanded && clockWidget.mode !== "default" && !clockWidget.anyOverlayActive ? 1.0 : 0.0
    visible: opacity > 0.0
    Behavior on opacity { NumberAnimation { duration: 200 } }

    // Volume mode
    Item {
      visible: clockWidget.mode === "volume"
      implicitWidth: volLayout.implicitWidth
      implicitHeight: volLayout.implicitHeight

      RowLayout {
        id: volLayout
        anchors.fill: parent
        spacing: 8

        Text {
          text: clockWidget.volumeIcon(clockWidget.volume, clockWidget.audioMuted)
          color: clockWidget.audioMuted ? Theme.subtext : Theme.primary
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
          Behavior on color { ColorAnimation { duration: 120 } }
        }

        Item {
          width: 80; height: 6
          Rectangle {
            anchors.fill: parent; radius: 3; color: Theme.border
            Rectangle {
              anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
              width: parent.width * (clockWidget.audioMuted ? 0 : clockWidget.volume)
              radius: 3
              color: clockWidget.audioMuted ? Theme.border : Theme.primary
              Behavior on width { NumberAnimation { duration: 150; easing: Easing.OutCubic } }
              Behavior on color { ColorAnimation { duration: 120 } }
            }
          }
        }

        Text {
          text: Math.round((clockWidget.audioMuted ? 0 : clockWidget.volume) * 100) + "%"
          color: clockWidget.audioMuted ? Theme.subtext : Theme.text
          font { family: "Inter"; pixelSize: 13; weight: 700 }
          Behavior on color { ColorAnimation { duration: 120 } }
        }
      }

      MouseArea {
        anchors.fill: parent
        onWheel: (wheel) => {
          var step = 0.05;
          var sink = clockWidget.audioSink;
          if (!sink?.audio) return;
          if (wheel.angleDelta.y > 0) {
            sink.audio.volume = Math.min(1, sink.audio.volume + step);
          } else {
            sink.audio.volume = Math.max(0, sink.audio.volume - step);
          }
          sink.audio.muted = false;
          revertTimer.restart();
        }
      }
    }

    // Brightness mode
    Item {
      visible: clockWidget.mode === "brightness"
      implicitWidth: briLayout.implicitWidth
      implicitHeight: briLayout.implicitHeight

      RowLayout {
        id: briLayout
        anchors.fill: parent
        spacing: 8

        Text {
          text: clockWidget.brightnessIcon(clockWidget.brightness)
          color: Qt.rgba(
            0.89, 0.7 + 0.25 * clockWidget.brightness, 0.25,
            0.4 + 0.6 * clockWidget.brightness
          )
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
          Behavior on color { ColorAnimation { duration: 200 } }
        }

        Item {
          width: 80; height: 6
          Rectangle {
            anchors.fill: parent; radius: 3; color: Theme.border
            Rectangle {
              anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
              width: parent.width * clockWidget.brightness
              radius: 3; color: Theme.warning
              Behavior on width { NumberAnimation { duration: 200; easing: Easing.OutCubic } }
            }
          }
        }

        Text {
          text: Math.round(clockWidget.brightness * 100) + "%"
          color: Theme.text
          font { family: "Inter"; pixelSize: 13; weight: 700 }
        }
      }

      MouseArea {
        anchors.fill: parent
        onWheel: (wheel) => {
          var step = 0.05;
          var cur = clockWidget.brightness;
          if (wheel.angleDelta.y > 0) {
            cur = Math.min(1, cur + step);
          } else {
            cur = Math.max(0, cur - step);
          }
          clockWidget.brightnessSetProc.command = ["brightnessctl", "set", Math.round(cur * 100) + "%"];
          clockWidget.brightnessSetProc.running = true;
          revertTimer.restart();
        }
      }
    }

    // Kbd Brightness mode
    RowLayout {
      spacing: 8
      visible: clockWidget.mode === "kbdbacklight"

      Text {
        text: "󰌌"
        color: Theme.primary
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
      }

      Item {
        width: 80; height: 6
        Rectangle {
          anchors.fill: parent; radius: 3; color: Theme.border
          Rectangle {
            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
            width: parent.width * clockWidget.kbdBrightness
            radius: 3; color: Theme.primary
            Behavior on width { NumberAnimation { duration: 200; easing: Easing.OutCubic } }
          }
        }
      }

      Text {
        text: Math.round(clockWidget.kbdBrightness * 100) + "%"
        color: Theme.text
        font { family: "Inter"; pixelSize: 13; weight: 700 }
      }
    }

    // Caps Lock mode
    RowLayout {
      spacing: 8
      visible: clockWidget.mode === "capslock"

      Text {
        text: "󰜹"
        color: clockWidget.capsLock ? Theme.primary : Theme.subtext
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
        Behavior on color { ColorAnimation { duration: 120 } }
      }

      Text {
        text: clockWidget.capsLock ? "ON" : "OFF"
        color: clockWidget.capsLock ? Theme.text : Theme.subtext
        font { family: "Inter"; pixelSize: 13; weight: 700 }
        Behavior on color { ColorAnimation { duration: 120 } }
      }
    }

    // Num Lock mode
    RowLayout {
      spacing: 8
      visible: clockWidget.mode === "numlock"

      Text {
        text: "󰎦"
        color: clockWidget.numLock ? Theme.primary : Theme.subtext
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
        Behavior on color { ColorAnimation { duration: 120 } }
      }

      Text {
        text: clockWidget.numLock ? "ON" : "OFF"
        color: clockWidget.numLock ? Theme.text : Theme.subtext
        font { family: "Inter"; pixelSize: 13; weight: 700 }
        Behavior on color { ColorAnimation { duration: 120 } }
      }
    }

    // Mode indicator
    RowLayout {
      spacing: 8
      visible: clockWidget.mode === "mode"

      Text {
        text: {
          if (!clockWidget.modeSvc) return "";
          var m = clockWidget.modeSvc.currentMode;
          if (m === "silent") return "";
          if (m === "performance") return "";
          return "";
        }
        color: {
          if (!clockWidget.modeSvc) return Theme.subtext;
          var m = clockWidget.modeSvc.currentMode;
          if (m === "silent") return Theme.tertiary;
          if (m === "performance") return Theme.error;
          return Theme.primary;
        }
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
      }

      Text {
        text: {
          if (!clockWidget.modeSvc) return "Balanced";
          var m = clockWidget.modeSvc.currentMode;
          return m.charAt(0).toUpperCase() + m.slice(1);
        }
        color: Theme.text
        font { family: "Inter"; pixelSize: 13; weight: 700 }
      }
    }

  }

  // --- Expanded content (regular) ---
  // Visible when expanded with no notification: shows media player, clock, status capsule.
  Item {
    id: expandedContent
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 64
    anchors.leftMargin: 16
    anchors.rightMargin: 16

    opacity: (clockWidget.isExpanded || clockWidget.showControlCenter) && !clockWidget.showPomodoro && !clockWidget.showSys && !clockWidget.showTray ? 1.0 : 0.0
    visible: opacity > 0.0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    Item {
      id: workspaceArea
      anchors.left: parent.left
      anchors.right: centerSection.left
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      height: Math.max(28, workspaceIndicator.height + 6)

      WorkspaceIndicator {
        id: workspaceIndicator
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Item {
      id: centerSection
      anchors.centerIn: parent

      ColumnLayout {
        id: clockView
        anchors.centerIn: parent
        spacing: 4

        // Time
        Rectangle {
          Layout.alignment: Qt.AlignHCenter
          width: clockText.implicitWidth + 16
          height: clockText.implicitHeight + 8
          radius: 8
          color: timeMouseArea.containsMouse ? Theme.surfaceHover : "transparent"
          
          Text {
            id: clockText
            anchors.centerIn: parent
            text: Qt.formatDateTime(clock.date, "h:mm AP")
            color: Theme.text
            font { family: "Inter"; pixelSize: 20; weight: 700 }
          }
          
          MouseArea {
            id: timeMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (clockWidget.showProductivity && clockWidget.productivityPage === "time") {
                clockWidget.showProductivity = false;
              } else {
                clockWidget.exclusiveOpen("prod");
                clockWidget.productivityPage = "time";
                clockWidget.showProductivity = true;
              }
            }
          }
        }

        // Date
        Rectangle {
          Layout.alignment: Qt.AlignHCenter
          width: dateText.implicitWidth + 12
          height: dateText.implicitHeight + 4
          radius: 6
          color: dateMouseArea.containsMouse ? Theme.surfaceHover : "transparent"

          Text {
            id: dateText
            anchors.centerIn: parent
            text: Qt.formatDateTime(clock.date, "ddd, MMM d")
            color: Theme.text
            opacity: dateMouseArea.containsMouse ? 1.0 : 0.5
            font { family: "Inter"; pixelSize: 11; weight: 500 }
            Behavior on opacity { NumberAnimation { duration: 150 } }
          }

          MouseArea {
            id: dateMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (clockWidget.showProductivity && clockWidget.productivityPage === "calendar") {
                clockWidget.showProductivity = false;
              } else {
                clockWidget.exclusiveOpen("prod");
                clockWidget.productivityPage = "calendar";
                clockWidget.showProductivity = true;
              }
            }
          }
        }
      }
    }

    StatusCapsule {
      id: statusCapsule
      anchors.right: powerButton.left
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      statusSvc: clockWidget.statusSvc
      onClicked: clockWidget.showControlCenter = !clockWidget.showControlCenter
    }

    Rectangle {
      id: powerButton
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: 32; height: 32
      radius: 16
      color: powerMouseArea.containsMouse ? Theme.surfaceHover : "transparent"
      Behavior on color { ColorAnimation { duration: 150 } }
      
      Text {
        anchors.centerIn: parent
        text: "󰐥"
        color: Theme.error
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
      }
      
      MouseArea {
        id: powerMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: clockWidget._powerHovered = containsMouse
        onClicked: {
          clockWidget.showPowerSection = !clockWidget.showPowerSection;
        }
      }
    }
  }

  // --- Pomodoro expanded overlay ---
  Item {
    id: pomodoroExpandedContent
    anchors.fill: parent
    anchors.margins: 16

    opacity: clockWidget.showPomodoro ? 1.0 : 0.0
    visible: opacity > 0.0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    PomodoroSection {
      anchors.fill: parent
    }
  }

  // --- Sys expanded overlay ---
  Item {
    id: sysExpandedContent
    anchors.fill: parent
    anchors.margins: 16

    opacity: clockWidget.showSys ? 1.0 : 0.0
    visible: opacity > 0.0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    SystemUsageSection {
      anchors.fill: parent
    }
  }

  // --- Battery Alert overlay (below clock, only when collapsed) ---
  Item {
    id: batteryAlertOverlay
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: collapsedContent.bottom
    anchors.bottom: parent.bottom

    opacity: clockWidget.showBatteryAlert && !clockWidget.isExpanded ? 1.0 : 0.0
    visible: opacity > 0.0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    RowLayout {
      anchors.centerIn: parent
      spacing: 10

      Item {
        width: 36; height: 18
        Layout.alignment: Qt.AlignVCenter

        Rectangle {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: 32; height: 16
          radius: 4
          color: "transparent"
          border.color: Theme.text
          border.width: 1
          opacity: 0.4
        }

        Rectangle {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          anchors.margins: 2
          anchors.leftMargin: 2
          height: 12
          width: Math.max(0, 28 * ((clockWidget.statusSvc ? clockWidget.statusSvc.battery : 0) / 100))
          radius: 2
          color: clockWidget.batteryAlertMode === "charging" ? Theme.primary : (clockWidget.batteryAlertMode === "low" ? Theme.error : Theme.text)
        }

        Rectangle {
          anchors.left: parent.left
          anchors.leftMargin: 33
          anchors.verticalCenter: parent.verticalCenter
          width: 3; height: 6
          radius: 1.5
          color: Theme.text
          opacity: 0.4
        }

        Text {
          anchors.centerIn: parent
          text: "󱐋"
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
          visible: clockWidget.batteryAlertMode === "charging"
          color: Theme.background
          z: 1
        }
      }
      Text {
        text: clockWidget.batteryAlertMode === "charging" ? "Charging" : (clockWidget.batteryAlertMode === "low" ? "Battery Low" : "Unplugged")
        color: Theme.text
        font.family: "Inter"
        font.pixelSize: 13
        font.weight: 600
      }
      Text {
        text: (clockWidget.statusSvc ? clockWidget.statusSvc.battery : 0) + "%"
        color: clockWidget.batteryAlertMode === "charging" ? Theme.primary : (clockWidget.batteryAlertMode === "low" ? Theme.error : Theme.text)
        font.family: "Inter"
        font.pixelSize: 13
        font.weight: 600
      }
    }
  }

  // --- Tray expanded overlay ---
  Item {
    id: trayExpandedContent
    anchors.fill: parent
    opacity: clockWidget.showTray ? 1.0 : 0.0
    visible: opacity > 0.0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    SystemTraySection {
      anchors.fill: parent
    }
  }

  // --- Control Center expanded overlay ---
  Item {
    id: ccExpandedContent
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 20
    anchors.topMargin: 64
    height: Math.max(0, parent.height - 84) // Prevent negative heights during morph which completely breaks the QML rendering engine
    clip: true // Apple-style smooth unmasking: we clip the perfectly rendered internal layout as the island smoothly morphs!

    opacity: clockWidget.showControlCenter ? 1.0 : 0.0
    visible: opacity > 0.0
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } } // Fades out slightly faster than the morph so it doesn't leave ghost images

    MouseArea {
      anchors.fill: parent
      onClicked: {} // Consume clicks so they don't fall through to the background and pin the island
    }

    Loader {
      id: ccLoader
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      active: clockWidget.showControlCenter || opacity > 0.0
      sourceComponent: Component {
        ControlCenter {
          height: implicitHeight // Instantly snaps to final layout size to prevent jittery recalculations during morph!
          isOpen: clockWidget.showControlCenter
          modeSvc: clockWidget.modeSvc
          storedNotifications: clockWidget.notifService ? clockWidget.notifService.storedNotifications : []
          doNotDisturb: clockWidget.notifService ? clockWidget.notifService.doNotDisturb : false
          onDndToggled: (val) => { if (clockWidget.notifService) clockWidget.notifService.doNotDisturb = val; }
          onDismissNotif: (notifRef) => { if (clockWidget.notifService) clockWidget.notifService.dismissNotif(notifRef); }
          onClearNotifs: { if (clockWidget.notifService) clockWidget.notifService.clearAll(); }
          onCloseRequested: clockWidget.showControlCenter = false
        }
      }
    }
  }

  // --- Power Panel overlay ---
  Item {
    id: powerExpandedContent
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 20
    anchors.topMargin: 64
    height: Math.max(0, parent.height - 84)
    clip: true

    opacity: clockWidget.showPowerSection ? 1.0 : 0.0
    visible: opacity > 0.0
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }

    MouseArea {
      anchors.fill: parent
      onClicked: {}
    }

    Loader {
      id: powerLoader
      anchors.fill: parent
      active: clockWidget.showPowerSection || opacity > 0.0
      sourceComponent: Component {
        PowerPanel {
          isOpen: clockWidget.showPowerSection
          onCloseRequested: clockWidget.showPowerSection = false
        }
      }
    }
  }

  // --- Productivity Center overlay ---
  Item {
    id: prodExpandedContent
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 20
    anchors.topMargin: 64
    height: Math.max(0, parent.height - 84)
    clip: true

    opacity: clockWidget.showProductivity ? 1.0 : 0.0
    visible: opacity > 0.0
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }

    MouseArea {
      anchors.fill: parent
      onClicked: {} // Consume clicks
    }

    Loader {
      id: prodLoader
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      active: clockWidget.showProductivity || opacity > 0.0
      sourceComponent: Component {
        ProductivityCenter {
          height: implicitHeight
          isOpen: clockWidget.showProductivity
          page: clockWidget.productivityPage
          onRequestClose: clockWidget.showProductivity = false
        }
      }
    }
  }

  Notifications {
    id: notifBanner
    anchors.centerIn: parent

    notificationData: clockWidget._currentNotifData
    pendingCount: clockWidget.activityManager ? clockWidget.activityManager.pendingCount : 0

    onDismissed: (notifRef) => {
      if (clockWidget.notifService && notifRef) {
        clockWidget.notifService.dismissBanner(notifRef);
      }
      if (clockWidget.activityManager && clockWidget.activityManager.activeActivity) {
        clockWidget.activityManager.dismiss(clockWidget.activityManager.activeActivity.id);
      }
    }
  }

  PasswordAskpassDialog {
    id: askpassDialog
    anchors.centerIn: parent

    promptText: clockWidget.showAskpass && clockWidget.askpassSvc ? clockWidget.askpassSvc.pendingRequest.prompt : ""
    fifoPath: clockWidget.showAskpass && clockWidget.askpassSvc ? clockWidget.askpassSvc.pendingRequest.fifoPath : ""

    onSubmitted: (password) => { if (clockWidget.askpassSvc) clockWidget.askpassSvc.submit(password); }
    onCancelled: { if (clockWidget.askpassSvc) clockWidget.askpassSvc.cancel(); }
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  VpnSection {
    vpnSvc: clockWidget.vpnSvc
    visible: clockWidget.showVpn
    opacity: visible ? 1 : 0
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: 56
    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
  }
}

