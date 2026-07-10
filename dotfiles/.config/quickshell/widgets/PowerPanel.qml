import "../theme"
import QtQuick
import Quickshell

Item {
  id: root

  property bool isOpen: false
  property var onCloseRequested

  Row {
    anchors.centerIn: parent
    spacing: 16

    Repeater {
      model: [
        { icon: "", color: Theme.error,     cmd: ["sh", "-c", "loginctl terminate-user $USER"], label: "Logout"  },
        { icon: "", color: Theme.secondary, cmd: ["hyprlock"],                                    label: "Lock"    },
        { icon: "", color: Theme.tertiary,  cmd: ["systemctl", "suspend"],                        label: "Sleep"   },
        { icon: "", color: Theme.warning,   cmd: ["systemctl", "reboot"],                         label: "Reboot"  },
        { icon: "", color: Theme.error,     cmd: ["systemctl", "poweroff"],                       label: "Shutdown" },
      ]

      delegate: Column {
        spacing: 4
        width: 56

        Rectangle {
          id: btnBg
          anchors.horizontalCenter: parent.horizontalCenter
          width: 56; height: 56; radius: 16
          color: btnArea.containsMouse ? Theme.surfaceHover : Theme.surfaceLight
          Behavior on color { ColorAnimation { duration: 150 } }

          Text {
            anchors.centerIn: parent
            text: modelData.icon
            color: modelData.color
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 22 }
          }

          MouseArea {
            id: btnArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: {
              Quickshell.execDetached(modelData.cmd)
              if (root.onCloseRequested) root.onCloseRequested()
            }
          }
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: modelData.label
          color: Theme.text
          opacity: 0.6
          font { family: "Inter"; pixelSize: 10 }
        }
      }
    }
  }
}
