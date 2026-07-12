import "../overlay"
import "../services"
import "../theme"
import "../widgets"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// ---- DESIGN NOTE ----------------------------------------------------------
// Signature motif: a radial "signal ring" (SignalRing.qml) replaces the
// generic four-bar Wi‑Fi icon everywhere on this page — as a big hero gauge
// for the active connection, a small strength indicator on every row, an
// indeterminate spinner while connecting, and an outlined "+" on the add-
// network tile. One shape, reused with intent, instead of a bar icon plus a
// separate spinner plus a separate lock glyph plus a separate skeleton.
//
// Rows drop the generic "rounded card that fills on hover" pattern in favor
// of a thin left accent bar + hairline divider, like a technical readout —
// status lines are set in JetBrains Mono, tracked and uppercase, to read as
// data rather than prose. SSIDs stay in Inter so names remain the most
// readable thing on the row.
//
// External API is unchanged from the previous revision — ControlCenter.qml's
// bindings (wifiPhase / wifiActionSsid / wifiActionIsNew / etc.) still work
// as-is; only the presentation layer below changed.
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
    property string wifiPhase: "idle"
    property string wifiActionSsid: ""
    property string wifiPendingSecurity: ""
    property bool wifiActionIsNew: false
    property string wifiConnectError: ""
    property string wifiCurrentPassword: ""
    property bool wifiPasswordRevealed: false
    property string wifiQrPath: ""
    property bool _pwReveal: false
    property bool _hiddenMode: false
    property string _hiddenSsid: ""
    property bool _revealPw: false
    property string _expanded: ""
    readonly property bool _connected: wifiName.length > 0 && wifiName !== "Off" && wifiName !== "No network" && wifiName !== "Disconnected"
    readonly property var _active: _activeNetwork()
    readonly property int _connectedSignal: _connected ? Math.max(0, Math.min(100, Math.round(wifiSignal))) : 0
    readonly property bool _pwSheetOpen: wifiPhase === "needs-password" || _hiddenMode
    readonly property var _savedList: {
        var arr = wifiNetworks.filter(function(n) {
            return n.known && !n.active;
        });
        arr.sort(function(a, b) {
            if (a.offline !== b.offline)
                return a.offline ? 1 : -1;

            return b.signal - a.signal;
        });
        return arr;
    }
    readonly property var _availableList: {
        var arr = wifiNetworks.filter(function(n) {
            return !n.known && !n.active;
        });
        arr.sort(function(a, b) {
            return b.signal - a.signal;
        });
        return arr;
    }

    signal toggleWifi()
    signal scanWifi()
    signal connectToWifi(string ssid, string security, string password)
    signal connectHidden(string ssid, string password)
    signal requestPassword(string ssid, string security)
    signal cancelPassword()
    signal cancelConnect()
    signal disconnectWifi()
    signal forgetWifi(string ssid)
    signal loadCurrentWifiPassword()
    signal generateWifiQr()
    signal backRequested()

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
            connectToWifi(wifiActionSsid || "", wifiPendingSecurity, wifiPwField.text);
    }

    function _onNetworkClick(net) {
        if (wifiPhase === "connecting" && net.ssid === wifiActionSsid) {
            cancelConnect();
            return ;
        }
        if (_isSecured(net.security) && !net.known)
            requestPassword(net.ssid, net.security);
        else
            connectToWifi(net.ssid, net.security, "");
    }

    function _statusCaption(n, connecting) {
        if (connecting)
            return "CONNECTING…";

        if (n.offline)
            return "SAVED · NOT IN RANGE";

        if (n.known)
            return "SAVED";

        return _isSecured(n.security) ? "SECURED" : "OPEN";
    }

    padding: 0
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    ScrollBar.vertical.policy: ScrollBar.AsNeeded
    contentWidth: width

    ColumnLayout {
        width: parent.width
        spacing: 20

        // ============ ENABLE ROW ============
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 40

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                spacing: 12

                SignalRing {
                    implicitWidth: 26
                    implicitHeight: 26
                    trackWidth: 3
                    value: wifiEnabled ? 100 : 0
                    ringColor: Theme.primary
                    trackColor: Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: wifiEnabled ? "󰤨" : "󰤮"
                        color: wifiEnabled ? Theme.primary : Theme.subtext
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                    }

                }

                ColumnLayout {
                    spacing: 1

                    Text {
                        text: "Wi‑Fi"
                        color: Theme.text
                        font.family: "Inter"
                        font.pixelSize: 13
                        font.weight: 600
                    }

                    Text {
                        text: !wifiEnabled ? "Off" : (_connected ? "Connected to " + wifiName : (wifiScanning ? "Scanning…" : "Not connected"))
                        color: Theme.subtext
                        opacity: 0.75
                        font.family: "Inter"
                        font.pixelSize: 11
                    }

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

        }

        // ============ OFF STATE ============
        ColumnLayout {
            visible: !wifiEnabled
            Layout.fillWidth: true
            Layout.topMargin: 24
            Layout.bottomMargin: 24
            spacing: 14

            SignalRing {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 64
                implicitHeight: 64
                trackWidth: 3
                value: 0
                trackColor: Theme.border

                Text {
                    anchors.centerIn: parent
                    text: "󰤮"
                    color: Theme.subtext
                    opacity: 0.6
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 22
                }

            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "WI‑FI IS OFF"
                color: Theme.subtext
                opacity: 0.6
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                font.letterSpacing: 1.5
            }

            QsButton {
                Layout.alignment: Qt.AlignHCenter
                text: "Turn on"
                onClicked: toggleWifi()
            }

        }

        // ============ CONNECTED HERO ============
        Item {
            visible: wifiEnabled && _connected && _active
            Layout.fillWidth: true
            Layout.preferredHeight: heroCol.implicitHeight

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: Theme.surfaceContainer
            }

            Rectangle {
                width: 3
                radius: 2
                color: Theme.primary
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: 10
                anchors.topMargin: 14
                anchors.bottomMargin: 14
            }

            ColumnLayout {
                id: heroCol

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 22
                anchors.rightMargin: 16
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    Layout.bottomMargin: 16
                    spacing: 14

                    SignalRing {
                        implicitWidth: 58
                        implicitHeight: 58
                        trackWidth: 3.5
                        value: _connectedSignal
                        ringColor: Theme.primary
                        trackColor: Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: Math.round(_connectedSignal) + "%"
                            color: Theme.text
                            font.family: "JetBrains Mono"
                            font.pixelSize: 12
                            font.weight: 700
                        }

                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: wifiName
                            color: Theme.text
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            font.family: "Inter"
                            font.pixelSize: 16
                            font.weight: 700
                        }

                        Text {
                            text: "CONNECTED" + (_isSecured(wifiSecurity) ? " · " + wifiSecurity.toUpperCase() : " · OPEN") + (wifiSpeed.length ? " · " + wifiSpeed.toUpperCase() : "")
                            color: Theme.primary
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            font.letterSpacing: 1
                        }

                    }

                    Text {
                        text: _expanded === wifiName ? "󰅃" : "󰅀"
                        color: Theme.subtext
                        opacity: 0.7
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: _expanded = (_expanded === wifiName) ? "" : wifiName
                    }

                }

                // ---- chip row: IP / band, always visible, quick glance ----
                RowLayout {
                    visible: _expanded !== wifiName
                    Layout.fillWidth: true
                    Layout.bottomMargin: 16
                    spacing: 8

                    Repeater {
                        model: [{
                            "label": "IP",
                            "value": wifiIp
                        }, {
                            "label": "BAND",
                            "value": _active && _active.band ? _active.band : ""
                        }]

                        Rectangle {
                            required property var modelData

                            visible: modelData.value.length > 0
                            radius: 8
                            color: Theme.surface
                            implicitWidth: chipText.implicitWidth + 20
                            implicitHeight: 24

                            Text {
                                id: chipText

                                anchors.centerIn: parent
                                text: modelData.label + " " + modelData.value
                                color: Theme.subtext
                                font.family: "JetBrains Mono"
                                font.pixelSize: 10
                            }

                        }

                    }

                    Item {
                        Layout.fillWidth: true
                    }

                }

                // ---- expanded drawer ----
                ColumnLayout {
                    visible: _expanded === wifiName
                    Layout.fillWidth: true
                    Layout.bottomMargin: 16
                    spacing: 14

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.outline
                        opacity: 0.4
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 18
                        rowSpacing: 12

                        ColumnLayout {
                            spacing: 3
                            Layout.fillWidth: true

                            Text {
                                text: "IP ADDRESS"
                                color: Theme.subtext
                                opacity: 0.6
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 9
                                font.letterSpacing: 1
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
                                text: "MAC"
                                color: Theme.subtext
                                opacity: 0.6
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 9
                                font.letterSpacing: 1
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

                        ColumnLayout {
                            spacing: 3
                            Layout.fillWidth: true
                            Layout.columnSpan: 2

                            Text {
                                text: "PASSWORD"
                                color: Theme.subtext
                                opacity: 0.6
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 9
                                font.letterSpacing: 1
                            }

                            RowLayout {
                                spacing: 8
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

                    }

                    Image {
                        visible: _revealPw && wifiQrPath.length > 0
                        source: wifiQrPath
                        Layout.preferredWidth: 108
                        Layout.preferredHeight: 108
                        Layout.alignment: Qt.AlignHCenter
                        fillMode: Image.PreserveAspectFit
                        smooth: false
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Item {
                            Layout.fillWidth: true
                        }

                        QsButton {
                            text: "Forget"
                            outline: true
                            onClicked: forgetWifi(wifiName)
                        }

                        QsButton {
                            text: "Disconnect"
                            danger: true
                            onClicked: disconnectWifi()
                        }

                    }

                }

            }

        }

        // ============ ERROR BANNER ============
        Item {
            visible: wifiEnabled && wifiConnectError.length > 0 && !_pwSheetOpen
            Layout.fillWidth: true
            Layout.preferredHeight: errRow.implicitHeight + 18

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: Theme.surface
            }

            Rectangle {
                width: 3
                radius: 2
                color: Theme.error
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: 8
                anchors.topMargin: 8
                anchors.bottomMargin: 8
            }

            RowLayout {
                id: errRow

                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 12
                anchors.topMargin: 9
                anchors.bottomMargin: 9
                spacing: 10

                Text {
                    text: wifiConnectError
                    color: Theme.text
                    opacity: 0.85
                    font.family: "Inter"
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }

                Text {
                    text: "DISMISS"
                    color: Theme.error
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    font.letterSpacing: 1

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cancelPassword()
                    }

                }

            }

        }

        // ============ SAVED NETWORKS ============
        ColumnLayout {
            visible: wifiEnabled && _savedList.length > 0
            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 8
                spacing: 7

                Rectangle {
                    width: 5
                    height: 5
                    radius: 2
                    color: Theme.primary
                    opacity: 0.8
                }

                Text {
                    text: "SAVED · " + _savedList.length
                    color: Theme.muted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                }

            }

            Repeater {
                model: _savedList

                delegate: networkRow
            }

        }

        // ============ AVAILABLE NETWORKS ============
        ColumnLayout {
            visible: wifiEnabled
            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 8
                spacing: 7

                Rectangle {
                    width: 5
                    height: 5
                    radius: 2
                    color: Theme.subtext
                    opacity: 0.6
                }

                Text {
                    text: "AVAILABLE" + (_availableList.length > 0 ? " · " + _availableList.length : "")
                    color: Theme.muted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                }

                Item {
                    Layout.fillWidth: true
                }

                RowLayout {
                    spacing: 6

                    SignalRing {
                        visible: wifiScanning
                        implicitWidth: 12
                        implicitHeight: 12
                        trackWidth: 1.5
                        indeterminate: true
                        ringColor: Theme.primary
                        trackColor: Theme.border
                    }

                    Text {
                        text: wifiScanning ? "SCANNING…" : "REFRESH"
                        color: Theme.primary
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.letterSpacing: 1

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!wifiScanning)
                                    scanWifi();

                            }
                        }

                    }

                }

            }

            Repeater {
                model: _availableList

                delegate: networkRow
            }

            ColumnLayout {
                visible: wifiScanning && _availableList.length === 0
                Layout.fillWidth: true
                spacing: 6
                Layout.topMargin: 4

                Repeater {
                    model: 3

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 10
                        color: Theme.surface

                        SequentialAnimation on opacity {
                            running: true
                            loops: Animation.Infinite

                            NumberAnimation {
                                from: 1
                                to: 0.35
                                duration: 800
                                easing.type: Easing.InOutSine
                            }

                            NumberAnimation {
                                from: 0.35
                                to: 1
                                duration: 800
                                easing.type: Easing.InOutSine
                            }

                        }

                    }

                }

            }

            Text {
                visible: !wifiScanning && _availableList.length === 0 && _savedList.length === 0 && !_connected
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
                Layout.topMargin: 6
                visible: !_hiddenMode

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: "transparent"
                    border.color: Theme.border
                    border.width: 1
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    SignalRing {
                        implicitWidth: 20
                        implicitHeight: 20
                        trackWidth: 1.5
                        value: 0
                        trackColor: Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            color: Theme.subtext
                            font.family: "Inter"
                            font.pixelSize: 13
                            font.weight: 700
                        }

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
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        _hiddenMode = true;
                        _hiddenSsid = "";
                    }
                }

            }

        }

        // ============ PASSWORD SHEET ============
        Item {
            id: pwSheet

            visible: _pwSheetOpen
            onVisibleChanged: {
                if (visible)
                    wifiPwField.forceActiveFocus();

            }
            Layout.fillWidth: true
            Layout.preferredHeight: pwCol.implicitHeight + 28

            Rectangle {
                anchors.fill: parent
                radius: 18
                color: Theme.surfaceContainer
                border.color: Theme.outline
                border.width: 1
            }

            ColumnLayout {
                id: pwCol

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 20
                spacing: 12

                SignalRing {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 4
                    implicitWidth: 46
                    implicitHeight: 46
                    trackWidth: 2.5
                    value: 0
                    trackColor: Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: "󰌾"
                        color: Theme.subtext
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                    }

                }

                Text {
                    text: _hiddenMode ? "Hidden network" : (wifiActionSsid || "")
                    color: Theme.text
                    font.family: "Inter"
                    font.pixelSize: 14
                    font.weight: 700
                    Layout.alignment: Qt.AlignHCenter
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    visible: !_hiddenMode
                    text: wifiActionIsNew ? "THIS NETWORK NEEDS A PASSWORD" : "SAVED PASSWORD NO LONGER WORKS"
                    color: Theme.subtext
                    opacity: 0.7
                    Layout.alignment: Qt.AlignHCenter
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 9
                    font.letterSpacing: 1
                }

                Rectangle {
                    visible: _hiddenMode
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    height: 42
                    radius: 10
                    color: Theme.surface
                    border.color: hiddenField.activeFocus ? Theme.primary : Theme.border
                    border.width: 1

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Motion.durXS
                        }

                    }

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
                    Layout.topMargin: _hiddenMode ? 0 : 4
                    height: 42
                    radius: 10
                    color: Theme.surface
                    border.color: wifiPwField.activeFocus ? Theme.primary : Theme.border
                    border.width: 1

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Motion.durXS
                        }

                    }

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
                    Layout.topMargin: 4
                    spacing: 8

                    Text {
                        visible: !_hiddenMode && !wifiActionIsNew
                        text: "FORGET"
                        color: Theme.error
                        opacity: 0.85
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.letterSpacing: 1

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                forgetWifi(wifiActionSsid || "");
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
                        enabled: _hiddenMode ? _hiddenSsid.trim().length > 0 : true
                        onClicked: _doConnect()
                    }

                }

            }

        }

        Item {
            Layout.preferredHeight: 4
        }

    }

    // ============ SHARED NETWORK ROW ============
    Component {
        id: networkRow

        Item {
            id: rowRoot

            required property var modelData
            readonly property bool isConnecting: wifiPhase === "connecting" && modelData.ssid === wifiActionSsid
            readonly property bool isOffline: modelData.offline === true

            Layout.fillWidth: true
            Layout.preferredHeight: 52
            opacity: isOffline ? 0.55 : 1

            Rectangle {
                width: 2
                radius: 1
                color: Theme.primary
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: 12
                anchors.bottomMargin: 12
                opacity: (netMouse.containsMouse || rowRoot.isConnecting) ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.durXS
                    }

                }

            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 34
                height: 1
                color: Theme.outline
                opacity: 0.3
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 8
                spacing: 12

                SignalRing {
                    implicitWidth: 20
                    implicitHeight: 20
                    trackWidth: 2
                    value: rowRoot.isOffline ? 0 : modelData.signal
                    indeterminate: rowRoot.isConnecting
                    ringColor: modelData.known ? Theme.primary : Theme.subtext
                    trackColor: Theme.border

                    Text {
                        visible: rowRoot.isOffline
                        anchors.centerIn: parent
                        text: "󰤭"
                        color: Theme.subtext
                        opacity: 0.7
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
                    }

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

                    Text {
                        text: _statusCaption(modelData, rowRoot.isConnecting)
                        color: rowRoot.isConnecting ? Theme.primary : Theme.subtext
                        opacity: rowRoot.isConnecting ? 1 : 0.6
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
                        font.letterSpacing: 1
                    }

                }

                Text {
                    visible: !rowRoot.isOffline && !rowRoot.isConnecting && _isSecured(modelData.security)
                    text: "󰌾"
                    color: Theme.subtext
                    opacity: 0.45
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                }

                Text {
                    visible: modelData.known && !rowRoot.isConnecting && netMouse.containsMouse
                    text: "󰆴"
                    color: Theme.error
                    opacity: 0.8
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: forgetWifi(modelData.ssid)
                    }

                }

            }

            MouseArea {
                id: netMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: _onNetworkClick(modelData)
            }

        }

    }

}
