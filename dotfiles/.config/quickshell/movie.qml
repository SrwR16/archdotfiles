import "./widgets"
import "./theme"
import "./services"
import QtQuick
import QtQuick.Window
import Quickshell

FloatingWindow {
  id: root
  visible: true
  flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
  color: "transparent"
  width: Screen.width
  height: Screen.height

  Rectangle {
    anchors.fill: parent
    color: "#cc000000"

    MouseArea {
      anchors.fill: parent
      onClicked: Qt.quit()
    }

    MovieWidget {
      anchors.centerIn: parent
      width: Math.min(1200, parent.width * 0.9)
      height: Math.min(800, parent.height * 0.9)
    }
  }
}
