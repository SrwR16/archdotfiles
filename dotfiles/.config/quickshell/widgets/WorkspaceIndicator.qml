import Quickshell.Hyprland
import QtQuick
import "../theme"

Item {
  id: root
  implicitWidth: col.implicitWidth
  implicitHeight: col.implicitHeight
  height: implicitHeight

  readonly property int pillSize: 24
  readonly property int pillSpacing: 6
  readonly property int rowSpacing: 4
  readonly property int firstRowCount: root._count <= 5 ? root._count : Math.ceil(root._count / 2)
  readonly property int secondRowCount: root._count - firstRowCount

  property var _items: []
  property int _focused: -1
  property int _count: 0

  function windowCount(ws) {
    if (!ws || !ws.toplevels) return 0
    try { return ws.toplevels.values.length } catch (e) { return 0 }
  }

  function update() {
    try {
      if (!Hyprland || !Hyprland.workspaces) return
      var vals = Hyprland.workspaces.values
      if (!vals) return

      var list = []
      for (var i = 0; i < vals.length; i++) {
        var ws = vals[i]
        if (ws && (ws.focused || windowCount(ws) > 0))
          list.push(ws)
      }
      list.sort(function(a, b) { return a.id - b.id })
      _items = list
      _count = list.length

      _focused = -1
      for (var j = 0; j < list.length; j++) {
        if (list[j].focused) { _focused = j; break }
      }
    } catch (e) {}
  }

  Connections {
    target: Hyprland.workspaces
    function onValuesChanged() { root.update() }
  }

  Connections {
    target: Hyprland
    function onFocusedWorkspaceChanged() { root.update() }
  }

  Timer {
    interval: 300
    running: true
    repeat: true
    onTriggered: {
      root.update()
      if (root._count > 0)
        running = false
    }
  }

  Component.onCompleted: Qt.callLater(root.update)

  Column {
    id: col
    spacing: rowSpacing
    anchors.verticalCenter: parent.verticalCenter

    Row {
      spacing: pillSpacing
      Repeater {
        model: root.firstRowCount
        delegate: Item {
          readonly property int realIndex: index
          readonly property var ws: root._items.length > realIndex ? root._items[realIndex] : null
          readonly property bool isActive: realIndex === root._focused
          readonly property bool hasWindows: ws ? root.windowCount(ws) > 0 : false

          width: pillSize
          height: pillSize

          Rectangle {
            anchors.fill: parent
            radius: 6
            color: isActive ? Theme.tertiary : (hasWindows ? Theme.surfaceContainer : Theme.surface)
          }

          Text {
            anchors.centerIn: parent
            text: ws ? ws.id : ""
            color: isActive ? Theme.onPrimary : Theme.text
            font {
              family: "Inter"
              pixelSize: 11
              weight: isActive ? Font.Bold : Font.Medium
            }
          }
        }
      }
    }

    Row {
      spacing: pillSpacing
      visible: root.secondRowCount > 0
      Repeater {
        model: root.secondRowCount
        delegate: Item {
          readonly property int realIndex: root.firstRowCount + index
          readonly property var ws: root._items.length > realIndex ? root._items[realIndex] : null
          readonly property bool isActive: realIndex === root._focused
          readonly property bool hasWindows: ws ? root.windowCount(ws) > 0 : false

          width: pillSize
          height: pillSize

          Rectangle {
            anchors.fill: parent
            radius: 6
            color: isActive ? Theme.tertiary : (hasWindows ? Theme.surfaceContainer : Theme.surface)
          }

          Text {
            anchors.centerIn: parent
            text: ws ? ws.id : ""
            color: isActive ? Theme.onPrimary : Theme.text
            font {
              family: "Inter"
              pixelSize: 11
              weight: isActive ? Font.Bold : Font.Medium
            }
          }
        }
      }
    }
  }
}
