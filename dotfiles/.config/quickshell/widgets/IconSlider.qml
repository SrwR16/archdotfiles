import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Layouts

Item {
  id: slider
  property string iconText: ""
  property real value: 0
  signal moved(real val)

  Layout.fillWidth: true
  height: 40

  Rectangle {
    id: track
    anchors.fill: parent
    radius: 20
    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.75)
    border.color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.75)
    border.width: 1

    Rectangle {
      width: Math.max(40, parent.width * slider.value)
      height: parent.height
      radius: 20
      color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.75)
      Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: 100 } }
    }

    RowLayout {
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: 14
      spacing: 0
      Text {
        text: slider.iconText
        color: Theme.primaryFg
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 15 }
      }
    }

    MouseArea {
      id: drag
      anchors.fill: parent
      onPressed: mouse => slider.moved(mouse.x / width)
      onPositionChanged: mouse => { if (pressed) slider.moved(mouse.x / width) }
    }
  }
}
