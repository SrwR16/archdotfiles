import "../theme"
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
  id: root

  property bool isOpen: false
  property var onCloseRequested

  property int _holdMs: 850

  GridLayout {
    anchors.horizontalCenter: parent.horizontalCenter
    columns: 2
    columnSpacing: 14
    rowSpacing: 14

    Repeater {
      model: [
        { icon: "", color: Theme.error,     cmd: ["sh", "-c", "loginctl terminate-user $USER"], label: "Logout",   confirm: false },
        { icon: "", color: Theme.secondary, cmd: ["sh", "-c", "~/.config/dotfiles/scripts/power -l"], label: "Lock",     confirm: false },
        { icon: "", color: Theme.tertiary,  cmd: ["systemctl", "suspend"],                        label: "Sleep",    confirm: false },
        { icon: "", color: Theme.warning,   cmd: ["systemctl", "reboot"],                         label: "Reboot",   confirm: true  },
        { icon: "", color: Theme.error,     cmd: ["systemctl", "poweroff"],                        label: "Shutdown", confirm: true  },
      ]

      delegate: Rectangle {
        id: tile
        required property var modelData
        width: 124
        height: 92
        radius: 18
        color: tileMouse.containsMouse ? Theme.surfaceHover : Theme.surfaceLight
        scale: tileMouse.pressed && !modelData.confirm ? 0.96 : 1.0
        Behavior on color { ColorAnimation { duration: Motion.durXS } }
        Behavior on scale { NumberAnimation { duration: Motion.durXS; easing.type: Motion.easeStandard } }

        // hold-to-confirm fill
        Rectangle {
          id: fill
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: 0
          radius: parent.radius
          color: modelData.color
          opacity: 0.28
        }
        NumberAnimation {
          id: fillAnim
          target: fill
          property: "width"
          from: 0
          to: tile.width
          duration: root._holdMs
          easing.type: Motion.easeStandard
        }
        Timer {
          id: holdTimer
          interval: root._holdMs
          onTriggered: { run(); root.onCloseRequested(); }
        }

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 6

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: modelData.icon
            color: modelData.color
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 26 }
          }
          Text {
            Layout.alignment: Qt.AlignHCenter
            text: modelData.label
            color: Theme.text
            opacity: 0.7
            font { family: "Inter"; pixelSize: 11; weight: 600 }
          }
          Text {
            visible: modelData.confirm
            Layout.alignment: Qt.AlignHCenter
            text: "hold"
            color: modelData.color
            opacity: 0.6
            font { family: "Inter"; pixelSize: 8 }
          }
        }

        function run() { Quickshell.execDetached(modelData.cmd); }

        MouseArea {
          id: tileMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onPressed: {
            if (modelData.confirm) { fill.width = 0; fillAnim.restart(); holdTimer.restart(); }
            else { run(); root.onCloseRequested(); }
          }
          onReleased: {
            if (modelData.confirm) { holdTimer.stop(); fillAnim.stop(); fill.width = 0; }
          }
          onCanceled: {
            if (modelData.confirm) { holdTimer.stop(); fillAnim.stop(); fill.width = 0; }
          }
        }
      }
    }
  }
}
