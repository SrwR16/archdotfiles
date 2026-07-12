import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Wi‑Fi backend built on the native Quickshell.Networking API (NetworkManager).
// The device/network list, connect/disconnect/forget, scanning and auth‑failure
// detection all go through the native types; only the few fields NetworkManager
// does not expose over the API (IP, link speed, BSSID, band) and hidden‑
// networkConnect are fetched via nmcli.
Item {
    id: root

    property bool wifiEnabled: Networking.wifiEnabled
    property string wifiName: "Off"
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
    readonly property var wifiDev: {
        var devs = Networking.devices.values;
        for (var i = 0; i < devs.length; ++i) {
            if (devs[i] && devs[i].type === DeviceType.Wifi)
                return devs[i];

        }
        return null;
    }
    property string _detailMac: ""
    property string _detailBand: ""
    property var wifiConnectingNet: null
    property string _lastDetailName: ""

    function _secLabel(sec) {
        try {
            if (sec === WifiSecurityType.Open)
                return "";

            var s = WifiSecurityType.toString(sec);
            return (s && s.length > 0) ? s : "Secured";
        } catch (e) {
            return "Secured";
        }
    }

    function _findNet(ssid) {
        var dev = root.wifiDev;
        if (!dev || !ssid)
            return null;

        var nets = dev.networks.values;
        for (var i = 0; i < nets.length; ++i) {
            if (nets[i] && nets[i].name === ssid)
                return nets[i];

        }
        return null;
    }

    function _findConnected() {
        var dev = root.wifiDev;
        if (!dev)
            return null;

        var nets = dev.networks.values;
        for (var i = 0; i < nets.length; ++i) {
            if (nets[i] && nets[i].connected)
                return nets[i];

        }
        return null;
    }

    function _rebuild() {
        var dev = root.wifiDev;
        if (!dev || !root.wifiEnabled) {
            root.wifiNetworks = [];
            root.wifiName = root.wifiEnabled ? "No network" : "Off";
            root.wifiSecurity = "";
            root.wifiSignal = 0;
            return ;
        }
        var nets = dev.networks.values;
        var list = [];
        var active = null;
        for (var i = 0; i < nets.length; ++i) {
            var net = nets[i];
            if (!net)
                continue;

            var ssid = net.name || "";
            if (!ssid)
                continue;

            var sig = Math.round((net.signalStrength || 0) * 100);
            var connected = net.connected;
            list.push({
                "ssid": ssid,
                "signal": sig,
                "security": root._secLabel(net.security),
                "mac": connected ? root._detailMac : "",
                "band": connected ? root._detailBand : "",
                "active": connected,
                "known": net.known
            });
            if (connected)
                active = net;

        }
        root.wifiNetworks = list;
        if (active) {
            root.wifiName = active.name;
            root.wifiSecurity = root._secLabel(active.security);
            root.wifiSignal = Math.round((active.signalStrength || 0) * 100);
        } else {
            root.wifiName = "No network";
            root.wifiSecurity = "";
            root.wifiSignal = 0;
        }
    }

    function _refreshDetail() {
        var dev = root.wifiDev ? root.wifiDev.name : "";
        if (!dev || root.wifiName === "Off" || root.wifiName === "No network" || !root.wifiName) {
            root.wifiIp = "";
            root.wifiSpeed = "";
            root._detailMac = "";
            root._detailBand = "";
            return ;
        }
        if (root.wifiName !== root._lastDetailName) {
            root._lastDetailName = root.wifiName;
            root.wifiIp = "";
            root.wifiSpeed = "";
            root._detailMac = "";
            root._detailBand = "";
        }
        wifiDetailProc.command = ["sh", "-c", "ip=$(nmcli -t -f IP4.ADDRESS device show '" + dev + "' 2>/dev/null | head -1 | cut -d: -f2- | cut -d/ -f1);" + "spd=$(iw dev '" + dev + "' link 2>/dev/null | grep -i 'tx bitrate' | grep -oE '[0-9.]+ MBit/s' | head -1);" + "mac=$(iw dev '" + dev + "' link 2>/dev/null | grep -i 'Connected to' | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | head -1);" + "freq=$(iw dev '" + dev + "' link 2>/dev/null | grep -i 'freq' | grep -oE '[0-9]+' | head -1);" + "band='';" + "if [ -n \"$freq\" ]; then if [ \"$freq\" -ge 5000 ]; then band='5 GHz'; else band='2.4 GHz'; fi; fi;" + "echo \"$ip|$spd|$mac|$band\""];
        wifiDetailProc.running = true;
    }

    function refreshWifi() {
        root._rebuild();
        root._refreshDetail();
    }

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
        if (!Networking.wifiEnabled) {
            root.wifiNetworks = [];
            root.wifiName = "Off";
            root.wifiSecurity = "";
            root.wifiIp = "";
            root.wifiSpeed = "";
            root.wifiSignal = 0;
            root.wifiConnectingSsid = "";
            root.wifiPendingSsid = "";
            root.wifiPendingSecurity = "";
            root.wifiPasswordRevealed = false;
        } else {
            root.scanWifi();
        }
    }

    function scanWifi() {
        if (!root.wifiEnabled || !root.wifiDev) {
            root.wifiScanning = false;
            return ;
        }
        root.wifiScanning = true;
        root.wifiDev.scannerEnabled = true;
        root._rebuild();
        scanClearTimer.restart();
    }

    function connectToWifi(ssid, security, password) {
        var s = String(ssid || "");
        if (s.length === 0)
            return ;

        var pw = String(password || "");
        root.wifiConnectError = "";
        root.wifiConnectingSsid = s;
        root.wifiPendingSsid = s;
        root.wifiPendingSecurity = String(security || "");
        root.wifiConnectingNet = null;
        var net = root._findNet(s);
        if (net) {
            root.wifiConnectingNet = net;
            if (pw.length > 0)
                net.connectWithPsk(pw);
            else
                net.connect();
        } else {
            var args = ["nmcli", "device", "wifi", "connect", s];
            if (pw.length > 0) {
                args.push("password");
                args.push(pw);
            }
            hiddenConnProc.command = args;
            hiddenConnProc.running = true;
        }
        root.connTimer.restart();
    }

    function disconnectWifi() {
        var net = root._findConnected();
        if (net)
            net.disconnect();
        else if (root.wifiDev)
            root.wifiDev.disconnect();
        root.wifiConnectingSsid = "";
        root.connTimer.stop();
    }

    function forgetWifi(ssid) {
        var net = root._findNet(ssid);
        if (net)
            net.forget();

        if (root.wifiPendingSsid === ssid) {
            root.wifiPendingSsid = "";
            root.wifiPendingSecurity = "";
        }
        root.scanWifi();
    }

    function requestPassword(ssid, security) {
        root.wifiPendingSsid = ssid;
        root.wifiPendingSecurity = security || "";
        root.wifiConnectError = "";
    }

    function cancelPassword() {
        root.wifiPendingSsid = "";
        root.wifiPendingSecurity = "";
        root.wifiConnectError = "";
        root.wifiConnectingSsid = "";
        root.wifiConnectingNet = null;
        root.connTimer.stop();
    }

    function loadCurrentWifiPassword() {
        if (!root.wifiName || root.wifiName === "No network" || root.wifiName === "Off")
            return ;

        wifiPasswordProc.command = ["sh", "-c", "nmcli -s -g 802-11-wireless-security.psk connection show '" + root.wifiName.replace(/'/g, "'\\''") + "' 2>/dev/null"];
        wifiPasswordProc.running = true;
    }

    function generateWifiQr() {
        if (!root.wifiCurrentPassword) {
            root.wifiQrPath = "";
            return ;
        }
        var sec = (root.wifiSecurity && root.wifiSecurity.length > 0) ? "WPA" : "nopass";
        var payload = "WIFI:T:" + sec + ";S:" + root.wifiName + ";P:" + root.wifiCurrentPassword + ";;";
        var escaped = payload.replace(/'/g, "'\\''");
        wifiQrProc.command = ["sh", "-c", "qrencode -t PNG -s 6 -o '" + Quickshell.cachePath("wifi-qr.png") + "' '" + escaped + "'"];
        wifiQrProc.running = true;
        root.wifiQrPath = "";
    }

    onWifiEnabledChanged: {
        if (root.wifiEnabled)
            root.scanWifi();
        else
            root._rebuild();
    }
    onWifiDevChanged: root._rebuild()
    Component.onCompleted: root._rebuild()

    Connections {
        function onConnectionFailed(reason) {
            if (reason === ConnectionFailReason.NoSecrets) {
                var ssid = root.wifiConnectingSsid;
                root.wifiConnectError = "Password is wrong or changed. Re-enter to update.";
                root.wifiPendingSsid = ssid;
                root.wifiConnectingSsid = "";
                root.wifiConnectingNet = null;
                root.connTimer.stop();
            }
        }

        target: root.wifiConnectingNet
    }

    Timer {
        id: listTimer

        interval: 3000
        repeat: true
        running: root.wifiEnabled
        onTriggered: root._rebuild()
    }

    Timer {
        id: scanClearTimer

        interval: 2000
        onTriggered: root.wifiScanning = false
    }

    Timer {
        id: detailTimer

        interval: 5000
        repeat: true
        running: root.wifiName !== "Off" && root.wifiName !== "No network" && root.wifiName.length > 0
        onTriggered: root._refreshDetail()
    }

    Timer {
        id: connTimer

        property int elapsed: 0

        interval: 1000
        repeat: true
        onTriggered: {
            root._rebuild();
            var ssid = root.wifiConnectingSsid;
            if (!ssid) {
                elapsed = 0;
                stop();
                return ;
            }
            if (root.wifiName === ssid) {
                root.wifiConnectError = "";
                root.wifiPendingSsid = "";
                root.wifiConnectingSsid = "";
                root.wifiConnectingNet = null;
                elapsed = 0;
                stop();
                root.scanWifi();
            } else {
                elapsed += interval;
                if (elapsed > 15000) {
                    if (!root.wifiPendingSsid)
                        root.wifiConnectError = "Connection timed out.";

                    root.wifiConnectingSsid = "";
                    root.wifiConnectingNet = null;
                    elapsed = 0;
                    stop();
                }
            }
        }
        onRunningChanged: elapsed = 0
    }

    Process {
        id: wifiDetailProc

        stdout: StdioCollector {
            onStreamFinished: {
                var p = (this.text || "").trim().split("|");
                root.wifiIp = p[0] || "";
                root.wifiSpeed = p[1] || "";
                root._detailMac = p[2] || "";
                root._detailBand = p[3] || "";
                root._rebuild();
            }
        }

    }

    Process {
        id: hiddenConnProc

        stderr: StdioCollector {
            onStreamFinished: {
                var err = (this.text || "").toLowerCase();
                if (err.indexOf("secret") >= 0 || err.indexOf("secrets") >= 0 || err.indexOf("authentication") >= 0 || err.indexOf("auth ") >= 0 || err.indexOf("password") >= 0 || err.indexOf("fail") >= 0 || err.indexOf("error") >= 0) {
                    var ssid = root.wifiConnectingSsid;
                    root.wifiConnectError = "Password is wrong or changed. Re-enter to update.";
                    root.wifiPendingSsid = ssid;
                    root.wifiConnectingSsid = "";
                    root.connTimer.stop();
                }
            }
        }

    }

    Process {
        id: wifiPasswordProc

        stdout: StdioCollector {
            onStreamFinished: root.wifiCurrentPassword = (this.text || "").trim()
        }

    }

    Process {
        id: wifiQrProc

        command: ["sh", "-c", "true"]
    }

    Connections {
        function onExited() {
            root.wifiQrPath = "file://" + Quickshell.cachePath("wifi-qr.png");
        }

        target: wifiQrProc
    }

}
