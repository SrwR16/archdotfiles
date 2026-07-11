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

  property bool wifiEnabled: false
  property string wifiName: ""
  property string wifiSecurity: ""
  property var wifiNetworks: []
  property bool wifiScanning: false
  property bool wifiConnecting: false
  property string wifiQrPath: ""
  property string wifiCurrentPassword: ""
  property bool wifiPasswordRevealed: false
  property string wifiPendingSsid: ""
  property string wifiPendingSecurity: ""
  property string wifiConnectError: ""
  property bool _pwReveal: false

  signal toggleWifi()
  signal scanWifi()
  signal connectToWifi(string ssid, string security, string password)
  signal loadCurrentWifiPassword()
  signal backRequested()
  signal disconnectWifi()
  signal generateWifiQr()
  signal showQrCode(string path)
  signal requestPassword(string ssid)
  signal cancelPassword()

  function doWifiConnect() {
    connectToWifi(wifiPendingSsid, wifiPendingSecurity, wifiPwField.text)
  }

  ColumnLayout {
    width: parent.width
    spacing: 10

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 52
      radius: 14
      color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.85)

      RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        Text { text: "Wi-Fi"; color: Theme.text; font { family: "Inter"; pixelSize: 14; weight: 700 } }
        Item { Layout.fillWidth: true }
        Rectangle {
          width: 46; height: 26; radius: 13
          color: wifiEnabled ? Theme.primary : Theme.border
          Rectangle {
            width: 20; height: 20; radius: 10; color: Theme.backgroundFg
            anchors.verticalCenter: parent.verticalCenter
            x: wifiEnabled ? parent.width - width - 3 : 3
            Behavior on x { NumberAnimation { duration: 120 } }
          }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: toggleWifi() }
        }
      }
    }

    Rectangle {
      Layout.fillWidth: true
      visible: wifiEnabled && wifiName !== "No network" && wifiName !== "Off"
      Layout.preferredHeight: connectedCol.implicitHeight + 28
      radius: 16
      color: Theme.container
      border.color: Theme.primary
      border.width: 1

      ColumnLayout {
        id: connectedCol
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        RowLayout {
          Layout.fillWidth: true
          Text { text: ""; color: Theme.primary; font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 } }
          ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            Text { text: wifiName; color: Theme.text; font { family: "Inter"; pixelSize: 14; weight: 700 } }
            Text { text: "Connected"; color: Theme.primary; font { family: "Inter"; pixelSize: 11 } }
          }
          Item { Layout.fillWidth: true }
          Text {
            text: "Disconnect"
            color: Theme.text; opacity: 0.7
            font { family: "Inter"; pixelSize: 11; weight: 600 }
            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: disconnectWifi() }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          visible: wifiCurrentPassword.length > 0
          spacing: 8

          Text { text: "Password:"; color: Theme.text; opacity: 0.7; font { family: "Inter"; pixelSize: 12 } }
          Text {
            text: wifiPasswordRevealed ? wifiCurrentPassword : "•".repeat(Math.max(6, wifiCurrentPassword.length))
            color: Theme.text
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
            Layout.fillWidth: true
          }
          Text {
            text: wifiPasswordRevealed ? "󰋭" : "󰋬"
            color: Theme.text
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
            MouseArea {
              anchors.fill: parent; anchors.margins: -8
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                wifiPasswordRevealed = !wifiPasswordRevealed;
                if (wifiPasswordRevealed && !wifiQrPath) generateWifiQr();
              }
            }
          }
        }

        Image {
          visible: wifiPasswordRevealed && wifiQrPath.length > 0
          source: wifiQrPath
          Layout.preferredWidth: 140
          Layout.preferredHeight: 140
          Layout.alignment: Qt.AlignHCenter
          fillMode: Image.PreserveAspectFit
          smooth: false
        }

        Text {
          visible: wifiPasswordRevealed && wifiCurrentPassword.length === 0
          text: "No saved password found for this network."
          color: Theme.text; opacity: 0.5
          font { family: "Inter"; pixelSize: 11 }
        }
      }
    }

    // ---- Inline password entry (replaces floating dialog) ----
    Rectangle {
      Layout.fillWidth: true
      Layout.topMargin: 6
      visible: wifiPendingSsid !== ""
      radius: 16
      color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.92)
      border.color: Theme.primary
      border.width: 1
      clip: true
      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10
        Text {
          text: "Connect to " + wifiPendingSsid
          color: Theme.text
          font { family: "Inter"; pixelSize: 13; weight: 700 }
          Layout.fillWidth: true
          elide: Text.ElideRight
        }
        Rectangle {
          Layout.fillWidth: true
          height: 42
          radius: 10
          color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.8)
          border.color: Theme.border
          border.width: 1
          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10; anchors.rightMargin: 6
            spacing: 6
            TextField {
              id: wifiPwField
              Layout.fillWidth: true
              color: Theme.text
              echoMode: _pwReveal ? TextInput.Normal : TextInput.Password
              placeholderText: "Password"
              placeholderTextColor: Theme.subtext
              background: null
              font { family: "Inter"; pixelSize: 13 }
              focus: wifiPendingSsid !== ""
              onAccepted: doWifiConnect()
            }
            Rectangle {
              width: 30; height: 30; radius: 8
              color: pwRevealBtn.containsMouse ? Theme.surfaceLight : "transparent"
              Text { anchors.centerIn: parent; text: _pwReveal ? "󰋭" : "󰋬"; color: Theme.text; font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 } }
              MouseArea {
                id: pwRevealBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: _pwReveal = !_pwReveal
              }
            }
          }
        }
        Text {
          visible: wifiConnectError !== ""
          text: wifiConnectError
          color: "#f38ba8"
          font { family: "Inter"; pixelSize: 11 }
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
        }
        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          Item { Layout.fillWidth: true }
          Rectangle {
            Layout.preferredWidth: 90; Layout.preferredHeight: 38; radius: 12
            color: cancelWifiBtn.containsMouse ? Theme.surfaceLight : Theme.surface
            Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.text; font { family: "Inter"; pixelSize: 12; weight: 600 } }
            MouseArea { id: cancelWifiBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cancelPassword() }
          }
          Rectangle {
            id: connectBtn
            Layout.preferredWidth: 110; Layout.preferredHeight: 38; radius: 12
            color: connectWifiBtn.containsMouse ? Theme.primary : Qt.darker(Theme.primary, 1.1)
            enabled: !wifiConnecting
            Text { anchors.centerIn: parent; text: wifiConnecting ? "Connecting…" : "Connect"; color: Theme.backgroundFg; font { family: "Inter"; pixelSize: 12; weight: 700 } }
            MouseArea { id: connectWifiBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: doWifiConnect() }
          }
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      Layout.topMargin: 4
      Text { text: "Networks"; color: Theme.text; opacity: 0.7; font { family: "Inter"; pixelSize: 12; weight: 700 } }
      Item { Layout.fillWidth: true }
      Text {
        text: wifiScanning ? "Scanning…" : "Refresh"
        color: Theme.primary
        font { family: "Inter"; pixelSize: 11; weight: 600 }
        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: scanWifi() }
      }
    }

    Repeater {
      model: wifiNetworks

      delegate: Rectangle {
        required property var modelData
        Layout.fillWidth: true
        Layout.preferredHeight: 52
        radius: 14
        color: modelData.active ? Theme.surfaceLight : Theme.surface

        RowLayout {
          anchors.fill: parent
          anchors.margins: 14
          spacing: 10

          Text {
            text: modelData.signal > 66 ? "󰤨" : modelData.signal > 33 ? "󰤢" : "󰤟"
            color: Theme.text
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 15 }
          }

          ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            Text { text: modelData.ssid; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; font { family: "Inter"; pixelSize: 13; weight: 600 } }
            Text {
              text: modelData.active ? "Connected" : (modelData.security && modelData.security !== "--" ? "Secured" : "Open")
              color: modelData.active ? Theme.primary : Theme.text
              opacity: modelData.active ? 1 : 0.6
              font { family: "Inter"; pixelSize: 10 }
            }
          }

          Text {
            visible: modelData.security && modelData.security !== "--"
            text: "󰲛"
            color: Theme.text; opacity: 0.5
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (modelData.active) return;
            if (modelData.security && modelData.security !== "--") {
              connectToWifi(modelData.ssid, modelData.security, "");
            } else {
              connectToWifi(modelData.ssid, modelData.security || "", "");
            }
          }
        }
      }
    }

    Text {
      visible: wifiNetworks.length === 0 && !wifiScanning
      text: "No networks found"
      color: Theme.text; opacity: 0.4
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: 12
      font { family: "Inter"; pixelSize: 12 }
    }

    Item { Layout.preferredHeight: 4 }
  }
}
