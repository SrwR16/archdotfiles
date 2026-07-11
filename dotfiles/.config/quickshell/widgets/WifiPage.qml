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

  // ---- State mirrored from ControlCenter ----
  property bool wifiEnabled: false
  property string wifiName: ""
  property string wifiSecurity: ""
  property string wifiIp: ""
  property string wifiSpeed: ""
  property var wifiNetworks: []
  property bool wifiScanning: false
  property string wifiConnectingSsid: ""
  property string wifiPendingSsid: ""
  property string wifiPendingSecurity: ""
  property string wifiConnectError: ""
  property string wifiCurrentPassword: ""
  property bool wifiPasswordRevealed: false
  property string wifiQrPath: ""

  signal toggleWifi()
  signal scanWifi()
  signal connectToWifi(string ssid, string security, string password)
  signal connectHidden(string ssid, string password)
  signal requestPassword(string ssid, string security)
  signal cancelPassword()
  signal disconnectWifi()
  signal forgetWifi(string ssid)
  signal loadCurrentWifiPassword()
  signal generateWifiQr()
  signal backRequested()

  // ---- Local UI state ----
  property bool _pwReveal: false
  property bool _hiddenMode: false
  property string _hiddenSsid: ""
  property bool _revealPw: false

  readonly property bool _connected: wifiName.length > 0
    && wifiName !== "Off" && wifiName !== "No network" && wifiName !== "Disconnected"

  function _activeNetwork() {
    for (var i = 0; i < wifiNetworks.length; i++)
      if (wifiNetworks[i].active) return wifiNetworks[i];
    return null;
  }
  readonly property int _connectedSignal: {
    var a = _activeNetwork();
    return a ? a.signal : 80;
  }
  readonly property bool _pendingKnown: {
    for (var i = 0; i < wifiNetworks.length; i++)
      if (wifiNetworks[i].ssid === wifiPendingSsid && wifiNetworks[i].known) return true;
    return false;
  }
  function _isSecured(sec) { return sec && sec.length > 0 && sec !== "--"; }

  function _doConnect() {
    if (_hiddenMode) connectHidden(_hiddenSsid.trim(), wifiPwField.text);
    else connectToWifi(wifiPendingSsid, wifiPendingSecurity, wifiPwField.text);
  }

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
          text: "Wi-Fi"
          color: Theme.text
          font.family: "Inter"
          font.pixelSize: 14
          font.weight: 700
        }
        Item { Layout.fillWidth: true }
        Text {
          text: wifiEnabled ? "On" : "Off"
          color: wifiEnabled ? Theme.primary : Theme.subtext
          font.family: "Inter"
          font.pixelSize: 11
          font.weight: 600
          opacity: 0.8
        }
        Rectangle {
          width: 46
          height: 26
          radius: 13
          color: wifiEnabled ? Theme.primary : Theme.border
          Behavior on color { ColorAnimation { duration: Motion.durXS } }

          Rectangle {
            width: 20
            height: 20
            radius: 10
            color: Theme.backgroundFg
            anchors.verticalCenter: parent.verticalCenter
            x: wifiEnabled ? parent.width - width - 3 : 3
            Behavior on x { NumberAnimation { duration: Motion.durS; easing.type: Motion.easeStandard } }
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleWifi()
          }
        }
      }
    }

    // ============ CONNECTED HERO ============
    Rectangle {
      Layout.fillWidth: true
      visible: _connected && wifiEnabled
      Layout.preferredHeight: heroCol.implicitHeight + 28
      radius: 16
      color: Theme.container
      border.color: Theme.primary
      border.width: 1
      opacity: visible ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: Motion.durM; easing.type: Motion.easeStandard } }

      ColumnLayout {
        id: heroCol
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        RowLayout {
          Layout.fillWidth: true
          spacing: 12

          SignalBars {
            signal: _connectedSignal
            barColor: Theme.primary
            implicitHeight: 22
          }
          ColumnLayout {
            spacing: 0
            Layout.fillWidth: true

            Text {
              text: wifiName
              color: Theme.text
              font.family: "Inter"
              font.pixelSize: 14
              font.weight: 700
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
            Text {
              text: "Connected" + (wifiSpeed ? "  ·  " + wifiSpeed : "")
              color: Theme.primary
              font.family: "Inter"
              font.pixelSize: 11
              opacity: 0.9
            }
          }
          Item { Layout.fillWidth: true }
          Rectangle {
            Layout.preferredWidth: 78
            Layout.preferredHeight: 26
            radius: 13
            color: Theme.surfaceLight

            Text {
              anchors.centerIn: parent
              text: "Disconnect"
              color: Theme.text
              opacity: 0.8
              font.family: "Inter"
              font.pixelSize: 11
              font.weight: 600
            }
            MouseArea {
              anchors.fill: parent
              anchors.margins: -6
              cursorShape: Qt.PointingHandCursor
              onClicked: disconnectWifi()
            }
          }
        }

        Text {
          visible: wifiIp.length > 0
          text: "IP " + wifiIp
          color: Theme.subtext
          font.family: "JetBrains Mono"
          font.pixelSize: 11
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Text {
            text: "Password:"
            color: Theme.text
            opacity: 0.7
            font.family: "Inter"
            font.pixelSize: 12
          }
          Text {
            Layout.fillWidth: true
            text: _revealPw ? (wifiCurrentPassword.length ? wifiCurrentPassword : "—") : "•".repeat(Math.max(6, wifiCurrentPassword.length))
            color: Theme.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            elide: Text.ElideRight
          }
          Rectangle {
            width: 30
            height: 30
            radius: 8
            color: pwRevealBtn.containsMouse ? Theme.surfaceHover : "transparent"
            Behavior on color { ColorAnimation { duration: Motion.durXS } }

            Text {
              anchors.centerIn: parent
              text: _revealPw ? "󰋭" : "󰋬"
              color: Theme.text
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 13
            }
            MouseArea {
              id: pwRevealBtn
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                _revealPw = !_revealPw;
                if (_revealPw) loadCurrentWifiPassword();
                else generateWifiQr();
              }
            }
          }
        }

        Image {
          visible: _revealPw && wifiQrPath.length > 0
          source: wifiQrPath
          Layout.preferredWidth: 132
          Layout.preferredHeight: 132
          Layout.alignment: Qt.AlignHCenter
          fillMode: Image.PreserveAspectFit
          smooth: false
          opacity: visible ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: Motion.durM } }
        }
      }
    }

    // ============ PASSWORD SHEET ============
    Rectangle {
      id: pwSheet
      Layout.fillWidth: true
      Layout.topMargin: 6
      visible: wifiPendingSsid !== "" || _hiddenMode
      Layout.preferredHeight: pwCol.implicitHeight + 28
      radius: 16
      color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.92)
      border.color: Theme.primary
      border.width: 1
      opacity: visible ? 1 : 0
      y: visible ? 0 : -10
      Behavior on opacity { NumberAnimation { duration: Motion.durS; easing.type: Motion.easeStandard } }
      Behavior on y { NumberAnimation { duration: Motion.durS; easing.type: Motion.easeStandard } }

      ColumnLayout {
        id: pwCol
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        Text {
          text: _hiddenMode ? "Connect to hidden network" : ("Connect to " + wifiPendingSsid)
          color: Theme.text
          font.family: "Inter"
          font.pixelSize: 13
          font.weight: 700
          Layout.fillWidth: true
          elide: Text.ElideRight
        }

        Rectangle {
          visible: _hiddenMode
          Layout.fillWidth: true
          height: 42
          radius: 10
          color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.8)
          border.color: Theme.border
          border.width: 1

          TextField {
            id: hiddenField
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.text
            font.family: "Inter"
            font.pixelSize: 13
            placeholderText: "Network name (SSID)"
            placeholderTextColor: Theme.subtext
            background: null
            text: _hiddenSsid
            onTextChanged: _hiddenSsid = text
          }
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
            anchors.leftMargin: 10
            anchors.rightMargin: 6
            spacing: 6

            TextField {
              id: wifiPwField
              Layout.fillWidth: true
              color: Theme.text
              echoMode: _pwReveal ? TextInput.Normal : TextInput.Password
              placeholderText: "Password"
              placeholderTextColor: Theme.subtext
              background: null
              font.family: "Inter"
              font.pixelSize: 13
              focus: pwSheet.visible
              onAccepted: _doConnect()
            }
            Rectangle {
              width: 30
              height: 30
              radius: 8
              color: pwRevealBtn2.containsMouse ? Theme.surfaceHover : "transparent"

              Text {
                anchors.centerIn: parent
                text: _pwReveal ? "󰋭" : "󰋬"
                color: Theme.text
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
              }
              MouseArea {
                id: pwRevealBtn2
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: _pwReveal = !_pwReveal
              }
            }
          }
        }

        Text {
          visible: wifiConnectError.length > 0
          text: wifiConnectError
          color: Theme.error
          font.family: "Inter"
          font.pixelSize: 11
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Text {
            visible: !_hiddenMode && _pendingKnown
            text: "Forget"
            color: Theme.error
            opacity: 0.85
            font.family: "Inter"
            font.pixelSize: 11
            font.weight: 600

            MouseArea {
              anchors.fill: parent
              anchors.margins: -6
              cursorShape: Qt.PointingHandCursor
              onClicked: { forgetWifi(wifiPendingSsid); _hiddenMode = false; }
            }
          }
          Item { Layout.fillWidth: true }
          Rectangle {
            Layout.preferredWidth: 90
            Layout.preferredHeight: 38
            radius: 12
            color: cancelBtn2.containsMouse ? Theme.surfaceHover : Theme.surface

            Text {
              anchors.centerIn: parent
              text: "Cancel"
              color: Theme.text
              font.family: "Inter"
              font.pixelSize: 12
              font.weight: 600
            }
            MouseArea {
              id: cancelBtn2
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: { cancelPassword(); _hiddenMode = false; _hiddenSsid = ""; }
            }
          }
          Rectangle {
            Layout.preferredWidth: 110
            Layout.preferredHeight: 38
            radius: 12
            color: connectBtn2.containsMouse ? Theme.primary : Qt.darker(Theme.primary, 1.1)
            Behavior on color { ColorAnimation { duration: Motion.durXS } }

            Text {
              anchors.centerIn: parent
              text: "Connect"
              color: Theme.backgroundFg
              font.family: "Inter"
              font.pixelSize: 12
              font.weight: 700
            }
            MouseArea {
              id: connectBtn2
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: _doConnect()
            }
          }
        }
      }
    }

    // ============ NETWORKS HEADER ============
    RowLayout {
      Layout.fillWidth: true
      Layout.topMargin: 4

      Text {
        text: "Networks"
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
          visible: wifiScanning
          running: wifiScanning
          size: 14
          color: Theme.primary
        }
        Text {
          text: wifiScanning ? "Scanning…" : "Refresh"
          color: Theme.primary
          font.family: "Inter"
          font.pixelSize: 11
          font.weight: 600

          MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: scanWifi()
          }
        }
      }
    }

    // ============ NETWORK LIST ============
    Repeater {
      model: wifiEnabled ? wifiNetworks : []

      delegate: Rectangle {
        required property var modelData
        Layout.fillWidth: true
        Layout.preferredHeight: 52
        radius: 14
        color: (modelData.active || modelData.ssid === wifiConnectingSsid)
          ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
          : Theme.surface
        border.color: modelData.active ? Theme.primary : "transparent"
        border.width: modelData.active ? 1.5 : 0
        Behavior on color { ColorAnimation { duration: Motion.durXS } }

        RowLayout {
          anchors.fill: parent
          anchors.margins: 14
          spacing: 12

          SignalBars {
            signal: modelData.signal
            barColor: modelData.active ? Theme.primary : Theme.text
            implicitHeight: 18
          }

          ColumnLayout {
            spacing: 0
            Layout.fillWidth: true

            Text {
              text: modelData.ssid
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
                text: modelData.active ? "Connected" : (_isSecured(modelData.security) ? "Secured" : "Open")
                color: modelData.active ? Theme.primary : Theme.text
                opacity: modelData.active ? 1 : 0.6
                font.family: "Inter"
                font.pixelSize: 10
              }
              Text {
                visible: modelData.known && !modelData.active
                text: "· Saved"
                color: Theme.subtext
                font.family: "Inter"
                font.pixelSize: 10
              }
            }
          }

          Spinner {
            visible: modelData.ssid === wifiConnectingSsid
            running: modelData.ssid === wifiConnectingSsid
            size: 16
            color: Theme.primary
          }

          Text {
            visible: modelData.active
            text: "󰄬"
            color: Theme.primary
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
          }

          Text {
            visible: _isSecured(modelData.security) && !modelData.active
            text: "󰲛"
            color: Theme.text
            opacity: 0.5
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (modelData.active) return;
            connectToWifi(modelData.ssid, modelData.security, "");
          }
        }
      }
    }

    // Empty / offline states
    Text {
      visible: wifiEnabled && wifiNetworks.length === 0 && !wifiScanning
      text: "No networks found"
      color: Theme.text
      opacity: 0.4
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: 12
      font.family: "Inter"
      font.pixelSize: 12
    }
    Text {
      visible: !wifiEnabled
      text: "Wi-Fi is off"
      color: Theme.text
      opacity: 0.4
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: 12
      font.family: "Inter"
      font.pixelSize: 12
    }

    // Hidden network entry
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 44
      radius: 14
      color: "transparent"
      border.color: Theme.outline
      border.width: 1
      visible: wifiEnabled && !_hiddenMode

      Text {
        anchors.centerIn: parent
        text: "Connect to hidden network"
        color: Theme.subtext
        font.family: "Inter"
        font.pixelSize: 12
        font.weight: 600
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: { _hiddenMode = true; _hiddenSsid = ""; }
      }
    }

    Item { Layout.preferredHeight: 4 }
  }
}
