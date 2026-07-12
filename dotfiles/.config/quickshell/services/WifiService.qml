import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Wi‑Fi backend built on the native Quickshell.Networking API (NetworkManager).
//
// DESIGN NOTE — connection state machine
// ----------------------------------------------------------------------------
// The previous version tracked connection progress with a single overloaded
// string, `wifiPendingSsid`, that meant two different things at different
// times: "the SSID a password sheet is open for" AND "the SSID we last asked
// NetworkManager to join". Because `connectToWifi()` set that same property
// for EVERY connection attempt — including silent ones for known/open
// networks — the password sheet (which is only gated on that string being
// non-empty) popped open even when no password was needed. That was the
// "prompt shows for saved networks too" bug.
//
// This version replaces that with one explicit `wifiPhase` state:
//   idle            -> nothing happening
//   connecting      -> attempt in flight, no user input required
//   needs-password  -> we genuinely need a password from the user right now
//   failed          -> attempt ended in an error, shown inline in the list
//
// The password sheet in WifiPage.qml is gated on `wifiPhase === "needs-password"`
// only, so it appears exactly when — and only when — one is actually needed:
// on first use of a secured network we don't have a saved profile for, or
// when NetworkManager reports back that a saved secret was missing/wrong.
Item {
    id: root

    readonly property string phaseIdle: "idle"
    readonly property string phaseConnecting: "connecting"
    readonly property string phaseNeedsPassword: "needs-password"
    readonly property string phaseFailed: "failed"

    property bool wifiEnabled: Networking.wifiEnabled
    property string wifiName: "Off"
    property string wifiSecurity: ""
    property string wifiIp: ""
    property string wifiSpeed: ""
    property int wifiSignal: 0
    property var wifiNetworks: []
    property bool wifiScanning: false
    // Single source of truth for "what are we doing right now".
    property string wifiPhase: phaseIdle
    // SSID the current phase applies to (connecting / needs-password / failed).
    property string wifiActionSsid: ""
    property string wifiPendingSecurity: ""
    // True when the SSID above has no saved NetworkManager profile, so the
    // password sheet can say "New network" instead of "wrong password".
    property bool wifiActionIsNew: false
    property string wifiConnectError: ""
    property string wifiCurrentPassword: ""
    property bool wifiPasswordRevealed: false
    property string wifiQrPath: ""
    // Saved (known) connection profile names, including ones currently out of
    // radio range. Lets the UI show "previously joined" networks even when
    // they don't appear in the live scan, and lets Forget work on them.
    property var wifiSavedProfiles: []
    readonly property var wifiDev: {
        var devs = Networking.devices.values;
        for (var i = 0; i < devs.length; ++i) {
            if (devs[i] && devs[i].type === DeviceType.Wifi)
                return devs[i];

        }
        return null;
    }
    // Backwards-compatible aliases some callers/tests may still reference.
    readonly property string wifiConnectingSsid: wifiPhase === phaseConnecting ? wifiActionSsid : ""
    readonly property string wifiPendingSsid: wifiPhase === phaseNeedsPassword ? wifiActionSsid : ""
    property string _detailMac: ""
    property string _detailBand: ""
    property var wifiConnectingNet: null
    property string _lastDetailName: ""

    function _sq(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

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
        var seen = {};
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
            seen[ssid] = true;
            list.push({
                "ssid": ssid,
                "signal": sig,
                "security": root._secLabel(net.security),
                "mac": connected ? root._detailMac : "",
                "band": connected ? root._detailBand : "",
                "active": connected,
                "known": net.known,
                "offline": false
            });
            if (connected)
                active = net;

        }
        // Saved profiles that are out of range right now still belong in the
        // "Saved networks" section — just marked offline, connect-on-tap will
        // retry them and Forget still works without needing a live scan hit.
        for (var j = 0; j < root.wifiSavedProfiles.length; ++j) {
            var name = root.wifiSavedProfiles[j];
            if (!name || seen[name])
                continue;

            list.push({
                "ssid": name,
                "signal": 0,
                "security": "",
                "mac": "",
                "band": "",
                "active": false,
                "known": true,
                "offline": true
            });
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
        wifiDetailProc.command = ["sh", "-c", "ip=$(nmcli -t -f IP4.ADDRESS device show " + root._sq(dev) + " 2>/dev/null | head -1 | cut -d: -f2- | cut -d/ -f1);" + "spd=$(iw dev " + root._sq(dev) + " link 2>/dev/null | grep -i 'tx bitrate' | grep -oE '[0-9.]+ MBit/s' | head -1);" + "mac=$(iw dev " + root._sq(dev) + " link 2>/dev/null | grep -i 'Connected to' | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | head -1);" + "freq=$(iw dev " + root._sq(dev) + " link 2>/dev/null | grep -i 'freq' | grep -oE '[0-9]+' | head -1);" + "band='';" + "if [ -n \"$freq\" ]; then if [ \"$freq\" -ge 5000 ]; then band='5 GHz'; else band='2.4 GHz'; fi; fi;" + "echo \"$ip|$spd|$mac|$band\""];
        wifiDetailProc.running = true;
    }

    function _refreshSavedProfiles() {
        savedProfilesProc.command = ["sh", "-c", "nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: '$2==\"802-11-wireless\"{print $1}'"];
        savedProfilesProc.running = true;
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
            root.wifiPhase = root.phaseIdle;
            root.wifiActionSsid = "";
            root.wifiConnectError = "";
            root.wifiPasswordRevealed = false;
        } else {
            root.scanWifi();
            root._refreshSavedProfiles();
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

    // Connects (or reconnects) to a network. Silent path for known/open
    // networks and for explicit passwords the caller already collected;
    // NetworkManager itself is the source of truth on whether a password was
    // actually required — see onConnectionFailed(NoSecrets) below, which is
    // the ONLY place that flips the phase to needs-password on our behalf.
    function connectToWifi(ssid, security, password) {
        var s = String(ssid || "");
        if (s.length === 0)
            return ;

        var pw = String(password || "");
        var net = root._findNet(s);
        var isKnownProfile = net ? net.known : root.wifiSavedProfiles.indexOf(s) >= 0;

        root.wifiConnectError = "";
        root.wifiActionSsid = s;
        root.wifiPendingSecurity = String(security || "");
        root.wifiActionIsNew = !isKnownProfile;
        root.wifiPhase = root.phaseConnecting;
        root.wifiConnectingNet = net;

        if (net) {
            if (pw.length > 0)
                net.connectWithPsk(pw);
            else
                net.connect();
        } else if (isKnownProfile) {
            // Saved profile that's currently out of scan range: bring the
            // existing connection profile up by name instead of re-scanning.
            hiddenConnProc.command = ["nmcli", "connection", "up", s];
            hiddenConnProc.running = true;
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

    function connectHidden(ssid, password) {
        root.connectToWifi(ssid, "", password);
    }

    // Cancels an in-flight connection attempt (e.g. user taps the spinning
    // row again to give up on a network that's taking too long).
    function cancelConnect() {
        root.connTimer.stop();
        root.wifiPhase = root.phaseIdle;
        root.wifiActionSsid = "";
        root.wifiConnectingNet = null;
    }

    function disconnectWifi() {
        var net = root._findConnected();
        if (net)
            net.disconnect();
        else if (root.wifiDev)
            root.wifiDev.disconnect();
        root.cancelConnect();
    }

    function forgetWifi(ssid) {
        var s = String(ssid || "");
        if (!s)
            return ;

        var net = root._findNet(s);
        if (net) {
            net.forget();
        } else {
            forgetProc.command = ["sh", "-c", "nmcli connection delete " + root._sq(s) + " 2>/dev/null"];
            forgetProc.running = true;
        }
        if (root.wifiActionSsid === s)
            root.cancelConnect();

        root.wifiSavedProfiles = root.wifiSavedProfiles.filter(function(n) {
            return n !== s;
        });
        root.scanWifi();
    }

    // Explicitly asks the user for a password up front — used when the UI
    // already knows (from `known`) that no saved secret exists.
    function requestPassword(ssid, security) {
        root.wifiActionSsid = ssid;
        root.wifiPendingSecurity = security || "";
        root.wifiConnectError = "";
        root.wifiActionIsNew = true;
        root.wifiPhase = root.phaseNeedsPassword;
    }

    function cancelPassword() {
        root.connTimer.stop();
        root.wifiPhase = root.phaseIdle;
        root.wifiActionSsid = "";
        root.wifiPendingSecurity = "";
        root.wifiConnectError = "";
        root.wifiConnectingNet = null;
    }

    function loadCurrentWifiPassword() {
        if (!root.wifiName || root.wifiName === "No network" || root.wifiName === "Off")
            return ;

        wifiPasswordProc.command = ["sh", "-c", "nmcli -s -g 802-11-wireless-security.psk connection show " + root._sq(root.wifiName) + " 2>/dev/null"];
        wifiPasswordProc.running = true;
    }

    function generateWifiQr() {
        if (!root.wifiCurrentPassword) {
            root.wifiQrPath = "";
            return ;
        }
        var sec = (root.wifiSecurity && root.wifiSecurity.length > 0) ? "WPA" : "nopass";
        var payload = "WIFI:T:" + sec + ";S:" + root.wifiName + ";P:" + root.wifiCurrentPassword + ";;";
        wifiQrProc.command = ["sh", "-c", "qrencode -t PNG -s 6 -o " + root._sq(Quickshell.cachePath("wifi-qr.png")) + " " + root._sq(payload)];
        wifiQrProc.running = true;
        root.wifiQrPath = "";
    }

    onWifiEnabledChanged: {
        if (root.wifiEnabled) {
            root.scanWifi();
            root._refreshSavedProfiles();
        } else {
            root._rebuild();
        }
    }
    onWifiDevChanged: root._rebuild()
    Component.onCompleted: {
        root._rebuild();
        if (root.wifiEnabled)
            root._refreshSavedProfiles();

    }

    // The one and only place a "wrong/expired password" prompt gets raised —
    // driven by NetworkManager's own failure reason, not guessed from UI state.
    Connections {
        function onConnectionFailed(reason) {
            if (reason === ConnectionFailReason.NoSecrets) {
                var ssid = root.wifiActionSsid;
                root.connTimer.stop();
                root.wifiConnectError = root.wifiActionIsNew ? "This network needs a password." : "Password is wrong or has changed. Re-enter it to update.";
                root.wifiActionSsid = ssid;
                root.wifiPhase = root.phaseNeedsPassword;
                root.wifiConnectingNet = null;
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
            if (root.wifiPhase !== root.phaseConnecting) {
                elapsed = 0;
                stop();
                return ;
            }
            var ssid = root.wifiActionSsid;
            if (!ssid) {
                elapsed = 0;
                stop();
                return ;
            }
            if (root.wifiName === ssid) {
                root.wifiConnectError = "";
                root.wifiPhase = root.phaseIdle;
                root.wifiActionSsid = "";
                root.wifiConnectingNet = null;
                elapsed = 0;
                stop();
                root.scanWifi();
                root._refreshSavedProfiles();
            } else {
                elapsed += interval;
                if (elapsed > 15000) {
                    root.wifiConnectError = "Couldn't connect to \"" + ssid + "\". It may be out of range.";
                    root.wifiPhase = root.phaseFailed;
                    root.wifiActionSsid = ssid;
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
                if (err.length === 0)
                    return ;

                var authLike = err.indexOf("secret") >= 0 || err.indexOf("password") >= 0 || err.indexOf("auth") >= 0 || err.indexOf("802-1x") >= 0 || err.indexOf("psk") >= 0;
                root.connTimer.stop();
                var ssid = root.wifiActionSsid;
                if (authLike) {
                    root.wifiConnectError = root.wifiActionIsNew ? "This network needs a password." : "Password is wrong or has changed. Re-enter it to update.";
                    root.wifiActionSsid = ssid;
                    root.wifiPhase = root.phaseNeedsPassword;
                } else {
                    root.wifiConnectError = "Couldn't connect to \"" + ssid + "\". " + ((err.indexOf("no network") >= 0 || err.indexOf("not found") >= 0) ? "It may be out of range." : "Please try again.");
                    root.wifiActionSsid = ssid;
                    root.wifiPhase = root.phaseFailed;
                }
            }
        }

    }

    Process {
        id: forgetProc

        command: ["sh", "-c", "true"]
    }

    Process {
        id: savedProfilesProc

        stdout: StdioCollector {
            onStreamFinished: {
                var names = (this.text || "").split("\n").map(function(s) {
                    return s.trim();
                }).filter(function(s) {
                    return s.length > 0;
                });
                root.wifiSavedProfiles = names;
                root._rebuild();
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
