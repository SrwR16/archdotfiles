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

  property bool _pwReveal: false
  property bool _hiddenMode: false
  property string _hiddenSsid: ""
  property bool _revealPw: false
  property string _search: ""

  readonly property bool _connected: wifiName.length > 0
    && wifiName !== "Off" && wifiName !== "No network" && wifiName !== "Disconnected"

  function _activeNetwork() {
    for (var i = 0; i < wifiNetworks.length; i++)
      if (wifiNetworks[i].active) return wifiNetworks[i];
    return null;
  }
  readonly property var _active: _activeNetwork()
  readonly property int _connectedSignal: _active ? _active.signal : 80

  readonly property var _available: {
    var q = _search.toLowerCase().trim();
    return wifiNetworks.filter(function (n) {
      if (n.active) return false;
      if (q.length && n.ssid.toLowerCase().indexOf(q) === -1) return false;
      return true;
    });
  }
  readonly property bool _pendingKnown: {
    for (var i = 0; i < wifiNetworks.length; i++)
      if (wifiNetworks[i].ssid === wifiPendingSsid && wifiNetworks[i].known) return true;
    return false;
  }
  function _isSecured(sec) { return sec && sec.length > 0 && sec !== "--"; }
  function _doConnect() {
    if (_hiddenMode) connectHidden(_hiddenSsid.trim(), wifiPwField.text);
    else connectToWifi(wifiPendingSsid || "", wifiPendingSecurity, wifiPwField.text);
  }

  ColumnLayout {
    width: parent.width
    spacing: 10

    // ============ ENABLE ============
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 48
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
          color: wifiEnabled ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18) : Theme.surfaceLight
          Text {
            anchors.centerIn: parent
            text: "󰤯"
            color: wifiEnabled ? Theme.primary : Theme.subtext
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
          }
        }
        Text {
          text: wifiEnabled ? "Wi-Fi is on" : "Wi-Fi is off"
          color: wifiEnabled ? Theme.primary : Theme.subtext
          font.family: "Inter"
          font.pixelSize: 12
          font.weight: 600
        }
        Item { Layout.fillWidth: true }
        Rectangle {
          width: 44; height: 25; radius: 12
          color: wifiEnabled ? Theme.primary : Theme.border
          Behavior on color { ColorAnimation { duration: Motion.durXS } }

          Rectangle {
            width: 19; height: 19; radius: 9
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

    // ============ OFF ============
    Rectangle {
      visible: !wifiEnabled
      Layout.fillWidth: true
      Layout.preferredHeight: 160
      radius: 16
      color: Theme.surface

      ColumnLayout {
        anchors.centerIn: parent
        spacing: 10

        Text { text: "󰤮"; color: Theme.subtext; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 34 }
        Text { text: "Wi-Fi is off"; color: Theme.text; opacity: 0.5; font.family: "Inter"; font.pixelSize: 12 }
        QsButton {
          text: "Turn on"
          onClicked: toggleWifi()
        }
      }
    }

    // ============ CONNECTED HERO ============
    Item {
      visible: _connected && wifiEnabled
      Layout.fillWidth: true
      Layout.preferredHeight: heroCol.implicitHeight + 24

      Rectangle {
        anchors.fill: parent
        radius: 18
        color: Theme.container
        border.color: Theme.primary
        border.width: 1
      }
      // accent strip
      Rectangle {
        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
        width: 3
        radius: 18
        color: Theme.primary
      }
      ColumnLayout {
        id: heroCol
        anchors.fill: parent
        anchors.margins: 16
        anchors.leftMargin: 22
        spacing: 12

        RowLayout {
          Layout.fillWidth: true
          spacing: 14

          RowLayout {
            spacing: 8
            SignalBars { signal: _connectedSignal; barColor: Theme.primary; implicitHeight: 28 }
            Text {
              text: Math.round(_connectedSignal) + "%"
              color: Theme.primary
              font.family: "Inter"
              font.pixelSize: 13
              font.weight: 700
            }
          }
          ColumnLayout {
            spacing: 2
            Layout.fillWidth: true

            Text {
              text: wifiName
              color: Theme.text
              font.family: "Inter"
              font.pixelSize: 15
              font.weight: 700
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
            RowLayout {
              spacing: 6
              Text { text: "Connected"; color: Theme.primary; font.family: "Inter"; font.pixelSize: 11; font.weight: 600 }
              Text {
                visible: wifiSpeed.length > 0
                text: "· " + wifiSpeed
                color: Theme.primary; opacity: 0.85
                font.family: "Inter"; font.pixelSize: 11
              }
              Text {
                visible: _isSecured(wifiSecurity)
                text: "· Secured"
                color: Theme.subtext
                font.family: "Inter"; font.pixelSize: 11
              }
            }
          }
          QsButton {
            text: "Disconnect"
            danger: true
            onClicked: disconnectWifi()
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.outline; opacity: 0.5 }

        GridLayout {
          Layout.fillWidth: true
          columns: 2
          rowSpacing: 12
          columnSpacing: 14

          ColumnLayout {
            spacing: 3
            Layout.fillWidth: true
            Text { text: "IP address"; color: Theme.subtext; font.family: "Inter"; font.pixelSize: 10 }
            Text {
              text: wifiIp.length ? wifiIp : "—"
              color: Theme.text; font.family: "JetBrains Mono"; font.pixelSize: 12
              elide: Text.ElideRight; Layout.fillWidth: true
            }
          }
          ColumnLayout {
            spacing: 3
            Layout.fillWidth: true
            Text { text: "Band"; color: Theme.subtext; font.family: "Inter"; font.pixelSize: 10 }
            Text {
              text: _active && _active.band ? _active.band : "—"
              color: Theme.text; font.family: "JetBrains Mono"; font.pixelSize: 12
              elide: Text.ElideRight; Layout.fillWidth: true
            }
          }
          ColumnLayout {
            spacing: 3
            Layout.fillWidth: true

            Text { text: "Password"; color: Theme.subtext; font.family: "Inter"; font.pixelSize: 10 }
            RowLayout {
              spacing: 6
              Layout.fillWidth: true
              Text {
                Layout.fillWidth: true
                text: _revealPw ? (wifiCurrentPassword.length ? wifiCurrentPassword : "—") : "•".repeat(Math.max(6, wifiCurrentPassword.length))
                color: Theme.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                elide: Text.ElideRight
              }
              Text {
                text: _revealPw ? "󰋭" : "󰋬"
                color: Theme.text; opacity: 0.7
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13

                MouseArea {
                  anchors.fill: parent; anchors.margins: -6
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    _revealPw = !_revealPw;
                    if (_revealPw) loadCurrentWifiPassword();
                    else generateWifiQr();
                  }
                }
              }
            }
          }
          ColumnLayout {
            spacing: 3
            Layout.fillWidth: true
            Text { text: "MAC"; color: Theme.subtext; font.family: "Inter"; font.pixelSize: 10 }
            Text {
              text: _active && _active.mac ? _active.mac : "—"
              color: Theme.text; font.family: "JetBrains Mono"; font.pixelSize: 12
              elide: Text.ElideRight; Layout.fillWidth: true
            }
          }
        }

        Image {
          visible: _revealPw && wifiQrPath.length > 0
          source: wifiQrPath
          Layout.preferredWidth: 120
          Layout.preferredHeight: 120
          Layout.alignment: Qt.AlignHCenter
          fillMode: Image.PreserveAspectFit
          smooth: false
        }
      }
    }

    // ============ PASSWORD SHEET ============
    Item {
      id: pwSheet
      visible: (wifiPendingSsid || "") !== "" || _hiddenMode
      onVisibleChanged: if (visible) wifiPwField.forceActiveFocus()
      Layout.fillWidth: true
      Layout.preferredHeight: pwCol.implicitHeight + 24

      Rectangle {
        anchors.fill: parent
        radius: 18
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.92)
        border.color: Theme.primary
        border.width: 1
      }
      ColumnLayout {
        id: pwCol
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        Text {
          text: _hiddenMode ? "Connect to hidden network" : ("Connect to " + (wifiPendingSsid || ""))
          color: Theme.text; font.family: "Inter"; font.pixelSize: 13; font.weight: 700
          Layout.fillWidth: true; elide: Text.ElideRight
        }
        Rectangle {
          visible: _hiddenMode
          Layout.fillWidth: true; height: 42; radius: 10
          color: Theme.surface; border.color: Theme.border; border.width: 1

          TextField {
            id: hiddenField
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.text; font.family: "Inter"; font.pixelSize: 13
            placeholderText: "Network name (SSID)"; placeholderTextColor: Theme.subtext
            background: null; text: _hiddenSsid
            onTextChanged: _hiddenSsid = text
          }
        }
        Rectangle {
          Layout.fillWidth: true; height: 42; radius: 10
          color: Theme.surface; border.color: Theme.border; border.width: 1

          RowLayout {
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 6; spacing: 6
            TextField {
              id: wifiPwField
              Layout.fillWidth: true
              color: Theme.text
              echoMode: _pwReveal ? TextInput.Normal : TextInput.Password
              placeholderText: "Password"; placeholderTextColor: Theme.subtext
              background: null; font.family: "Inter"; font.pixelSize: 13
              onAccepted: _doConnect()
            }
            Text {
              text: _pwReveal ? "󰋭" : "󰋬"
              color: Theme.text; opacity: 0.7
              font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13

              MouseArea {
                anchors.fill: parent; anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: _pwReveal = !_pwReveal
              }
            }
          }
        }
        Text {
          visible: wifiConnectError.length > 0
          text: wifiConnectError
          color: Theme.error; font.family: "Inter"; font.pixelSize: 11
          Layout.fillWidth: true; wrapMode: Text.WordWrap
        }
        RowLayout {
          Layout.fillWidth: true; spacing: 8
          Text {
            visible: !_hiddenMode && _pendingKnown
            text: "Forget"; color: Theme.error; opacity: 0.85
            font.family: "Inter"; font.pixelSize: 11; font.weight: 600

            MouseArea {
              anchors.fill: parent; anchors.margins: -6
              cursorShape: Qt.PointingHandCursor
              onClicked: { forgetWifi(wifiPendingSsid || ""); _hiddenMode = false; }
            }
          }
          Item { Layout.fillWidth: true }
          QsButton {
            text: "Cancel"
            outline: true
            onClicked: { cancelPassword(); _hiddenMode = false; _hiddenSsid = ""; }
          }
          QsButton {
            text: "Connect"
            onClicked: _doConnect()
          }
        }
      }
    }

    // ============ NETWORKS ============
    ColumnLayout {
      visible: wifiEnabled
      Layout.fillWidth: true
      spacing: 10
      opacity: 0
      SequentialAnimation on opacity {
        PauseAnimation { duration: 120 }
        NumberAnimation { from: 0; to: 1; duration: Motion.durM; easing.type: Motion.easeStandard; objectName: "entrance" }
      }

      RowLayout {
        Layout.fillWidth: true; spacing: 8
        Text { text: "Networks"; color: Theme.muted; font.family: "Inter"; font.pixelSize: 11; font.weight: 700; leftPadding: 4 }
        Item { Layout.fillWidth: true }
        RowLayout {
          spacing: 6
          Spinner { visible: wifiScanning; running: wifiScanning; size: 14; color: Theme.primary }
          Text {
            id: wifiScanLbl
            text: wifiScanning ? "Scanning…" : "Refresh"
            color: Theme.primary; font.family: "Inter"; font.pixelSize: 11; font.weight: 600

            SequentialAnimation on opacity {
              running: wifiScanning; loops: Animation.Infinite
              NumberAnimation { from: 1; to: 0.4; duration: 700; easing.type: Easing.InOutSine }
              NumberAnimation { from: 0.4; to: 1; duration: 700; easing.type: Easing.InOutSine }
            }
            onOpacityChanged: if (!wifiScanning) opacity = 1

            MouseArea {
              anchors.fill: parent; anchors.margins: -6
              cursorShape: Qt.PointingHandCursor
              onClicked: if (!wifiScanning) scanWifi()
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true; height: 38; radius: 12
        color: Theme.surface; border.color: searchField.activeFocus ? Theme.primary : Theme.border
        border.width: searchField.activeFocus ? 1.5 : 1
        Behavior on border.color { ColorAnimation { duration: Motion.durXS } }

        RowLayout {
          anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 8
          Text { text: "󰍉"; color: Theme.subtext; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
          TextField {
            id: searchField
            Layout.fillWidth: true
            color: Theme.text; placeholderText: "Filter networks"; placeholderTextColor: Theme.subtext
            background: null; font.family: "Inter"; font.pixelSize: 12
            text: _search; onTextChanged: _search = text
          }
        }
      }

      Repeater {
        model: _available

        Rectangle {
          required property var modelData
          Layout.fillWidth: true
          Layout.preferredHeight: 52
          radius: 14
          color: (modelData.ssid === wifiConnectingSsid)
            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
            : (netMouse.containsMouse ? Theme.surfaceHover : Theme.surface)
          border.color: modelData.ssid === wifiConnectingSsid ? Theme.primary : "transparent"
          border.width: modelData.ssid === wifiConnectingSsid ? 1.5 : 0
          Behavior on color { ColorAnimation { duration: Motion.durXS } }

          RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            SignalBars { signal: modelData.signal; barColor: Theme.text; implicitHeight: 18 }
            ColumnLayout {
              spacing: 1
              Layout.fillWidth: true

              Text {
                text: modelData.ssid
                color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true
                font.family: "Inter"; font.pixelSize: 13; font.weight: 600
              }
              RowLayout {
                spacing: 5
                Text {
                  text: _isSecured(modelData.security) ? "Secured" : "Open"
                  color: Theme.subtext; opacity: 0.7
                  font.family: "Inter"; font.pixelSize: 10
                }
                Text {
                  visible: modelData.band.length > 0
                  text: "· " + modelData.band
                  color: Theme.subtext
                  font.family: "Inter"; font.pixelSize: 10
                }
                Text {
                  visible: modelData.known
                  text: "· Saved"
                  color: Theme.subtext
                  font.family: "Inter"; font.pixelSize: 10
                }
              }
            }
            Spinner {
              visible: modelData.ssid === wifiConnectingSsid
              running: modelData.ssid === wifiConnectingSsid
              size: 16; color: Theme.primary
            }
            Text {
              visible: _isSecured(modelData.security) && modelData.ssid !== wifiConnectingSsid
              text: "󰲛"; color: Theme.text; opacity: 0.4
              font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
            }
          }
          MouseArea {
            id: netMouse
            anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: connectToWifi(modelData.ssid, modelData.security, "")
          }
        }
      }

      Text {
        visible: wifiEnabled && _available.length === 0 && !wifiScanning
        text: _search.length ? "No networks match “" + _search + "”" : "No networks found"
        color: Theme.text; opacity: 0.4
        Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 8
        font.family: "Inter"; font.pixelSize: 12
      }
      ColumnLayout {
        visible: wifiEnabled && wifiScanning && _available.length === 0
        Layout.fillWidth: true; spacing: 8

        Repeater {
          model: 3
          Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 52; radius: 14; color: Theme.surface
            SequentialAnimation on opacity {
              running: true; loops: Animation.Infinite
              NumberAnimation { from: 1; to: 0.4; duration: 800; easing.type: Easing.InOutSine }
              NumberAnimation { from: 0.4; to: 1; duration: 800; easing.type: Easing.InOutSine }
            }
          }
        }
      }

      Rectangle {
        visible: !_hiddenMode
        Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 14
        color: "transparent"; border.color: Theme.outline; border.width: 1

        Text {
          anchors.centerIn: parent
          text: "Connect to hidden network"
          color: Theme.subtext; font.family: "Inter"; font.pixelSize: 12; font.weight: 600
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: { _hiddenMode = true; _hiddenSsid = ""; }
        }
      }
    }

    Item { Layout.preferredHeight: 4 }
  }
}
