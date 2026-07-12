import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Layouts

Rectangle {
  id: tile
  property string iconText: ""
  property string label: ""
  property string sublabel: ""
  property bool active: false
  property bool expandable: false
  signal tapped()
  signal expandTapped()

  Layout.fillWidth: true
  Layout.preferredHeight: 56
  radius: 16
  color: active ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.85) : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.85)
  border.color: active ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.85) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.85)
  border.width: 1
  scale: tile._pressed ? 0.97 : (tile._hover ? 1.02 : 1.0)
  Behavior on scale { NumberAnimation { duration: Motion.durXS; easing.type: Motion.easeStandard } }
  Behavior on color { ColorAnimation { duration: Motion.durXS } }
  Behavior on border.color { ColorAnimation { duration: Motion.durXS } }

  property bool _pressed: false
  property bool _hover: false

  RowLayout {
    anchors.fill: parent
    anchors.margins: 12
    spacing: 10

    Rectangle {
      width: 32; height: 32; radius: 16
      color: tile.active ? Qt.rgba(Theme.primaryFg.r, Theme.primaryFg.g, Theme.primaryFg.b, 0.85) : Qt.rgba(Theme.surfaceBright.r, Theme.surfaceBright.g, Theme.surfaceBright.b, 0.85)
      Behavior on color { ColorAnimation { duration: Motion.durXS } }

      Text {
        anchors.centerIn: parent
        text: tile.iconText
        color: tile.active ? Theme.text : Theme.primary
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
      }
    }
    ColumnLayout {
      spacing: 0
      Layout.fillWidth: true
      Text {
        text: tile.label
        color: tile.active ? Theme.background : Theme.text
        elide: Text.ElideRight
        Layout.fillWidth: true
        font { family: "Inter"; pixelSize: 13; weight: 700 }
      }
      Text {
        text: tile.sublabel
        color: tile.active ? Theme.background : Theme.text
        opacity: 0.7
        elide: Text.ElideRight
        Layout.fillWidth: true
        font { family: "Inter"; pixelSize: 10 }
      }
    }
    Text {
      visible: tile.expandable
      text: "󰅂"
      color: tile.active ? Theme.background : Theme.text
      opacity: 0.6
      font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
    }
  }

  MouseArea {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: tile.expandable ? parent.width * 0.72 : parent.width
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true
    onEntered: tile._hover = true
    onExited: tile._hover = false
    onPressed: tile._pressed = true
    onReleased: tile._pressed = false
    onCanceled: tile._pressed = false
    onClicked: tile.tapped()
  }

  MouseArea {
    visible: tile.expandable
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: parent.width * 0.28
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true
    onEntered: tile._hover = true
    onExited: tile._hover = false
    onPressed: tile._pressed = true
    onReleased: tile._pressed = false
    onCanceled: tile._pressed = false
    onClicked: tile.expandTapped()
  }
}
