import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Layouts
import "."

ColumnLayout {
  id: sysSection
  spacing: 12

  RowLayout {
    Layout.fillWidth: true
    Text {
      text: "System Usage"
      color: Theme.text
      font.family: "Inter"
      font.pixelSize: 14
      font.weight: 600
      Layout.fillWidth: true
    }
  }

  RowLayout {
    spacing: 20
    Layout.fillWidth: true

    // CPU
    ColumnLayout {
      spacing: 6
      Layout.fillWidth: true
      RowLayout {
        Text { text: "CPU"; color: Theme.subtext; font.pixelSize: 12 }
        Item { Layout.fillWidth: true }
        Text { text: Math.round(SystemUsageService.cpuUsage * 100) + "%"; color: Theme.text; font.pixelSize: 12; font.weight: 600 }
      }
      Rectangle {
        Layout.fillWidth: true; height: 6; radius: 3; color: Theme.surfaceLight
        Rectangle {
          height: parent.height; width: parent.width * SystemUsageService.cpuUsage; radius: 3
          color: Theme.primary
          Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        }
      }
    }

    // RAM
    ColumnLayout {
      spacing: 6
      Layout.fillWidth: true
      RowLayout {
        Text { text: "RAM"; color: Theme.subtext; font.pixelSize: 12 }
        Item { Layout.fillWidth: true }
        Text { text: Math.round(SystemUsageService.ramUsage * 100) + "%"; color: Theme.text; font.pixelSize: 12; font.weight: 600 }
      }
      Rectangle {
        Layout.fillWidth: true; height: 6; radius: 3; color: Theme.surfaceLight
        Rectangle {
          height: parent.height; width: parent.width * SystemUsageService.ramUsage; radius: 3
          color: Theme.secondary
          Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        }
      }
    }

    // DISK
    ColumnLayout {
      spacing: 6
      Layout.fillWidth: true
      RowLayout {
        Text { text: "DISK"; color: Theme.subtext; font.pixelSize: 12 }
        Item { Layout.fillWidth: true }
        Text { text: Math.round(SystemUsageService.diskUsage * 100) + "%"; color: Theme.text; font.pixelSize: 12; font.weight: 600 }
      }
      Rectangle {
        Layout.fillWidth: true; height: 6; radius: 3; color: Theme.surfaceLight
        Rectangle {
          height: parent.height; width: parent.width * SystemUsageService.diskUsage; radius: 3
          color: Theme.tertiary
          Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        }
      }
    }
  }
}
