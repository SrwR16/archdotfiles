import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

ColumnLayout {
  id: traySection
  spacing: 12

  RowLayout {
    Layout.fillWidth: true
    Text {
      text: "System Tray"
      color: Theme.text
      font.family: "Inter"
      font.pixelSize: 14
      font.weight: 600
      Layout.fillWidth: true
    }
  }

  ListView {
    id: trayList
    Layout.fillWidth: true
    Layout.preferredHeight: 64
    orientation: ListView.Horizontal
    spacing: 12
    model: SystemTray.items
    clip: true

    delegate: Item {
      width: 48
      height: 48
      
      Rectangle {
        id: iconRect
        anchors.fill: parent
        radius: 12
        color: Theme.surfaceLight

        Image {
          anchors.centerIn: parent
          width: 32; height: 32
          source: model.icon || ""
          fillMode: Image.PreserveAspectFit
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: iconRect.scale = 1.1
        onExited: iconRect.scale = 1.0
        Behavior on scale { NumberAnimation { duration: 150 } }
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: (mouse) => {
          if (mouse.button === Qt.LeftButton) model.activate()
          else if (mouse.button === Qt.RightButton) model.contextMenu()
          else if (mouse.button === Qt.MiddleButton) model.secondaryActivate()
        }
      }
    }
  }
}
