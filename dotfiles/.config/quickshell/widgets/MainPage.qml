import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

ColumnLayout {
  spacing: 10

  property string page: ""
  property var modeSvc: null
  property bool wifiEnabled: false
  property string wifiName: ""
  property var volumeIcon
  property real audioVolume: 0
  property bool audioMuted: false
  property var audioSink
  property var btAdapter
  readonly property var _btDevices: btAdapter ? btAdapter.devices.values : []
  readonly property string _btConnectedName: {
    if (!btAdapter || !btAdapter.enabled) return "Off";
    var d = _btDevices;
    for (var i = 0; i < d.length; i++) {
      if (d[i].state === BluetoothDeviceState.Connected) return d[i].name || d[i].deviceName || "Connected";
    }
    return "On";
  }
  property bool nlEnabled: false
  property bool doNotDisturb: false
  property var brightnessIcon
  property real brightness: 0
  property var activePlayer
  readonly property bool _hasTrack: !!activePlayer && !!activePlayer.trackTitle
  property string playerArt: ""
  property var storedNotifications: []

  signal navigateTo(string page)
  signal toggleWifi()
  signal scanWifi()
  signal loadCurrentWifiPassword()
  signal toggleMute()
  signal toggleBluetooth()
  signal toggleNightLight()
  signal toggleDnd()
  signal setVolume(real val)
  signal setBrightness(real val)
  signal dismissNotif(var notifRef)
  signal clearNotifs()

  SystemClock { id: clock; precision: SystemClock.Minutes }

  // ---- Quick toggles (compact 3-col grid) ----
  GridLayout {
    Layout.fillWidth: true
    columns: 3
    rowSpacing: 10
    columnSpacing: 10
    opacity: 0
    SequentialAnimation on opacity {
  PauseAnimation { duration: 0 }
  NumberAnimation { from: 0; to: 1; duration: Motion.durM; easing.type: Motion.easeStandard; objectName: "entrance" }
}

    ToggleTile {
      iconText: wifiEnabled ? "" : "󰖪"
      label: "Wi-Fi"
      sublabel: wifiEnabled ? wifiName : "Off"
      active: wifiEnabled
      expandable: true
      onTapped: toggleWifi()
      onExpandTapped: { navigateTo("wifi"); scanWifi(); loadCurrentWifiPassword(); }
    }
    ToggleTile {
      iconText: "󰂯"
      label: "Bluetooth"
      sublabel: _btConnectedName
      active: !!btAdapter && btAdapter.enabled
      expandable: true
      onTapped: toggleBluetooth()
      onExpandTapped: navigateTo("bluetooth")
    }
    ToggleTile {
      iconText: volumeIcon(audioVolume, audioMuted)
      label: "Audio"
      sublabel: audioMuted ? "Muted" : (!!audioSink ? (audioSink.description || audioSink.name) : "Speaker")
      active: !audioMuted
      expandable: true
      onTapped: toggleMute()
      onExpandTapped: navigateTo("audio")
    }
    ToggleTile {
      iconText: "󰂚"
      label: "Night Light"
      sublabel: nlEnabled ? "On" : "Off"
      active: nlEnabled
      expandable: true
      onTapped: toggleNightLight()
      onExpandTapped: navigateTo("nightlight")
    }
    ToggleTile {
      iconText: "󱐋"
      label: "Performance"
      sublabel: modeSvc ? modeSvc.currentMode.charAt(0).toUpperCase() + modeSvc.currentMode.slice(1) : "Balanced"
      active: true
      expandable: true
      onExpandTapped: navigateTo("mode")
    }
    ToggleTile {
      iconText: ""
      label: "Peace"
      sublabel: doNotDisturb ? "On" : "Off"
      active: doNotDisturb
      onTapped: toggleDnd()
    }
  }

  // ---- Sliders (two-up) ----
  RowLayout {
    Layout.fillWidth: true
    spacing: 10
    opacity: 0
    SequentialAnimation on opacity {
  PauseAnimation { duration: 70 }
  NumberAnimation { from: 0; to: 1; duration: Motion.durM; easing.type: Motion.easeStandard; objectName: "entrance" }
}

    IconSlider {
      Layout.fillWidth: true
      iconText: volumeIcon(audioVolume, audioMuted)
      value: audioMuted ? 0 : audioVolume
      onMoved: val => setVolume(val)
    }
    IconSlider {
      Layout.fillWidth: true
      iconText: brightnessIcon(brightness)
      value: brightness
      onMoved: val => setBrightness(val)
    }
  }

  // ---- Media Player ----
  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: _hasTrack ? 84 : 36
    opacity: 0
    SequentialAnimation on opacity {
  PauseAnimation { duration: 140 }
  NumberAnimation { from: 0; to: 1; duration: Motion.durM; easing.type: Motion.easeStandard; objectName: "entrance" }
}

    Behavior on Layout.preferredHeight { NumberAnimation { duration: Motion.durM; easing.type: Motion.easeStandard } }

    Rectangle {
      anchors.fill: parent
      radius: 16
      color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
      border.color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.55)
      border.width: 1
      visible: _hasTrack
      clip: true

      RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Rectangle {
          width: 52; height: 52; radius: 13
          color: Qt.rgba(Theme.surfaceLight.r, Theme.surfaceLight.g, Theme.surfaceLight.b, 0.85); clip: true

          Image {
            anchors.fill: parent
            source: playerArt || ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 104; sourceSize.height: 104

            Rectangle {
              anchors.fill: parent
              color: Theme.surfaceLight
              visible: parent.status !== Image.Ready
              Text { anchors.centerIn: parent; text: "󰎆"; color: Theme.primary; font { family: "JetBrainsMono Nerd Font"; pixelSize: 20 } }
            }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          Text {
            text: _hasTrack ? activePlayer.trackTitle : ""
            color: Theme.text
            font { family: "Inter"; pixelSize: 13; weight: 700 }
            elide: Text.ElideRight; Layout.fillWidth: true
          }
          Text {
            text: activePlayer ? (activePlayer.trackArtist || "") : ""
            color: Theme.text
            opacity: 0.6
            elide: Text.ElideRight; Layout.fillWidth: true
            font { family: "Inter"; pixelSize: 11 }
          }

          RowLayout {
            spacing: 8
            Layout.topMargin: 4
            Text {
              text: "󰒮"; color: Theme.subtext
              font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
              MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: if (activePlayer) activePlayer.previous() }
            }
            Rectangle {
              width: 28; height: 28; radius: 14; color: Theme.text
              Text { anchors.centerIn: parent; text: (activePlayer && activePlayer.isPlaying) ? "" : ""; color: Theme.surface; font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 } }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (activePlayer) activePlayer.togglePlaying() }
            }
            Text {
              text: "󰒭"; color: Theme.subtext
              font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
              MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: if (activePlayer) activePlayer.next() }
            }
            Rectangle {
              Layout.fillWidth: true; height: 3; radius: 1.5; color: Theme.text; opacity: 0.18; Layout.alignment: Qt.AlignVCenter
              Rectangle {
                height: parent.height; radius: 1.5; color: Theme.text
                width: parent.width * ((activePlayer && activePlayer.length > 0) ? activePlayer.position / activePlayer.length : 0)
              }
            }
          }
        }
      }
    }

    RowLayout {
      anchors.fill: parent
      spacing: 8
      visible: !_hasTrack
      Text { text: "󰎆"; color: Theme.subtext; font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 } }
      Text { text: "Nothing playing"; color: Theme.text; opacity: 0.4; font { family: "Inter"; pixelSize: 12 } }
    }
  }

  // ---- Notifications ----
  NotificationHistory {
    id: notifHist
    Layout.fillWidth: true
    storedNotifications: storedNotifications
    Layout.preferredHeight: (storedNotifications ? storedNotifications.length : 0) > 0 ? 220 : 64
    opacity: 0
    SequentialAnimation on opacity {
  PauseAnimation { duration: 210 }
  NumberAnimation { from: 0; to: 1; duration: Motion.durM; easing.type: Motion.easeStandard; objectName: "entrance" }
}
    onDismissNotif: (n) => dismissNotif(n)
    onClearAll: clearNotifs()
  }

  Item { Layout.fillHeight: true }
}
