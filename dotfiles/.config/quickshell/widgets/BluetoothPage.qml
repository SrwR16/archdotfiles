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
  readonly property var _paired: _on ? btDevices.filter(function (d) { return d.paired; }) : []
  readonly property var _available: _on ? btDevices.filter(function (d) { return !d.paired; }) : []

  ColumnLayout {
    width: parent.width
    spacing: 12

    // ============ ENABLE CONTROL (title is in the panel header) ============
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 50
      radius: 14
      color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.85)
      border.color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.85)
      border.width: 1
      opacity: 0
      SequentialAnimation on opacity {
  PauseAnimation { duration: 0 }
  NumberAnimation { from: 0; to: 1; duration: Motion.durM; easing.type: Motion.easeStandard; objectName: "entrance" }
}

      RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Rectangle {
          width: 26; height: 26; radius: 8
          color: _on ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18) : Theme.surfaceLight
          Text {
            anchors.centerIn: parent
            text: "󰂯"
            color: _on ? Theme.primary : Theme.subtext
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
          }
        }
        Text {
          text: _on ? "Enabled" : "Disabled"
          color: _on ? Theme.primary : Theme.subtext
          font.family: "Inter"
          font.pixelSize: 12
          font.weight: 600
        }
        Item { Layout.fillWidth: true }
        Rectangle {
          width: 44; height: 25; radius: 12
          color: _on ? Theme.primary : Theme.border
          Behavior on color { ColorAnimation { duration: Motion.durXS } }

          Rectangle {
            width: 19; height: 19; radius: 9
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

    // ============ MY DEVICES ============
    ColumnLayout {
      visible: _on
      Layout.fillWidth: true
      spacing: 8
      opacity: 0
      SequentialAnimation on opacity {
  PauseAnimation { duration: 60 }
  NumberAnimation { from: 0; to: 1; duration: Motion.durM; easing.type: Motion.easeStandard; objectName: "entrance" }
}

      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text { text: "My Devices"; color: Theme.muted; font.family: "Inter"; font.pixelSize: 11; font.weight: 700; leftPadding: 4 }
        Item { Layout.fillWidth: true }
        RowLayout {
          spacing: 6
          Spinner { visible: btScanning; running: btScanning; size: 14; color: Theme.primary }
          Text {
            id: btScanLbl
            text: btScanning ? "Scanning…" : "Scan"
            color: Theme.primary
            font.family: "Inter"
            font.pixelSize: 11
            font.weight: 600

            SequentialAnimation on opacity {
              running: btScanning
              loops: Animation.Infinite
              NumberAnimation { from: 1; to: 0.4; duration: 700; easing.type: Easing.InOutSine }
              NumberAnimation { from: 0.4; to: 1; duration: 700; easing.type: Easing.InOutSine }
            }
            onOpacityChanged: if (!btScanning) opacity = 1

            MouseArea {
              anchors.fill: parent
              anchors.margins: -6
              cursorShape: Qt.PointingHandCursor
              onClicked: if (_on && !btScanning) toggleBtScan()
            }
          }
        }
      }

      Repeater {
        model: _paired

        Rectangle {
          id: btCard
          required property var modelData
          Layout.fillWidth: true
          Layout.preferredHeight: 56
          radius: 14
          color: (modelData.state === BluetoothDeviceState.Connected || modelData.pairing)
            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
            : (btMouse.containsMouse ? Theme.surfaceHover : Theme.surface)
          border.color: modelData.state === BluetoothDeviceState.Connected ? Theme.primary : "transparent"
          border.width: modelData.state === BluetoothDeviceState.Connected ? 1.5 : 0
          Behavior on color { ColorAnimation { duration: Motion.durXS } }

          RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Rectangle {
              width: 34; height: 34; radius: 10
              color: modelData.state === BluetoothDeviceState.Connected
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                : Theme.surfaceLight
              Text {
                anchors.centerIn: parent
                text: modelData.pairing ? "󰄉"
                  : (modelData.state === BluetoothDeviceState.Connected ? "󰂱" : "󰂯")
                color: modelData.state === BluetoothDeviceState.Connected ? Theme.primary : Theme.text
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
              }
            }
            ColumnLayout {
              spacing: 1
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
                  color: modelData.state === BluetoothDeviceState.Connected ? Theme.primary : Theme.subtext
                  opacity: modelData.state === BluetoothDeviceState.Connected ? 1 : 0.7
                  font.family: "Inter"
                  font.pixelSize: 10
                }
              }
            }

            Item {
              visible: modelData.batteryAvailable
              implicitWidth: 26
              implicitHeight: 26
              ArcGauge {
                anchors.fill: parent
                value: modelData.battery
                thickness: 3
                fromDeg: -90
                sweepDeg: 360
                color: modelData.battery < 0.2 ? Theme.error : (modelData.battery < 0.5 ? Theme.warning : Theme.primary)
                centerText: Math.round(modelData.battery * 100) + ""
                centerSize: 9
                centerColor: Theme.subtext
              }
            }

            Spinner {
              visible: modelData.state === BluetoothDeviceState.Connecting || modelData.pairing
              running: modelData.state === BluetoothDeviceState.Connecting || modelData.pairing
              size: 16
              color: Theme.primary
            }
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
            Text {
              visible: !modelData.pairing
                && modelData.state !== BluetoothDeviceState.Connecting
              text: "Forget"
              color: Theme.error
              opacity: 0.85
              font.family: "Inter"
              font.pixelSize: 11
              font.weight: 600

              MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: forgetDevice(modelData)
              }
            }
          }
          MouseArea {
            id: btMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (modelData.pairing || modelData.state === BluetoothDeviceState.Connecting) return;
              if (modelData.paired) toggleBtConnection(modelData);
            }
          }
        }
      }

      Text {
        visible: _paired.length === 0 && !btScanning
        text: "No paired devices"
        color: Theme.text
        opacity: 0.4
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 4
        font.family: "Inter"
        font.pixelSize: 12
      }
    }

    // ============ AVAILABLE ============
    ColumnLayout {
      visible: _on
      Layout.fillWidth: true
      spacing: 8
      opacity: 0
      SequentialAnimation on opacity {
  PauseAnimation { duration: 120 }
  NumberAnimation { from: 0; to: 1; duration: Motion.durM; easing.type: Motion.easeStandard; objectName: "entrance" }
}

      Text { text: "Available"; color: Theme.muted; font.family: "Inter"; font.pixelSize: 11; font.weight: 700; leftPadding: 4 }

      Repeater {
        model: _available

        Rectangle {
          id: avCard
          required property var modelData
          Layout.fillWidth: true
          Layout.preferredHeight: 52
          radius: 14
          color: avMouse.containsMouse ? Theme.surfaceHover : Theme.surface
          Behavior on color { ColorAnimation { duration: Motion.durXS } }

          RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Rectangle {
              width: 34; height: 34; radius: 10
              color: Theme.surfaceLight
              Text {
                anchors.centerIn: parent
                text: "󰂯"
                color: Theme.text
                opacity: 0.7
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
              }
            }
            ColumnLayout {
              spacing: 1
              Layout.fillWidth: true

              Text {
                text: avCard.modelData.name || avCard.modelData.deviceName || "Unknown device"
                color: Theme.text
                elide: Text.ElideRight
                Layout.fillWidth: true
                font.family: "Inter"
                font.pixelSize: 13
                font.weight: 600
              }
              Text {
                text: btDeviceSubtitle(avCard.modelData)
                color: Theme.subtext
                opacity: 0.7
                font.family: "Inter"
                font.pixelSize: 10
              }
            }
            Spinner {
              visible: modelData.pairing
              running: modelData.pairing
              size: 16
              color: Theme.primary
            }
            Text {
              visible: !modelData.pairing
              text: "Pair"
              color: Theme.primary
              font.family: "Inter"
              font.pixelSize: 11
              font.weight: 600

              MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: pairDevice(modelData)
              }
            }
          }
          MouseArea {
            id: avMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { if (!modelData.pairing) pairDevice(modelData); }
          }
        }
      }

      Text {
        visible: _available.length === 0 && !btScanning
        text: "Tap Scan to find nearby devices"
        color: Theme.text
        opacity: 0.4
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 4
        font.family: "Inter"
        font.pixelSize: 12
      }
      ColumnLayout {
        visible: btScanning && _available.length === 0
        Layout.fillWidth: true
        spacing: 8

        Repeater {
          model: 3
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            radius: 14
            color: Theme.surface

            SequentialAnimation on opacity {
              running: true
              loops: Animation.Infinite
              NumberAnimation { from: 1; to: 0.4; duration: 800; easing.type: Easing.InOutSine }
              NumberAnimation { from: 0.4; to: 1; duration: 800; easing.type: Easing.InOutSine }
            }
          }
        }
      }
    }

    Text {
      visible: !_on
      text: "Turn on Bluetooth to see devices"
      color: Theme.text
      opacity: 0.4
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: 16
      font.family: "Inter"
      font.pixelSize: 12
    }

    Item { Layout.preferredHeight: 4 }
  }
}
