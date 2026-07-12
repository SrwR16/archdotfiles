import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications

import Quickshell.Bluetooth
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: controlCenter
    property bool isOpen: false
    visible: isOpen

    property string page: "main"
    onIsOpenChanged: if (isOpen) page = "main"

    signal closeRequested()
    signal dismissNotif(var notifRef)
    signal clearNotifs()
    signal dndToggled(bool val)
    property bool doNotDisturb: false
    property var storedNotifications: []

    implicitHeight: Math.min(controlCenter.page === "main"
      ? (mainPageItem ? mainPageItem.implicitHeight + 48 : 800)
      : 560, 880)

    // --- Audio (Pipewire) ---
    property PwNode audioSink: Pipewire.defaultAudioSink
    property PwNode audioSource: Pipewire.defaultAudioSource
    property bool audioMuted: !!audioSink?.audio?.muted
    property bool audioSourceMuted: !!audioSource?.audio?.muted
    property real audioVolume: Math.min(1, Math.max(0, audioSink?.audio?.volume ?? 0))
    property real audioSourceVolume: Math.min(1, Math.max(0, audioSource?.audio?.volume ?? 0))

    property var audioSinks: []
    property var audioSources: []

    function _addAudioNode(node) {
        if (!node || !node.ready) return;
        if (node.type === PwNodeType.AudioSink) {
            if (audioSinks.indexOf(node) !== -1) return;
            var s = audioSinks.slice();
            s.push(node);
            s.sort(function(a, b) { return (a.description || a.name || "").localeCompare(b.description || b.name || ""); });
            audioSinks = s;
        } else if (node.type === PwNodeType.AudioSource) {
            if (audioSources.indexOf(node) !== -1) return;
            var s2 = audioSources.slice();
            s2.push(node);
            s2.sort(function(a, b) { return (a.description || a.name || "").localeCompare(b.description || b.name || ""); });
            audioSources = s2;
        }
    }

    function _removeAudioNode(node) {
        if (!node) return;
        audioSinks = audioSinks.filter(function(n) { return n !== node; });
        audioSources = audioSources.filter(function(n) { return n !== node; });
    }

    // Bind the default audio sink/source so their volume/muted setters work
    PwObjectTracker {
        objects: [controlCenter.audioSink, controlCenter.audioSource]
    }

    // Listen to Pipewire node changes instead of polling every 500ms
    function _syncAudioNodes() {
        try {
            var allNodes = Pipewire.nodes.values;
            var nodes = [];
            for (var i = 0; i < allNodes.length; i++) {
                var n = allNodes[i];
                if (n && (n.type === PwNodeType.AudioSink || n.type === PwNodeType.AudioSource)) {
                    nodes.push(n);
                }
            }
            audioSinks = audioSinks.filter(function(n) { return nodes.indexOf(n) !== -1; });
            audioSources = audioSources.filter(function(n) { return nodes.indexOf(n) !== -1; });
            for (var i = 0; i < nodes.length; i++) {
                if (nodes[i] && nodes[i].ready) controlCenter._addAudioNode(nodes[i]);
            }
        } catch (e) {}
    }

    // Sync audio nodes only when ControlCenter is open
    Timer {
        interval: 2000; repeat: true; running: controlCenter.isOpen
        onTriggered: _syncAudioNodes()
    }

    function setAudioSourceVolume(vol) {
        if (audioSource?.ready && audioSource?.audio) {
            audioSource.audio.muted = false;
            audioSource.audio.volume = Math.max(0, Math.min(1, vol));
        }
    }

    function toggleAudioSourceMute() {
        if (audioSource?.ready && audioSource?.audio) {
            audioSource.audio.muted = !audioSource.audio.muted;
        }
    }

    function setDefaultSink(node) {
        if (node) Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultSource(node) {
        if (node) Pipewire.preferredDefaultAudioSource = node;
    }

    function setVolume(vol) {
        if (audioSink?.ready && audioSink?.audio) {
            audioSink.audio.muted = false;
            audioSink.audio.volume = Math.max(0, Math.min(1, vol));
        }
    }

    function toggleMute() {
        if (audioSink?.ready && audioSink?.audio) {
            audioSink.audio.muted = !audioSink.audio.muted;
        }
    }

    function volumeIcon(vol, muted) {
        if (muted || vol <= 0) return "󰝟";
        if (vol < 0.34) return "󰕿";
        if (vol < 0.67) return "󰖀";
        return "󰕾";
    }

    // --- Wi-Fi -----------------------------------------------------------------
    // Robust NetworkManager backend. Corner cases handled correctly:
    //  * Scanning never blocks the UI: request a rescan then read the cached
    //    list ~1.3s later (the old `--rescan yes` could hang StdioCollector).
    //  * SSIDs containing ':' are parsed by splitting SIGNAL/SECURITY/BSSID from
    //    the RIGHT and treating the remainder as the SSID. Fields are joined with
    //    the ASCII unit-separator (0x1F) so they survive any SSID content.
    //  * Switching networks always works: a live "connecting to <ssid>" state is
    //    tracked and success is confirmed by polling status (not just exit text).
    //  * Auth failures fall back to the password sheet with a clear message and
    //    let the user retry; saved-profile failures also prompt for a password.
    property bool wifiEnabled: true
    property string wifiName: "Disconnected"
    property string wifiSecurity: ""
    property string wifiIp: ""
    property string wifiSpeed: ""
    property string wifiDev: ""
    property var wifiNetworks: []
    property bool wifiScanning: false
    property var wifiKnownList: []

    property string wifiConnectingSsid: ""
    property string wifiConnectError: ""
    property string wifiPendingSsid: ""
    property string wifiPendingSecurity: ""
    property bool wifiShowPassword: false

    readonly property var _wifiSep: String.fromCharCode(31)

    function _wifiField(line, key) {
        var idx = line.indexOf(key + ":");
        if (idx < 0) return "";
        var rest = line.substring(idx + key.length + 1);
        var nxt = rest.indexOf("|");
        return nxt < 0 ? rest : rest.substring(0, nxt);
    }

    // Replay staggered entrance animations for a page (called when it becomes visible).
    function _replayEntrance(root) {
        if (!root) return;
        var stack = [root];
        while (stack.length) {
            var n = stack.pop();
            if (n.objectName === "entrance" && n.restart) n.restart();
            var ch = n.children;
            if (ch) for (var i = 0; i < ch.length; i++) stack.push(ch[i]);
        }
    }

    function _wifiParseStatus(text) {
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
            if (lines[i].indexOf("EN:") !== 0) continue;
            var en = controlCenter._wifiField(lines[i], "EN");
            var cur = controlCenter._wifiField(lines[i], "CUR");
            controlCenter.wifiEnabled = (en === "enabled");
            controlCenter.wifiIp = controlCenter._wifiField(lines[i], "IP");
            controlCenter.wifiSpeed = controlCenter._wifiField(lines[i], "SPD");
            controlCenter.wifiDev = controlCenter._wifiField(lines[i], "DEV");
            if (cur) {
                controlCenter.wifiName = cur;
                controlCenter.wifiSecurity = controlCenter._wifiField(lines[i], "SEC");
            } else if (controlCenter.wifiEnabled) {
                controlCenter.wifiName = "No network";
                controlCenter.wifiSecurity = "";
            } else {
                controlCenter.wifiName = "Off";
                controlCenter.wifiSecurity = "";
            }
        }
    }

    Process {
        id: wifiStatusProc
        command: ["sh", "-c",
            "en=$(nmcli -t -f WIFI radio 2>/dev/null); " +
            "cur=$(nmcli -t -f TYPE,NAME con show --active 2>/dev/null | grep '^802-11-wireless:' | cut -d: -f2-); " +
            "dev=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2==\"wifi\"{print $1; exit}'); " +
            "ip=''; spd=''; sec=''; " +
            "if [ -n \"$dev\" ] && [ -n \"$cur\" ]; then " +
            "  ip=$(nmcli -t -f IP4.ADDRESS device show \"$dev\" 2>/dev/null | head -1 | cut -d: -f2- | cut -d/ -f1); " +
            "  spd=$(iw dev \"$dev\" link 2>/dev/null | grep -i 'tx bitrate' | grep -oE '[0-9.]+ MBit/s' | head -1); " +
            "  sec=$(nmcli -t -f IN-USE,SECURITY dev wifi 2>/dev/null | grep '^*' | cut -d: -f2-); " +
            "fi; " +
            "echo \"EN:$en|CUR:$cur|IP:$ip|SPD:$spd|SEC:$sec|DEV:$dev\""]
        stdout: StdioCollector { onStreamFinished: controlCenter._wifiParseStatus(this.text) }
    }

    function refreshWifi() { wifiStatusProc.running = true; }

    Process { id: wifiToggleProc }
    Timer { id: wifiRefreshDelay; interval: 700; onTriggered: refreshWifi() }

    function toggleWifi() {
        var turningOff = wifiEnabled;
        wifiToggleProc.command = ["nmcli", "radio", "wifi", turningOff ? "off" : "on"];
        wifiToggleProc.running = true;
        wifiEnabled = !wifiEnabled;
        if (turningOff) {
            wifiName = "Off"; wifiSecurity = ""; wifiIp = ""; wifiSpeed = "";
            wifiNetworks = []; wifiConnectingSsid = ""; wifiPendingSsid = ""; wifiShowPassword = false;
        }
        wifiRefreshDelay.start();
        if (!turningOff) controlCenter.scanWifi();
    }

    Process { id: wifiRescanProc; command: ["nmcli", "dev", "wifi", "rescan"] }

    Process {
        id: wifiScanProc
        command: ["sh", "-c",
            "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY,BSSID,FREQ dev wifi list 2>/dev/null | while IFS= read -r line; do " +
            "  [ -z \"$line\" ] && continue; " +
            "  iu=${line%%:*}; r=${line#*:}; " +
            "  freq=${r##*:}; r=${r%:*}; " +
            "  mac=${r##*:}; r=${r%:*}; " +
            "  sec=${r##*:}; r=${r%:*}; " +
            "  sig=${r##*:}; r=${r%:*}; " +
            "  ssid=${r%:*}; " +
            "  [ -z \"$ssid\" ] && continue; " +
            "  printf '%s\\037%s\\037%s\\037%s\\037%s\\037%s\\n' \"$iu\" \"$sig\" \"$sec\" \"$mac\" \"$freq\" \"$ssid\"; " +
            "done"]
        stdout: StdioCollector { onStreamFinished: controlCenter._wifiParseScan(this.text) }
    }

    function _wifiParseScan(text) {
        var lines = text.split("\n");
        var seen = {};
        var list = [];
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i].trim();
            if (!l) continue;
            var f = l.split(controlCenter._wifiSep);
            if (f.length < 6) continue;
            var inUse = f[0] === "*";
            var signal = parseInt(f[1]) || 0;
            var security = f[2];
            var mac = f[3];
            var freq = parseInt(f[4]) || 0;
            var ssid = f[5];
            if (!ssid || seen[ssid]) continue;
            seen[ssid] = true;
            var band = freq >= 5000 ? "5 GHz" : (freq > 0 ? "2.4 GHz" : "");
            list.push({
                ssid: ssid,
                signal: signal,
                security: security,
                mac: mac,
                band: band,
                active: inUse,
                known: controlCenter.wifiKnownList.indexOf(ssid) >= 0
            });
        }
        list.sort(function (a, b) { return b.signal - a.signal; });
        controlCenter.wifiNetworks = list;
        controlCenter.wifiScanning = false;
    }

    Timer { id: wifiScanDelay; interval: 1300; onTriggered: wifiScanProc.running = true }

    function scanWifi() {
        if (!wifiEnabled) { wifiScanning = false; return; }
        wifiScanning = true;
        refreshKnown();
        wifiRescanProc.running = true;
        wifiScanDelay.restart();
    }

    Process {
        id: wifiKnownProc
        command: ["sh", "-c", "nmcli -t -f NAME connection show 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                controlCenter.wifiKnownList = this.text.split("\n")
                    .map(function (s) { return s.trim(); })
                    .filter(function (s) { return s.length > 0; });
            }
        }
    }
    function refreshKnown() { wifiKnownProc.running = true; }

    Timer {
        interval: 7000
        running: controlCenter.isOpen && controlCenter.page === "wifi" && wifiEnabled
        repeat: true
        triggeredOnStart: true
        onTriggered: controlCenter.scanWifi()
    }

    // --- Connect flow (robust: `nmcli device wifi connect` handles saved / unknown
    //     credentials AND auto-switches away from the currently connected network) ---
    function connectToWifi(ssid, security, password) {
        if (!ssid) return;
        controlCenter.wifiConnectError = "";
        controlCenter.wifiConnectingSsid = ssid;
        controlCenter.wifiPendingSsid = ssid;
        controlCenter.wifiPendingSecurity = security || "";
        if (password && String(password).length > 0) {
            controlCenter.wifiShowPassword = true;
            controlCenter.wifiConnectProc.command = ["nmcli", "device", "wifi", "connect", ssid, "password", password];
        } else {
            controlCenter.wifiConnectProc.command = ["nmcli", "device", "wifi", "connect", ssid];
        }
        controlCenter.wifiConnectProc.running = true;
        controlCenter.wifiConnectPoll.restart();
    }

    Process {
        id: wifiConnectProc
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                var err = (this.text || "").toLowerCase();
                if (err.indexOf("error") >= 0 || err.indexOf("fail") >= 0
                        || err.indexOf("secret") >= 0 || err.indexOf("secrets") >= 0) {
                    // Missing / wrong credentials: keep the password sheet open.
                    controlCenter.wifiConnectError = "This network needs a password.";
                    controlCenter.wifiConnectingSsid = "";
                    controlCenter.wifiShowPassword = true;
                }
                // Success is confirmed by the status poll, not by exit text.
            }
        }
    }

    // Poll status while connecting: confirm success, or time out.
    Timer {
        id: wifiConnectPoll
        interval: 1000
        repeat: true
        property int elapsed: 0
        onTriggered: {
            controlCenter.refreshWifi();
            if (!controlCenter.wifiConnectingSsid) { elapsed = 0; stop(); return; }
            elapsed += interval;
            if (controlCenter.wifiName === controlCenter.wifiConnectingSsid) {
                controlCenter.wifiConnectError = "";
                controlCenter.wifiPendingSsid = "";
                controlCenter.wifiConnectingSsid = "";
                controlCenter.wifiShowPassword = false;
                elapsed = 0; stop();
                controlCenter.scanWifi();
            } else if (elapsed > 15000) {
                if (!controlCenter.wifiShowPassword)
                    controlCenter.wifiConnectError = "Connection timed out.";
                controlCenter.wifiConnectingSsid = "";
                elapsed = 0; stop();
            }
        }
        onRunningChanged: elapsed = 0
    }

    function disconnectWifi() {
        if (!wifiName || wifiName === "No network" || wifiName === "Off") return;
        wifiDisconnectProc.command = ["sh", "-c",
            "nmcli con down id " + JSON.stringify(wifiName) + " 2>/dev/null || " +
            "(dev=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2==\"wifi\"{print $1; exit}'); " +
            "[ -n \"$dev\" ] && nmcli dev disconnect \"$dev\")"];
        wifiDisconnectProc.running = true;
        wifiRefreshDelay.start();
    }
    Process { id: wifiDisconnectProc }

    function forgetWifi(ssid) {
        if (!ssid) return;
        forgetProc.command = ["nmcli", "connection", "delete", "id", ssid];
        forgetProc.running = true;
        if (controlCenter.wifiPendingSsid === ssid) { controlCenter.wifiPendingSsid = ""; controlCenter.wifiShowPassword = false; }
        wifiRefreshDelay.start();
    }
    Process { id: forgetProc }

    function requestPassword(ssid, security) {
        controlCenter.wifiPendingSsid = ssid;
        controlCenter.wifiPendingSecurity = security || "";
        controlCenter.wifiShowPassword = true;
        controlCenter.wifiConnectError = "";
    }

    function cancelPassword() {
        wifiPendingSsid = "";
        wifiShowPassword = false;
        wifiConnectError = "";
        wifiConnectingSsid = "";
    }

    property string wifiCurrentPassword: ""
    property bool wifiPasswordRevealed: false
    property string wifiQrPath: ""

    Process {
        id: wifiPasswordProc
        stdout: StdioCollector {
            onStreamFinished: { controlCenter.wifiCurrentPassword = this.text.trim(); }
        }
    }

    function loadCurrentWifiPassword() {
        if (!wifiName || wifiName === "No network" || wifiName === "Off") return;
        wifiPasswordProc.command = ["sh", "-c", `nmcli -s -g 802-11-wireless-security.psk connection show '${wifiName.replace(/'/g, "'\\''")}' 2>/dev/null`];
        wifiPasswordProc.running = true;
    }

    Process {
        id: wifiQrProc
        command: ["sh", "-c", "true"]
    }

    Connections {
        target: wifiQrProc
        function onExited() {
            var p = Quickshell.cachePath("wifi-qr.png");
            controlCenter.wifiQrPath = "file://" + p;
        }
    }

    function generateWifiQr() {
        if (!wifiCurrentPassword) { wifiQrPath = ""; return; }
        const security = wifiSecurity && wifiSecurity !== "--" ? "WPA" : "nopass";
        const payload = `WIFI:T:${security};S:${wifiName};P:${wifiCurrentPassword};;`;
        const escaped = payload.replace(/'/g, "'\\''");
        wifiQrProc.command = ["sh", "-c", `qrencode -t PNG -s 6 -o '${Quickshell.cachePath("wifi-qr.png")}' '${escaped}'`];
        wifiQrProc.running = true;
        wifiQrPath = "";
    }

    // --- Bluetooth ---
    readonly property BluetoothAdapter btAdapter: Bluetooth.defaultAdapter
    readonly property var btDevices: btAdapter ? btAdapter.devices.values : []

    function toggleBluetooth() {
        if (btAdapter) btAdapter.enabled = !btAdapter.enabled;
    }

    property bool btScanning: false
    onBtAdapterChanged: { if (!btAdapter) { btScanning = false; } }
    Connections {
        target: controlCenter.btAdapter
        enabled: !!controlCenter.btAdapter
        function onDiscoveringChanged() {
            if (controlCenter.btAdapter && !controlCenter.btAdapter.discovering)
                controlCenter.btScanning = false;
        }
        function onEnabledChanged() {
            if (controlCenter.btAdapter && !controlCenter.btAdapter.enabled)
                controlCenter.btScanning = false;
        }
    }

    function btDeviceSubtitle(dev) {
        if (dev.state === BluetoothDeviceState.Connected) {
            if (dev.batteryAvailable) return "Connected · " + Math.round(dev.battery * 100) + "%";
            return "Connected";
        }
        if (dev.state === BluetoothDeviceState.Connecting) return "Connecting…";
        if (dev.pairing) return "Pairing…";
        if (dev.paired) return "Paired";
        return "Available";
    }

    function toggleBtConnection(dev) {
        if (dev.state === BluetoothDeviceState.Connected) {
            dev.disconnect();
        } else {
            dev.connect();
        }
    }

    function toggleBtScan() {
        if (!btAdapter) return;
        btScanning = !btScanning;
        btAdapter.discovering = btScanning;
    }

    function pairDevice(dev) {
        dev.pair();
    }

    function forgetDevice(dev) {
        if (dev.state === BluetoothDeviceState.Connected)
            dev.disconnect();
        dev.forget();
    }

    // --- Mode Service ---
    property var modeSvc: null

    // --- Night Light ---
    property string nlStatePath: Quickshell.shellPath("scripts/night-light-state.json")
    property bool nlEnabled: false
    property string nlMode: "manual"
    property int nlTemp: 4500
    property int nlDayTemp: 6500
    property int nlNightTemp: 3500

    FileView {
        id: nlStateFile
        path: controlCenter.nlStatePath
        Component.onCompleted: {
            var raw = nlStateFile.text().trim();
            if (!raw) return;
            try {
                var s = JSON.parse(raw);
                controlCenter.nlEnabled = s.enabled || false;
                controlCenter.nlMode = s.mode || "manual";
                controlCenter.nlTemp = s.temperature || 4500;
                controlCenter.nlDayTemp = s.dayTemp || 6500;
                controlCenter.nlNightTemp = s.nightTemp || 3500;
            } catch (e) {}
            controlCenter._applyNightLight();
        }
    }

    function _applyNightLight() {
        if (!nlEnabled) {
            nlProc.command = [Quickshell.shellPath("scripts/nightlight.sh"), "off"];
        } else if (nlMode === "auto") {
            nlProc.command = [
                Quickshell.shellPath("scripts/nightlight.sh"), "auto",
                String(nlDayTemp), String(nlNightTemp)
            ];
        } else {
            nlProc.command = [
                Quickshell.shellPath("scripts/nightlight.sh"), "manual",
                String(nlTemp)
            ];
        }
        nlProc.running = true;
    }

    function _saveNightLight() {
        var s = JSON.stringify({
            enabled: nlEnabled,
            mode: nlMode,
            temperature: nlTemp,
            dayTemp: nlDayTemp,
            nightTemp: nlNightTemp
        });
        nlSaveProc.command = ["sh", "-c",
            "mkdir -p $(dirname \"" + controlCenter.nlStatePath + "\") && " +
            "printf '%s\\n' \"" + s.replace(/\"/g, '\\"') + "\" > \"" + controlCenter.nlStatePath + ".tmp\" && " +
            "mv -f \"" + controlCenter.nlStatePath + ".tmp\" \"" + controlCenter.nlStatePath + "\""
        ];
        nlSaveProc.running = true;
    }

    function toggleNightLight() {
        nlEnabled = !nlEnabled;
        _applyNightLight();
        _saveNightLight();
    }

    function setNightLightTemp(temp) {
        nlTemp = Math.max(1000, Math.min(8000, temp));
        if (nlEnabled && nlMode === "manual") {
            _applyNightLight();
        }
        _saveNightLight();
    }

    function setNightLightAutoTemp(day, night) {
        nlDayTemp = Math.max(1000, Math.min(8000, day));
        nlNightTemp = Math.max(1000, Math.min(8000, night));
        if (nlEnabled && nlMode === "auto") {
            _applyNightLight();
        }
        _saveNightLight();
    }

    Process { id: nlProc }
    Process { id: nlSaveProc }

    // --- Brightness ---
    property real brightness: 0.8
    property string backlightDevice: ""

    Process {
        id: backlightDetectProc
        command: ["sh", "-c", "ls /sys/class/backlight 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const name = this.text.trim();
                if (name) controlCenter.backlightDevice = name;
            }
        }
    }

    FileView {
        id: brightnessCurrentFile
        path: controlCenter.backlightDevice
            ? `/sys/class/backlight/${controlCenter.backlightDevice}/brightness`
            : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: controlCenter.syncBrightnessFromSysfs()
        onTextChanged: controlCenter.syncBrightnessFromSysfs()
    }

    FileView {
        id: brightnessMaxFile
        path: controlCenter.backlightDevice
            ? `/sys/class/backlight/${controlCenter.backlightDevice}/max_brightness`
            : ""
    }

    function syncBrightnessFromSysfs() {
        const cur = parseInt(brightnessCurrentFile.text());
        const max = parseInt(brightnessMaxFile.text());
        if (!isNaN(cur) && !isNaN(max) && max > 0) {
            brightness = cur / max;
        }
    }

    function setBrightness(val) {
        brightness = Math.max(0, Math.min(1, val));
        brightnessSetProc.command = ["brightnessctl", "set", Math.round(brightness * 100) + "%"];
        brightnessSetProc.running = true;
        hwMonitor.refresh();
    }

    Process { id: brightnessSetProc }

    function brightnessIcon(val) {
        if (val < 0.34) return "󰃞";
        if (val < 0.67) return "󰃟";
        return "󰃠";
    }

    // --- Media player (playerctl) ---
    property QtObject activePlayer: playerctlData

    property string playerArt: ""

    property var playerctlData: QtObject {
        property string identity: "Media Player"
        property string trackTitle: ""
        property string trackArtist: ""
        property string artUrl: ""
        property bool isPlaying: false
        property real position: 0
        property real length: 1

        function previous() {
            playerctlCmd.command = ["playerctl", "--player=playerctld", "previous"]
            playerctlCmd.running = true
        }
        function togglePlaying() {
            playerctlCmd.command = ["playerctl", "--player=playerctld", "play-pause"]
            playerctlCmd.running = true
        }
        function next() {
            playerctlCmd.command = ["playerctl", "--player=playerctld", "next"]
            playerctlCmd.running = true
        }

        function fetch() {
            metaProc.running = false
            metaProc.command = [
                "playerctl", "--player=playerctld", "metadata",
                "--format",
                "{{title}}|~|{{artist}}|~|{{mpris:artUrl}}|~|{{xesam:url}}|~|{{mpris:length}}|~|{{mpris:position}}"
            ]
            metaProc.running = true
        }
    }

    property Process playerctlCmd: Process { command: ["true"]; running: false }

    property Process playerctlStatusProc: Process {
        command: ["playerctl", "--player=playerctld", "status", "--follow"]
        running: true
        stdout: SplitParser {
            onRead: (data) => {
                var s = data.trim()
                if (s !== "Playing" && s !== "Paused") {
                    playerctlData.isPlaying = false
                    playerctlData.trackTitle = ""
                    playerctlData.trackArtist = ""
                    playerctlData.artUrl = ""
                    playerArt = ""
                } else {
                    playerctlData.isPlaying = s === "Playing"
                    playerctlData.fetch()
                }
            }
        }
    }

    property Process metaProc: Process {
        command: ["true"]
        running: false
        stdout: SplitParser {
            onRead: (data) => {
                var parts = data.trim().split("|~|")
                if (parts.length < 6) return
                playerctlData.trackTitle = parts[0] || ""
                playerctlData.trackArtist = parts[1] || ""
                var artUrl = parts[2] || ""
                var pageUrl = parts[3] || ""
                var len = parseFloat(parts[4]) || 0
                var pos = parseFloat(parts[5]) || 0
                playerctlData.length = len > 0 ? len / 1000000 : 1
                playerctlData.position = pos > 0 ? pos / 1000000 : 0
                var newArt = ""
                if (artUrl.startsWith("/"))
                    newArt = "file://" + artUrl
                else if (artUrl)
                    newArt = artUrl
                else if (pageUrl) {
                    var m = pageUrl.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})/)
                    if (m) newArt = "https://img.youtube.com/vi/" + m[1] + "/hqdefault.jpg"
                }
                playerctlData.artUrl = newArt
                if (newArt) playerArt = newArt
            }
        }
    }

    Component.onCompleted: {
        refreshWifi();
        _syncAudioNodes();
        backlightDetectProc.running = true;
        nlStateFile.reload();
    }

    // ---- Inline components ----


    // ---- Panel ----
    Item {
        id: panel
        anchors.fill: parent
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            // ---- HEADER (Hidden on Main Page) ----
            Item {
                Layout.fillWidth: true
                implicitHeight: headerRow.implicitHeight
                visible: controlCenter.page !== "main"

                RowLayout {
                    id: headerRow
                    anchors.fill: parent
                    spacing: 8

                    Text {
                        text: "󰅁"
                        color: Theme.text
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
                    }

                    Text {
                        text: controlCenter.page === "wifi" ? "Wi-Fi"
                            : controlCenter.page === "bluetooth" ? "Bluetooth"
                            : controlCenter.page === "audio" ? "Audio"
                            : controlCenter.page === "nightlight" ? "Night Light"
                            : controlCenter.page === "mode" ? "Performance Mode"
                            : ""
                        color: Theme.text
                        font { family: "Inter"; pixelSize: 15; weight: 700 }
                        Layout.fillWidth: true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (controlCenter.page !== "main") controlCenter.page = "main";
                        else controlCenter.closeRequested();
                    }
                }
            }

            MainPage {
                id: mainPageItem
                visible: controlCenter.page === "main"
                onVisibleChanged: { if (visible) controlCenter._replayEntrance(mainPageItem); }
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
                page: controlCenter.page
                modeSvc: controlCenter.modeSvc
                wifiEnabled: controlCenter.wifiEnabled
                wifiName: controlCenter.wifiName
                volumeIcon: controlCenter.volumeIcon
                audioVolume: controlCenter.audioVolume
                audioMuted: controlCenter.audioMuted
                audioSink: controlCenter.audioSink
                btAdapter: controlCenter.btAdapter
                nlEnabled: controlCenter.nlEnabled
                doNotDisturb: controlCenter.doNotDisturb
                brightnessIcon: controlCenter.brightnessIcon
                brightness: controlCenter.brightness
                activePlayer: controlCenter.activePlayer
                playerArt: controlCenter.playerArt
                storedNotifications: controlCenter.storedNotifications
                onNavigateTo: (p) => controlCenter.page = p
                onToggleWifi: controlCenter.toggleWifi()
                onScanWifi: controlCenter.scanWifi()
                onLoadCurrentWifiPassword: controlCenter.loadCurrentWifiPassword()
                onToggleMute: controlCenter.toggleMute()
                onToggleBluetooth: controlCenter.toggleBluetooth()
                onToggleNightLight: controlCenter.toggleNightLight()
                onToggleDnd: { controlCenter.doNotDisturb = !controlCenter.doNotDisturb; controlCenter.dndToggled(controlCenter.doNotDisturb); }
                onSetVolume: (v) => controlCenter.setVolume(v)
                onSetBrightness: (v) => controlCenter.setBrightness(v)
                onDismissNotif: (n) => controlCenter.dismissNotif(n)
                onClearNotifs: controlCenter.clearNotifs()
            }

            WifiPage {
                id: wifiPageItem
                visible: controlCenter.page === "wifi"
                onVisibleChanged: { if (visible) controlCenter._replayEntrance(wifiPageItem); }
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                wifiEnabled: controlCenter.wifiEnabled
                wifiName: controlCenter.wifiName
                wifiSecurity: controlCenter.wifiSecurity
                wifiIp: controlCenter.wifiIp
                wifiSpeed: controlCenter.wifiSpeed
                wifiNetworks: controlCenter.wifiNetworks
                wifiScanning: controlCenter.wifiScanning
                wifiConnectingSsid: controlCenter.wifiConnectingSsid
                wifiPendingSsid: controlCenter.wifiPendingSsid
                wifiPendingSecurity: controlCenter.wifiPendingSecurity
                wifiConnectError: controlCenter.wifiConnectError
                wifiCurrentPassword: controlCenter.wifiCurrentPassword
                wifiPasswordRevealed: controlCenter.wifiPasswordRevealed
                wifiQrPath: controlCenter.wifiQrPath
                onToggleWifi: controlCenter.toggleWifi()
                onScanWifi: controlCenter.scanWifi()
                onConnectToWifi: (ssid, security, pw) => controlCenter.connectToWifi(ssid, security, pw)
                onConnectHidden: (ssid, pw) => controlCenter.connectToWifi(ssid, "", pw)
                onRequestPassword: (ssid, security) => controlCenter.requestPassword(ssid, security)
                onCancelPassword: controlCenter.cancelPassword()
                onDisconnectWifi: controlCenter.disconnectWifi()
                onForgetWifi: (ssid) => controlCenter.forgetWifi(ssid)
                onLoadCurrentWifiPassword: controlCenter.loadCurrentWifiPassword()
                onGenerateWifiQr: controlCenter.generateWifiQr()
                onBackRequested: controlCenter.page = "main"
            }

            // ---- BLUETOOTH PAGE ----
            BluetoothPage {
              id: btPageItem
              visible: controlCenter.page === "bluetooth"
              onVisibleChanged: { if (visible) controlCenter._replayEntrance(btPageItem); }
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true
              btAdapter: controlCenter.btAdapter
              btDevices: controlCenter.btDevices
              btScanning: controlCenter.btScanning
              btDeviceSubtitle: controlCenter.btDeviceSubtitle
              onToggleBluetooth: controlCenter.toggleBluetooth()
              onToggleBtScan: controlCenter.toggleBtScan()
              onForgetDevice: (device) => controlCenter.forgetDevice(device)
              onPairDevice: (device) => controlCenter.pairDevice(device)
              onToggleBtConnection: (device) => controlCenter.toggleBtConnection(device)
              onBackRequested: controlCenter.page = "main"
            }

            // ---- AUDIO PAGE ----
            AudioPage {
              id: audioPageItem
              visible: controlCenter.page === "audio"
              onVisibleChanged: { if (visible) controlCenter._replayEntrance(audioPageItem); }
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true
              audioSinks: controlCenter.audioSinks
              audioSink: controlCenter.audioSink
              audioSources: controlCenter.audioSources
              audioSource: controlCenter.audioSource
              audioVolume: controlCenter.audioVolume
              audioMuted: controlCenter.audioMuted
              audioSourceVolume: controlCenter.audioSourceVolume
              audioSourceMuted: controlCenter.audioSourceMuted
              volumeIcon: controlCenter.volumeIcon
              onBackRequested: controlCenter.page = "main"
              onSetVolume: (v) => controlCenter.setVolume(v)
              onToggleMute: controlCenter.toggleMute()
              onSetAudioSourceVolume: (v) => controlCenter.setAudioSourceVolume(v)
              onToggleAudioSourceMute: controlCenter.toggleAudioSourceMute()
              onSetDefaultSink: (n) => controlCenter.setDefaultSink(n)
              onSetDefaultSource: (n) => controlCenter.setDefaultSource(n)
            }

            // ---- NIGHT LIGHT PAGE ----
            NightLightPage {
              id: nlPageItem
              visible: controlCenter.page === "nightlight"
              onVisibleChanged: { if (visible) controlCenter._replayEntrance(nlPageItem); }
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true
              nlEnabled: controlCenter.nlEnabled
              nlMode: controlCenter.nlMode
              nlTemp: controlCenter.nlTemp
              nlDayTemp: controlCenter.nlDayTemp
              nlNightTemp: controlCenter.nlNightTemp
              onBackRequested: controlCenter.page = "main"
              onToggleNightLight: controlCenter.toggleNightLight()
              onSetNightLightTemp: (t) => controlCenter.setNightLightTemp(t)
              onSetNightLightMode: (mode) => { controlCenter.nlMode = mode; if (controlCenter.nlEnabled) controlCenter._applyNightLight(); controlCenter._saveNightLight(); }
              onSetNightLightAutoTemp: (d, n) => controlCenter.setNightLightAutoTemp(d, n)
              onApplyNightLight: controlCenter._applyNightLight()
              onSaveNightLight: controlCenter._saveNightLight()
            }

            // ---- MODE PAGE ----
            ModePage {
              id: modePageItem
              visible: controlCenter.page === "mode"
              onVisibleChanged: { if (visible) controlCenter._replayEntrance(modePageItem); }
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true
              currentMode: controlCenter.modeSvc ? controlCenter.modeSvc.currentMode : "balanced"
              cpuTemp: controlCenter.modeSvc ? controlCenter.modeSvc.cpuTemp : 0
              onSetMode: (m) => { if (controlCenter.modeSvc) controlCenter.modeSvc.setMode(m); }
              onBackRequested: controlCenter.page = "main"
            }
        }
    }

}
