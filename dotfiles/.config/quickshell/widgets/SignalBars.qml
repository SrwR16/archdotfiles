import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Layouts

// Animated Wi-Fi signal strength indicator (4 ascending bars).
// Heights animate smoothly as `signal` changes; the active set is tinted with
// `barColor`, the rest with a dimmed track. Robust to signal values > 100.
Item {
  id: root
  property int signal: 0          // 0-100
  property color barColor: Theme.primary
  property color trackColor: Theme.outline
  property int bars: 4
  property int barWidth: 3
  property int gap: 2

  implicitWidth: bars * barWidth + (bars - 1) * gap
  implicitHeight: 16

  readonly property int _lvl: Math.max(0, Math.min(bars, Math.round((Math.max(0, Math.min(100, signal)) / 100) * bars)))

  Row {
    anchors.centerIn: parent
    spacing: gap

    Repeater {
      model: root.bars

      delegate: Rectangle {
        required property int index
        width: root.barWidth
        height: (index + 1) * (root.implicitHeight / root.bars) - 1
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        color: index < root._lvl ? root.barColor : root.trackColor
        opacity: index < root._lvl ? 1.0 : 0.35
        Behavior on color { ColorAnimation { duration: Motion.durXS } }
        Behavior on opacity { NumberAnimation { duration: Motion.durXS } }
        Behavior on height { NumberAnimation { duration: Motion.durM; easing.type: Motion.easeStandard } }
      }
    }
  }
}
