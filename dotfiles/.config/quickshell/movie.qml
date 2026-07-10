import "./widgets"
import "./theme"
import "./services"
import QtQuick

Item {
  id: root
  anchors.fill: parent
  signal close()

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.7)

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    MovieWidget {
      anchors.centerIn: parent
      width: Math.min(1200, parent.width * 0.9)
      height: Math.min(800, parent.height * 0.9)
    }
  }
}
