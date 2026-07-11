import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Bluetooth

ScrollView {
  id: sv
  padding: 0
  ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
  ScrollBar.vertical.policy: ScrollBar.AsNeeded
  contentWidth: width

  property var btAdapter
  property var btDevices
  property bool btScanning
  property var btDeviceSubtitle

  signal toggleBluetooth()
  signal toggleBtScan()
  signal forgetDevice(var device)
  signal pairDevice(var device)
  signal toggleBtConnection(var device)
  signal backRequested()

  readonly property bool _on: !!btAdapter && btAdapter.enabled

  ColumnLayout {
    width: parent.width
    spacing: 10

    // ============ HEADER ============
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 52
      radius: 16
      color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.85)
      border.color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.85)
      border.width: 1

      RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        Text {
          text: "Bluetooth"
          color: Theme.text
          font.family: "Inter"
          font.pixelSize: 14
          font.weight: 700
        }
        Item { Layout.fillWidth: true }
        Text {
          text: _on ? "On" : "Off"
          color: _on ? Theme.primary : Theme.subtext
          font.family: "Inter"
          font.pixelSize: 11
          font.weight: 600
          opacity: 0.8
        }
        Rectangle {
          width: 46
          height: 26
          radius: 13
          color: _on ? Theme.primary : Theme.border
          Behavior on color { ColorAnimation { duration: Motion.durXS } }

          Rectangle {
            width: 20
            height: 20
            radius: 10
            color: Theme.backgroundFg
            anchors.verticalCenter: parent.verticalCenter
            x: _on ? parent.width - width - 3 : 3
            Behavior on x { NumberAnimation { duration: Motion.durS; easing.type: Motion.easeStandard } }
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleBluetooth()
          }
        }
      }
    }

    // ============ DEVICES HEADER ============
    RowLayout {
      Layout.fillWidth: true
      Layout.topMargin: 4
      spacing: 8

      Text {
        text: "Devices"
        color: Theme.text
        opacity: 0.7
        font.family: "Inter"
        font.pixelSize: 12
        font.weight: 700
      }
      Item { Layout.fillWidth: true }
      RowLayout {
        spacing: 6

        Spinner {
          visible: btScanning
          running: btScanning
          size: 14
          color: Theme.primary
        }
        Text {
          text: btScanning ? "Scanning…" : "Scan"
          color: _on ? Theme.primary : Theme.subtext
          font.family: "Inter"
          font.pixelSize: 11
          font.weight: 600

          MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: if (_on) toggleBtScan()
          }
        }
      }
    }

    // ============ DEVICE LIST ============
    Repeater {
      model: _on ? btDevices : []

      delegate: Rectangle {
        id: btCard
        required property var modelData
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        radius: 14
        color: modelData.state === BluetoothDeviceState.Connected
          ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
          : (modelData.pairing ? Theme.surfaceHover : Theme.surface)
        border.color: modelData.state === BluetoothDeviceState.Connected ? Theme.primary : "transparent"
        border.width: modelData.state === BluetoothDeviceState.Connected ? 1.5 : 0
        Behavior on color { ColorAnimation { duration: Motion.durXS } }

        RowLayout {
          anchors.fill: parent
          anchors.margins: 14
          spacing: 12

          Text {
            text: modelData.pairing ? "󰄉"
              : (modelData.state === BluetoothDeviceState.Connected ? "󰂱" : "󰂯")
            color: modelData.state === BluetoothDeviceState.Connected ? Theme.primary : Theme.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
          }

          ColumnLayout {
            spacing: 0
            Layout.fillWidth: true

            Text {
              text: btCard.modelData.name || btCard.modelData.deviceName || "Unknown device"
              color: Theme.text
              elide: Text.ElideRight
              Layout.fillWidth: true
              font.family: "Inter"
              font.pixelSize: 13
              font.weight: 600
            }
            RowLayout {
              spacing: 6

              Text {
                text: btDeviceSubtitle(btCard.modelData)
                color: modelData.state === BluetoothDeviceState.Connected ? Theme.primary : Theme.text
                opacity: modelData.state === BluetoothDeviceState.Connected ? 1 : 0.6
                font.family: "Inter"
                font.pixelSize: 10
              }
              Text {
                visible: modelData.batteryAvailable
                text: Math.round(modelData.battery * 100) + "%"
                color: Theme.subtext
                font.family: "Inter"
                font.pixelSize: 10
              }
            }
          }

          // Connecting / pairing spinner
          Spinner {
            visible: modelData.state === BluetoothDeviceState.Connecting || modelData.pairing
            running: modelData.state === BluetoothDeviceState.Connecting || modelData.pairing
            size: 16
            color: Theme.primary
          }

          // Connect / Disconnect
          Text {
            visible: modelData.paired && !modelData.pairing
              && modelData.state !== BluetoothDeviceState.Connecting
            text: modelData.state === BluetoothDeviceState.Connected ? "Disconnect" : "Connect"
            color: Theme.primary
            font.family: "Inter"
            font.pixelSize: 11
            font.weight: 600

            MouseArea {
              anchors.fill: parent
              anchors.margins: -8
              cursorShape: Qt.PointingHandCursor
              onClicked: toggleBtConnection(modelData)
            }
          }

          // Pair / Forget
          Text {
            visible: !modelData.pairing
              && modelData.state !== BluetoothDeviceState.Connecting
            text: modelData.paired ? "Forget" : "Pair"
            color: modelData.paired ? Theme.error : Theme.text
            opacity: modelData.paired ? 0.85 : 0.7
            font.family: "Inter"
            font.pixelSize: 11
            font.weight: 600

            MouseArea {
              anchors.fill: parent
              anchors.margins: -8
              cursorShape: Qt.PointingHandCursor
              onClicked: modelData.paired ? forgetDevice(modelData) : pairDevice(modelData)
            }
          }
        }
      }
    }

    // Empty / offline states
    Text {
      visible: _on && btDevices.length === 0 && !btScanning
      text: "No devices found"
      color: Theme.text
      opacity: 0.4
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: 12
      font.family: "Inter"
      font.pixelSize: 12
    }
    Text {
      visible: _on && btScanning && btDevices.length === 0
      text: "Scanning for devices…"
      color: Theme.primary
      opacity: 0.6
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: 12
      font.family: "Inter"
      font.pixelSize: 12
    }
    Text {
      visible: !_on
      text: "Turn on Bluetooth to see devices"
      color: Theme.text
      opacity: 0.4
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: 12
      font.family: "Inter"
      font.pixelSize: 12
    }

    Item { Layout.preferredHeight: 4 }
  }
}
