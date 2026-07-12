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


    // --- Wi-Fi (delegated to its own service) ---
    property QtObject wifiSvc: WifiService {}

    // Periodic rescan while the Wi-Fi page is open (UI-visibility concern,
    // so it stays here rather than in the service).
    Timer {
        interval: 7000
        running: controlCenter.isOpen && controlCenter.page === "wifi" && controlCenter.wifiSvc.wifiEnabled
        repeat: true
        triggeredOnStart: true
        onTriggered: controlCenter.wifiSvc.scanWifi()
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

    // --- Backend services (each its own file under services/) ---
    property QtObject nightLightSvc: NightLightService {}
    property QtObject brightnessSvc: BrightnessService {}
    property QtObject playerSvc: PlayerService {}

    Component.onCompleted: {
        wifiSvc.refreshWifi();
        _syncAudioNodes();
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
                wifiEnabled: controlCenter.wifiSvc.wifiEnabled
                wifiName: controlCenter.wifiSvc.wifiName
                volumeIcon: controlCenter.volumeIcon
                audioVolume: controlCenter.audioVolume
                audioMuted: controlCenter.audioMuted
                audioSink: controlCenter.audioSink
                btAdapter: controlCenter.btAdapter
                nlEnabled: controlCenter.nightLightSvc.nlEnabled
                doNotDisturb: controlCenter.doNotDisturb
                brightnessIcon: controlCenter.brightnessSvc.brightnessIcon
                brightness: controlCenter.brightnessSvc.brightness
                activePlayer: controlCenter.playerSvc.activePlayer
                playerArt: controlCenter.playerSvc.playerArt
                storedNotifications: controlCenter.storedNotifications
                onNavigateTo: (p) => controlCenter.page = p
                onToggleWifi: controlCenter.wifiSvc.toggleWifi()
                onScanWifi: controlCenter.wifiSvc.scanWifi()
                onLoadCurrentWifiPassword: controlCenter.wifiSvc.loadCurrentWifiPassword()
                onToggleMute: controlCenter.toggleMute()
                onToggleBluetooth: controlCenter.toggleBluetooth()
                onToggleNightLight: controlCenter.nightLightSvc.toggleNightLight()
                onToggleDnd: { controlCenter.doNotDisturb = !controlCenter.doNotDisturb; controlCenter.dndToggled(controlCenter.doNotDisturb); }
                onSetVolume: (v) => controlCenter.setVolume(v)
                onSetBrightness: (v) => controlCenter.brightnessSvc.setBrightness(v)
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
                wifiEnabled: controlCenter.wifiSvc.wifiEnabled
                wifiName: controlCenter.wifiSvc.wifiName
                wifiSecurity: controlCenter.wifiSvc.wifiSecurity
                wifiIp: controlCenter.wifiSvc.wifiIp
                wifiSpeed: controlCenter.wifiSvc.wifiSpeed
                wifiSignal: controlCenter.wifiSvc.wifiSignal
                wifiNetworks: controlCenter.wifiSvc.wifiNetworks
                wifiScanning: controlCenter.wifiSvc.wifiScanning
                wifiPhase: controlCenter.wifiSvc.wifiPhase
                wifiActionSsid: controlCenter.wifiSvc.wifiActionSsid
                wifiPendingSecurity: controlCenter.wifiSvc.wifiPendingSecurity
                wifiActionIsNew: controlCenter.wifiSvc.wifiActionIsNew
                wifiConnectError: controlCenter.wifiSvc.wifiConnectError
                wifiCurrentPassword: controlCenter.wifiSvc.wifiCurrentPassword
                wifiPasswordRevealed: controlCenter.wifiSvc.wifiPasswordRevealed
                wifiQrPath: controlCenter.wifiSvc.wifiQrPath
                onToggleWifi: controlCenter.wifiSvc.toggleWifi()
                onScanWifi: controlCenter.wifiSvc.scanWifi()
                onConnectToWifi: (ssid, security, pw) => controlCenter.wifiSvc.connectToWifi(ssid, security, pw)
                onConnectHidden: (ssid, pw) => controlCenter.wifiSvc.connectToWifi(ssid, "", pw)
                onRequestPassword: (ssid, security) => controlCenter.wifiSvc.requestPassword(ssid, security)
                onCancelPassword: controlCenter.wifiSvc.cancelPassword()
                onCancelConnect: controlCenter.wifiSvc.cancelConnect()
                onDisconnectWifi: controlCenter.wifiSvc.disconnectWifi()
                onForgetWifi: (ssid) => controlCenter.wifiSvc.forgetWifi(ssid)
                onLoadCurrentWifiPassword: controlCenter.wifiSvc.loadCurrentWifiPassword()
                onGenerateWifiQr: controlCenter.wifiSvc.generateWifiQr()
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
               nlEnabled: controlCenter.nightLightSvc.nlEnabled
               nlMode: controlCenter.nightLightSvc.nlMode
               nlTemp: controlCenter.nightLightSvc.nlTemp
               nlDayTemp: controlCenter.nightLightSvc.nlDayTemp
               nlNightTemp: controlCenter.nightLightSvc.nlNightTemp
               onBackRequested: controlCenter.page = "main"
               onToggleNightLight: controlCenter.nightLightSvc.toggleNightLight()
               onSetNightLightTemp: (t) => controlCenter.nightLightSvc.setNightLightTemp(t)
               onSetNightLightMode: (mode) => controlCenter.nightLightSvc.setNightLightMode(mode)
               onSetNightLightAutoTemp: (d, n) => controlCenter.nightLightSvc.setNightLightAutoTemp(d, n)
               onApplyNightLight: controlCenter.nightLightSvc.applyNightLight()
               onSaveNightLight: controlCenter.nightLightSvc.saveNightLight()
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
