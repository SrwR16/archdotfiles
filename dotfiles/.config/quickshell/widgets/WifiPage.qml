import "../overlay"
import "../services"
import "../theme"
import "../widgets"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    id: sv

    property bool wifiEnabled: false
    property string wifiName: ""
    property string wifiSecurity: ""
    property string wifiIp: ""
    property string wifiSpeed: ""
    property int wifiSignal: 0
    property var wifiNetworks: []
    property bool wifiScanning: false
    property string wifiConnectingSsid: ""
    property string wifiPendingSsid: ""
    property string wifiPendingSecurity: ""
    property string wifiConnectError: ""
    property string wifiCurrentPassword: ""
    property bool wifiPasswordRevealed: false
    property string wifiQrPath: ""
    property bool _pwReveal: false
    property bool _hiddenMode: false
    property string _hiddenSsid: ""
    property bool _revealPw: false
    property string _search: ""
    // SSID of the expanded (connected) row; "" = none.
    property string _expanded: ""
    readonly property bool _connected: wifiName.length > 0 && wifiName !== "Off" && wifiName !== "No network" && wifiName !== "Disconnected"
    readonly property var _active: _activeNetwork()
    readonly property int _connectedSignal: _connected ? Math.max(0, Math.min(100, Math.round(wifiSignal))) : 0
    // Whether the network we are currently prompting a password for is a saved (known) one.
    readonly property bool _pendingKnown: {
        for (var i = 0; i < wifiNetworks.length; i++) {
            if (wifiNetworks[i].ssid === wifiPendingSsid)
                return wifiNetworks[i].known;

        }
        return false;
    }
    // Connected network stays in the list (ranked first); sort by
    // active → connecting → saved → strength.
    readonly property var _sorted: {
        var arr = wifiNetworks.slice();
        arr.sort(function(a, b) {
            return r(a) - r(b) || (b.signal - a.signal);
        });
        return arr;
    }

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

    function r(n) {
        if (n.active)
            return 0;

        if (n.ssid === wifiConnectingSsid)
            return 1;

        if (n.known)
            return 2;

        return 3;
    }

    function _activeNetwork() {
        for (var i = 0; i < wifiNetworks.length; i++) if (wifiNetworks[i].active) {
            return wifiNetworks[i];
        }
        return null;
    }

    function _isSecured(sec) {
        return sec && sec.length > 0 && sec !== "--";
    }

    function _doConnect() {
        if (_hiddenMode)
            connectHidden(_hiddenSsid.trim(), wifiPwField.text);
        else
            connectToWifi(wifiPendingSsid || "", wifiPendingSecurity, wifiPwField.text);
    }

    // Open networks and known (saved) networks connect with no prompt.
    // Only unknown secured networks ask for a password.
    function _onNetworkClick(net) {
        if (!_isSecured(net.security) || net.known)
            connectToWifi(net.ssid, net.security, "");
        else
            requestPassword(net.ssid, net.security);
    }

    padding: 0
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    ScrollBar.vertical.policy: ScrollBar.AsNeeded
    contentWidth: width

    ColumnLayout {
        width: parent.width
        spacing: 14

        // ============ ENABLE (slim row) ============
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            opacity: 0

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: enMouse.containsMouse ? Theme.surfaceHover : "transparent"
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12

                Text {
                    text: "󰤯"
                    color: wifiEnabled ? Theme.primary : Theme.subtext
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                }

                Text {
                    text: "Wi‑Fi"
                    color: Theme.text
                    font.family: "Inter"
                    font.pixelSize: 13
                    font.weight: 600
                }

                Text {
                    text: wifiEnabled ? "On" : "Off"
                    color: Theme.subtext
                    opacity: 0.7
                    font.family: "Inter"
                    font.pixelSize: 11
                }

                Item {
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 42
                    height: 24
                    radius: 12
                    color: wifiEnabled ? Theme.primary : Theme.border

                    Rectangle {
                        width: 18
                        height: 18
                        radius: 9
                        color: Theme.backgroundFg
                        anchors.verticalCenter: parent.verticalCenter
                        x: wifiEnabled ? parent.width - width - 3 : 3

                        Behavior on x {
                            NumberAnimation {
                                duration: Motion.durS
                                easing.type: Motion.easeStandard
                            }

                        }

                    }

                    MouseArea {
                        id: enMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: toggleWifi()
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Motion.durXS
                        }

                    }

                }

            }

            SequentialAnimation on opacity {
                PauseAnimation {
                    duration: 0
                }

                NumberAnimation {
                    from: 0
                    to: 1
                    duration: Motion.durM
                    easing.type: Motion.easeStandard
                    objectName: "entrance"
                }

            }

        }

        // ============ OFF (minimal) ============
        ColumnLayout {
            visible: !wifiEnabled
            Layout.fillWidth: true
            Layout.topMargin: 28
            Layout.bottomMargin: 28
            spacing: 12
            opacity: 0

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "󰤮"
                color: Theme.subtext
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 30
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Wi‑Fi is off"
                color: Theme.text
                opacity: 0.55
                font.family: "Inter"
                font.pixelSize: 12
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter

                QsButton {
                    text: "Turn on"
                    onClicked: toggleWifi()
                }

            }

            SequentialAnimation on opacity {
                PauseAnimation {
                    duration: 60
                }

                NumberAnimation {
                    from: 0
                    to: 1
                    duration: Motion.durM
                    easing.type: Motion.easeStandard
                    objectName: "entrance"
                }

            }

        }

        // ============ NETWORK LIST ============
        ColumnLayout {
            visible: wifiEnabled
            Layout.fillWidth: true
            spacing: 6
            opacity: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Networks"
                    color: Theme.muted
                    font.family: "Inter"
                    font.pixelSize: 11
                    font.weight: 700
                    leftPadding: 4
                }

                Item {
                    Layout.fillWidth: true
                }

                RowLayout {
                    spacing: 6

                    Spinner {
                        visible: wifiScanning
                        running: wifiScanning
                        size: 14
                        color: Theme.primary
                    }

                    Text {
                        id: wifiScanLbl

                        text: wifiScanning ? "Scanning…" : "Refresh"
                        color: Theme.primary
                        font.family: "Inter"
                        font.pixelSize: 11
                        font.weight: 600

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!wifiScanning)
                                    scanWifi();

                            }
                        }

                        SequentialAnimation on opacity {
                            running: wifiScanning
                            loops: Animation.Infinite

                            NumberAnimation {
                                from: 1
                                to: 0.4
                                duration: 700
                                easing.type: Easing.InOutSine
                            }

                            NumberAnimation {
                                from: 0.4
                                to: 1
                                duration: 700
                                easing.type: Easing.InOutSine
                            }

                        }

                    }

                }

            }

            Repeater {
                model: _sorted

                // Each row is a rounded StateLayer-style tile: transparent by
                // default, subtle hover tint, primary tint when it's the
                // active connection. The connected network lives here (no
                // separate hero block).
                Item {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: rowCol.implicitHeight
                    opacity: modelData.ssid === wifiConnectingSsid ? 0.55 : 1

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: modelData.active ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : (netMouse.containsMouse ? Theme.surfaceHover : "transparent")
                    }

                    ColumnLayout {
                        id: rowCol

                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Layout.leftMargin: 14
                            Layout.rightMargin: 14
                            Layout.topMargin: 12
                            Layout.bottomMargin: 12

                            SignalBars {
                                signal: modelData.signal
                                barColor: modelData.active ? Theme.primary : Theme.text
                                implicitHeight: 18
                            }

                            ColumnLayout {
                                spacing: 2
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
                                    spacing: 5

                                    Text {
                                        text: modelData.active ? "Connected" : (_isSecured(modelData.security) ? "Secured" : "Open")
                                        color: modelData.active ? Theme.primary : Theme.subtext
                                        opacity: modelData.active ? 1 : 0.7
                                        font.family: "Inter"
                                        font.pixelSize: 10
                                        font.weight: modelData.active ? 600 : 400
                                    }

                                    Text {
                                        visible: modelData.active && _connectedSignal > 0
                                        text: "· " + Math.round(_connectedSignal) + "%"
                                        color: Theme.primary
                                        font.family: "Inter"
                                        font.pixelSize: 10
                                    }

                                    Text {
                                        visible: !modelData.active && modelData.known
                                        text: "· Saved"
                                        color: Theme.subtext
                                        font.family: "Inter"
                                        font.pixelSize: 10
                                    }

                                    Text {
                                        visible: !modelData.active && modelData.band.length > 0
                                        text: "· " + modelData.band
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
                                visible: !modelData.active && _isSecured(modelData.security)
                                text: "󰲛"
                                color: Theme.text
                                opacity: 0.4
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                            }

                            Text {
                                visible: modelData.active
                                text: _expanded === modelData.ssid ? "󰌋" : "󰌊"
                                color: Theme.primary
                                opacity: 0.8
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                            }

                        }

                        // ---- Connected details (expandable) ----
                        ColumnLayout {
                            visible: modelData.active && _expanded === modelData.ssid
                            Layout.fillWidth: true
                            spacing: 10
                            Layout.leftMargin: 14
                            Layout.rightMargin: 14
                            Layout.bottomMargin: 12

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Theme.outline
                                opacity: 0.5
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: detGrid.implicitHeight

                                GridLayout {
                                    id: detGrid

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    columns: 2
                                    rowSpacing: 12
                                    columnSpacing: 14

                                    ColumnLayout {
                                        spacing: 3
                                        Layout.fillWidth: true

                                        Text {
                                            text: "IP address"
                                            color: Theme.subtext
                                            font.family: "Inter"
                                            font.pixelSize: 10
                                        }

                                        Text {
                                            text: wifiIp.length ? wifiIp : "—"
                                            color: Theme.text
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                    }

                                    ColumnLayout {
                                        spacing: 3
                                        Layout.fillWidth: true

                                        Text {
                                            text: "Band"
                                            color: Theme.subtext
                                            font.family: "Inter"
                                            font.pixelSize: 10
                                        }

                                        Text {
                                            text: _active && _active.band ? _active.band : "—"
                                            color: Theme.text
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                    }

                                    ColumnLayout {
                                        spacing: 3
                                        Layout.fillWidth: true

                                        Text {
                                            text: "Password"
                                            color: Theme.subtext
                                            font.family: "Inter"
                                            font.pixelSize: 10
                                        }

                                        RowLayout {
                                            spacing: 6
                                            Layout.fillWidth: true

                                            Text {
                                                Layout.fillWidth: true
                                                text: _revealPw ? (wifiCurrentPassword.length ? wifiCurrentPassword : "—") : "•".repeat(Math.max(6, wifiCurrentPassword.length))
                                                color: Theme.text
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 12
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: _revealPw ? "󰋭" : "󰋬"
                                                color: Theme.text
                                                opacity: 0.7
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 13

                                                MouseArea {
                                                    anchors.fill: parent
                                                    anchors.margins: -6
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        _revealPw = !_revealPw;
                                                        if (_revealPw)
                                                            loadCurrentWifiPassword();
                                                        else
                                                            generateWifiQr();
                                                    }
                                                }

                                            }

                                        }

                                    }

                                    ColumnLayout {
                                        spacing: 3
                                        Layout.fillWidth: true

                                        Text {
                                            text: "MAC"
                                            color: Theme.subtext
                                            font.family: "Inter"
                                            font.pixelSize: 10
                                        }

                                        Text {
                                            text: _active && _active.mac ? _active.mac : "—"
                                            color: Theme.text
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                    }

                                }

                            }

                            Image {
                                visible: _revealPw && wifiQrPath.length > 0
                                source: wifiQrPath
                                Layout.preferredWidth: 110
                                Layout.preferredHeight: 110
                                Layout.alignment: Qt.AlignHCenter
                                fillMode: Image.PreserveAspectFit
                                smooth: false
                            }

                            QsButton {
                                text: "Disconnect"
                                danger: true
                                onClicked: disconnectWifi()
                            }

                        }

                    }

                    MouseArea {
                        id: netMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.active)
                                _expanded = (_expanded === modelData.ssid) ? "" : modelData.ssid;
                            else
                                _onNetworkClick(modelData);
                        }
                    }

                }

            }

            ColumnLayout {
                visible: wifiEnabled && wifiScanning && _sorted.length === 0
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: 3

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 12
                        color: Theme.surface

                        SequentialAnimation on opacity {
                            running: true
                            loops: Animation.Infinite

                            NumberAnimation {
                                from: 1
                                to: 0.4
                                duration: 800
                                easing.type: Easing.InOutSine
                            }

                            NumberAnimation {
                                from: 0.4
                                to: 1
                                duration: 800
                                easing.type: Easing.InOutSine
                            }

                        }

                    }

                }

            }

            Text {
                visible: wifiEnabled && _sorted.length === 0 && !wifiScanning
                text: "No networks found"
                color: Theme.text
                opacity: 0.4
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                font.family: "Inter"
                font.pixelSize: 12
            }

            // ---- Add (hidden) network ----
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                opacity: _hiddenMode ? 0 : 1
                visible: !_hiddenMode

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: addMouse.containsMouse ? Theme.surfaceHover : "transparent"
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    Text {
                        text: "󰄲"
                        color: Theme.subtext
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                    }

                    Text {
                        text: "Add network"
                        color: Theme.text
                        font.family: "Inter"
                        font.pixelSize: 13
                        font.weight: 600
                    }

                }

                MouseArea {
                    id: addMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        _hiddenMode = true;
                        _hiddenSsid = "";
                    }
                }

            }

            SequentialAnimation on opacity {
                PauseAnimation {
                    duration: 120
                }

                NumberAnimation {
                    from: 0
                    to: 1
                    duration: Motion.durM
                    easing.type: Motion.easeStandard
                    objectName: "entrance"
                }

            }

        }

        // ============ PASSWORD SHEET ============
        Item {
            id: pwSheet

            visible: (wifiPendingSsid || "") !== "" || _hiddenMode
            onVisibleChanged: {
                if (visible)
                    wifiPwField.forceActiveFocus();

            }
            Layout.fillWidth: true
            Layout.preferredHeight: pwCol.implicitHeight + 24

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.55)
                border.color: Theme.outline
                border.width: 1
            }

            ColumnLayout {
                id: pwCol

                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Text {
                    text: _hiddenMode ? "Connect to hidden network" : ("Connect to " + (wifiPendingSsid || ""))
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
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1

                    TextField {
                        id: hiddenField

                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
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
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
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
                            onAccepted: _doConnect()
                        }

                        Text {
                            text: _pwReveal ? "󰋭" : "󰋬"
                            color: Theme.text
                            opacity: 0.7
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
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
                            onClicked: {
                                forgetWifi(wifiPendingSsid || "");
                                _hiddenMode = false;
                            }
                        }

                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    QsButton {
                        text: "Cancel"
                        outline: true
                        onClicked: {
                            cancelPassword();
                            _hiddenMode = false;
                            _hiddenSsid = "";
                        }
                    }

                    QsButton {
                        text: "Connect"
                        onClicked: _doConnect()
                    }

                }

            }

        }

        Item {
            Layout.preferredHeight: 4
        }

    }

}
