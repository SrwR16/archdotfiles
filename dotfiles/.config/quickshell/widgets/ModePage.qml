import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
  id: sv
  padding: 0
  ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
  ScrollBar.vertical.policy: ScrollBar.AsNeeded
  contentWidth: width

  required property string currentMode
  required property real cpuTemp

  signal setMode(string mode)
  signal backRequested()

  readonly property var _modes: [
    { key: "silent",      icon: "󰤆", title: "Silent",      desc: "Quiet fan · power saver",     hint: "Best battery",   glyph: "󰤆" },
    { key: "balanced",    icon: "󰒓", title: "Balanced",   desc: "Auto fan · balanced CPU",     hint: "Recommended", glyph: "󰒓" },
    { key: "performance", icon: "󰓅", title: "Performance", desc: "High fan · max clocks",        hint: "Max speed",    glyph: "󰓅" },
  ]

  ColumnLayout {
    width: parent.width
    spacing: 12

    // ============ MODE TILES ============
    RowLayout {
      Layout.fillWidth: true
      spacing: 10

      Repeater {
        model: _modes

        Rectangle {
          id: tile
          required property var modelData
          Layout.fillWidth: true
          Layout.preferredHeight: 122
          radius: 18
          color: currentMode === modelData.key
            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
            : (tileMouse.containsMouse ? Theme.surfaceHover : Theme.surface)
          border.color: currentMode === modelData.key ? Theme.primary : Theme.outline
          border.width: currentMode === modelData.key ? 1.5 : 1
          Behavior on color { ColorAnimation { duration: Motion.durXS } }

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 6

            RowLayout {
              spacing: 8

              Rectangle {
                width: 38; height: 38; radius: 12
                color: currentMode === modelData.key
                  ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
                  : Theme.surfaceLight
                Text {
                  anchors.centerIn: parent
                  text: modelData.glyph
                  color: currentMode === modelData.key ? Theme.primary : Theme.subtext
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 19
                }
              }
              Item { Layout.fillWidth: true }
              Text {
                visible: currentMode === modelData.key
                text: "✓"
                color: Theme.primary
                font.family: "Inter"
                font.pixelSize: 14
                font.weight: 700
              }
            }
            Text {
              text: modelData.title
              color: currentMode === modelData.key ? Theme.text : Theme.subtext
              font.family: "Inter"
              font.pixelSize: 14
              font.weight: 700
            }
            Text {
              text: modelData.desc
              color: Theme.text
              opacity: 0.55
              font.family: "Inter"
              font.pixelSize: 9
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }
            Item { Layout.fillHeight: true }
            Text {
              text: modelData.hint
              color: currentMode === modelData.key ? Theme.primary : Theme.subtext
              opacity: currentMode === modelData.key ? 0.9 : 0.4
              font.family: "Inter"
              font.pixelSize: 9
              font.weight: 600
            }
          }
          MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: setMode(modelData.key)
          }
        }
      }
    }

    // ============ ACTIVE PROFILE ============
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 60
      radius: 16
      color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.85)
      border.color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.85)
      border.width: 1

      RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Text {
          text: {
            if (currentMode === "silent") return "󰤆";
            if (currentMode === "performance") return "󰓅";
            return "󰒓";
          }
          color: Theme.primary
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 20
        }
        ColumnLayout {
          spacing: 1
          Layout.fillWidth: true

          Text {
            text: "Active profile"
            color: Theme.text
            opacity: 0.6
            font.family: "Inter"
            font.pixelSize: 10
          }
          Text {
            text: {
              if (currentMode === "silent") return "Power Saver";
              if (currentMode === "performance") return "Performance";
              return "Balanced";
            }
            color: Theme.text
            font.family: "Inter"
            font.pixelSize: 14
            font.weight: 700
          }
        }
        Rectangle {
          width: 1; height: 30
          color: Theme.outline
          opacity: 0.5
        }
        ColumnLayout {
          spacing: 1

          Text {
            text: "CPU"
            color: Theme.text
            opacity: 0.6
            font.family: "Inter"
            font.pixelSize: 10
          }
          Text {
            text: cpuTemp > 0 ? Math.round(cpuTemp) + "°C" : "—°C"
            color: cpuTemp >= 85 ? Theme.error : Theme.text
            font.family: "Inter"
            font.pixelSize: 14
            font.weight: 700
          }
        }
      }
    }

    Text {
      text: "⚠ Silent / Performance bypass the automatic fan curve. If CPU exceeds 85°C the system force-reverts to Balanced."
      color: Theme.text
      opacity: 0.4
      wrapMode: Text.WordWrap
      font.family: "Inter"
      font.pixelSize: 9
      Layout.fillWidth: true
      Layout.topMargin: 2
    }

    Item { Layout.preferredHeight: 4 }
  }
}
