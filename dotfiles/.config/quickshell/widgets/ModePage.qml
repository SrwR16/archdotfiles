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

  ColumnLayout {
    width: parent.width
    spacing: 10

    Text {
      text: "Performance Mode"
      color: Theme.muted
      font.family: "Inter"
      font.pixelSize: 11
      font.weight: 700
      Layout.leftMargin: 4
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      QsCard {
        Layout.fillWidth: true
        Layout.preferredHeight: 64
        highlighted: currentMode === "silent"
        onClicked: setMode("silent")

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 8
          spacing: 2

          Text {
            text: "󰤆"
            color: currentMode === "silent" ? Theme.primary : Theme.subtext
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            Layout.alignment: Qt.AlignHCenter
          }
          Text {
            text: "Silent"
            color: currentMode === "silent" ? Theme.text : Theme.subtext
            font.family: "Inter"
            font.pixelSize: 12
            font.weight: currentMode === "silent" ? 600 : 400
            Layout.alignment: Qt.AlignHCenter
          }
          Text {
            text: "quiet fan · power-saver"
            color: Theme.text
            opacity: 0.4
            font.family: "Inter"
            font.pixelSize: 8
            Layout.alignment: Qt.AlignHCenter
          }
        }
      }

      QsCard {
        Layout.fillWidth: true
        Layout.preferredHeight: 64
        highlighted: currentMode === "balanced"
        onClicked: setMode("balanced")

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 8
          spacing: 2

          Text {
            text: "󰒓"
            color: currentMode === "balanced" ? Theme.primary : Theme.subtext
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            Layout.alignment: Qt.AlignHCenter
          }
          Text {
            text: "Balanced"
            color: currentMode === "balanced" ? Theme.text : Theme.subtext
            font.family: "Inter"
            font.pixelSize: 12
            font.weight: currentMode === "balanced" ? 600 : 400
            Layout.alignment: Qt.AlignHCenter
          }
          Text {
            text: "auto fan · balanced CPU"
            color: Theme.text
            opacity: 0.4
            font.family: "Inter"
            font.pixelSize: 8
            Layout.alignment: Qt.AlignHCenter
          }
        }
      }

      QsCard {
        Layout.fillWidth: true
        Layout.preferredHeight: 64
        highlighted: currentMode === "performance"
        onClicked: setMode("performance")

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 8
          spacing: 2

          Text {
            text: "󰓅"
            color: currentMode === "performance" ? Theme.primary : Theme.subtext
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            Layout.alignment: Qt.AlignHCenter
          }
          Text {
            text: "Performance"
            color: currentMode === "performance" ? Theme.text : Theme.subtext
            font.family: "Inter"
            font.pixelSize: 12
            font.weight: currentMode === "performance" ? 600 : 400
            Layout.alignment: Qt.AlignHCenter
          }
          Text {
            text: "high fan · max CPU"
            color: Theme.text
            opacity: 0.4
            font.family: "Inter"
            font.pixelSize: 8
            Layout.alignment: Qt.AlignHCenter
          }
        }
      }
    }

    Item { Layout.preferredHeight: 4 }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 48
      radius: 12
      color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.85)
      border.color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.85)
      border.width: 1

      RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Text {
          text: "󰔄"
          color: cpuTemp > 0 ? (cpuTemp >= 85 ? Theme.error : Theme.primary) : Theme.subtext
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 16
        }

        ColumnLayout {
          spacing: 1
          Layout.fillWidth: true

          Text {
            text: "CPU Temperature"
            color: Theme.text
            opacity: 0.6
            font.family: "Inter"
            font.pixelSize: 10
          }
          Text {
            text: cpuTemp > 0 ? cpuTemp + "°C" : "—°C"
            color: cpuTemp >= 85 ? Theme.error : Theme.text
            font.family: "Inter"
            font.pixelSize: 14
            font.weight: 700
          }
        }

        Text {
          text: {
            if (currentMode === "silent") return "Power Saver";
            if (currentMode === "performance") return "Performance";
            return "Balanced";
          }
          color: Theme.primary
          font.family: "Inter"
          font.pixelSize: 11
          font.weight: 600
        }
      }
    }

    Text {
      text: "⚠ Silent/Performance modes bypass the automatic temperature curve. If CPU exceeds 85°C, the system force-reverts to Balanced."
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
