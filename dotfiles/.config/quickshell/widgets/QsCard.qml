import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Layouts

// Standard panel surface: rounded, theme-aware, with consistent hover/press
// feedback. Use as the building block for every card, row and tile so the whole
// shell shares one visual language.
Rectangle {
  id: card
  property bool interactive: false
  property bool highlighted: false   // primary/accent tint (e.g. active item)
  property int radiusPx: 16
  property color baseColor: highlighted
    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
    : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.85)
  property color hoverColor: highlighted
    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
    : Qt.rgba(Theme.surfaceBright.r, Theme.surfaceBright.g, Theme.surfaceBright.b, 0.85)

  radius: radiusPx
  color: cardMouse.containsMouse ? hoverColor : baseColor
  border.color: highlighted ? Theme.primary : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.85)
  border.width: highlighted ? 1.5 : 1

  Behavior on color { ColorAnimation { duration: Motion.durXS } }
  Behavior on scale { NumberAnimation { duration: Motion.durInstant; easing.type: Motion.easeStandard } }

  property alias mouseArea: cardMouse
  signal clicked()

  MouseArea {
    id: cardMouse
    anchors.fill: parent
    hoverEnabled: card.interactive
    cursorShape: card.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
    onPressed: card.scale = 0.985
    onReleased: card.scale = 1.0
    onCanceled: card.scale = 1.0
    onClicked: card.clicked()
  }
}
