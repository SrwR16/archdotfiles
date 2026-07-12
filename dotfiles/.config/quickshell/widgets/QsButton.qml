import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Layouts

// Pill button with filled / outline / ghost variants and hover/press feedback.
// `accent` tints with Theme.primary; otherwise uses surface colors.
Rectangle {
  id: btn
  property string text: ""
  property string icon: ""
  property bool accent: false
  property bool outline: false
  property bool danger: false
  property bool enabled: true
  property int radiusPx: 12
  signal clicked()

  radius: radiusPx
  implicitHeight: 38
  implicitWidth: row.implicitWidth + 28
  color: !btn.enabled ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
    : btn.danger ? (btnMouse.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.22) : Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.14))
    : btn.accent ? (btnMouse.containsMouse ? Theme.primary : Qt.darker(Theme.primary, 1.08))
    : btn.outline ? (btnMouse.containsMouse ? Qt.rgba(Theme.surfaceBright.r, Theme.surfaceBright.g, Theme.surfaceBright.b, 0.6) : "transparent")
    : (btnMouse.containsMouse ? Theme.surfaceHover : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.85))
  border.width: (btn.outline || btn.danger) ? 1 : 0
  border.color: btn.danger ? Theme.error : Theme.outline
  opacity: btn.enabled ? 1.0 : 0.5

  Behavior on color { ColorAnimation { duration: Motion.durXS } }
  Behavior on scale { NumberAnimation { duration: Motion.durInstant; easing.type: Motion.easeStandard } }
  Behavior on opacity { NumberAnimation { duration: Motion.durXS } }

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: btn.icon && btn.text ? 6 : 0
    Text {
      visible: btn.icon
      text: btn.icon
      color: btn.accent ? Theme.backgroundFg : Theme.text
      font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
    }
      Text {
        visible: btn.text
        text: btn.text
        color: btn.danger ? Theme.error : (btn.accent ? Theme.backgroundFg : Theme.text)
        font { family: "Inter"; pixelSize: 12; weight: 600 }
      }
  }

  MouseArea {
    id: btnMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: if (btn.enabled) btn.clicked()
    onPressed: btn.scale = 0.96
    onReleased: btn.scale = 1.0
    onCanceled: btn.scale = 1.0
  }
}
