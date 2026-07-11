import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Layouts

RowLayout {
  property string title: ""
  signal backTapped()

  Layout.fillWidth: true
  spacing: 8

  Text {
    text: "󰅁"
    color: parent.containsMouse ? Theme.primary : Theme.text
    font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
    Behavior on color { ColorAnimation { duration: Motion.durXS } }
    MouseArea {
      id: backHover
      anchors.fill: parent
      anchors.margins: -8
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: parent.parent.backTapped()
    }
  }
  Text {
    text: parent.title
    color: Theme.text
    font { family: "Inter"; pixelSize: 15; weight: 700 }
    Layout.fillWidth: true
  }
}
