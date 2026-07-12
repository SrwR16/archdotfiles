import "../overlay"
import "../services"
import "../theme"
import "../widgets"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

QtObject {
    id: root

    property int battery: 0
    property bool charging: false
    property string wifi: "Disconnected"
    property int wifiSignal: 0
    property string powerStatus: "Unknown"
    property string connType: "disconnected"
    readonly property string powerState: {
        var ps = powerStatus.toLowerCase();
        if (ps === "charging")
            return "Charging";

        if (ps === "full" || ps === "fully-charged")
            return "Full";

        return "Discharging";
    }
    readonly property string networkState: connType === "disconnected" ? "Disconnected" : "Connected"
    property Process batProc
    property Timer wifiTimer

    wifiTimer: Timer {
        id: wifiTimer

        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root._rebuildWifi()
    }

    // Wi-Fi / wired state from the native Quickshell.Networking API.
    function _rebuildWifi() {
        var wifiDev = null;
        var wiredDev = null;
        var devs = Networking.devices.values;
        for (var i = 0; i < devs.length; ++i) {
            var d = devs[i];
            if (!d)
                continue;

            if (d.type === DeviceType.Wifi)
                wifiDev = d;
            else if (d.type === DeviceType.Wired)
                wiredDev = d;
        }
        if (wifiDev) {
            var nets = wifiDev.networks.values;
            for (var j = 0; j < nets.length; ++j) {
                var net = nets[j];
                if (net && net.connected) {
                    wifi = net.name || "Disconnected";
                    wifiSignal = Math.round((net.signalStrength || 0) * 100);
                    connType = "wifi";
                    return ;
                }
            }
        }
        if (wiredDev && wiredDev.connected) {
            var wname = "Wired";
            var wnets = wiredDev.networks.values;
            for (var k = 0; k < wnets.length; ++k) {
                if (wnets[k] && wnets[k].connected) {
                    wname = wnets[k].name || wname;
                    break;
                }
            }
            wifi = wname;
            wifiSignal = 0;
            connType = "wired";
            return ;
        }
        wifi = "Disconnected";
        wifiSignal = 0;
        connType = "disconnected";
    }

    Component.onCompleted: root._rebuildWifi()

    batProc: Process {
        command: ["sh", "-c", "get_bat() { " + "  batdev=$(upower -e 2>/dev/null | grep -m1 battery); " + "  [ -z \"$batdev\" ] && batdev=\"/org/freedesktop/UPower/devices/DisplayDevice\"; " + "  upower -i \"$batdev\" 2>/dev/null | awk '/percentage:/ {p=$2} /state:/ {s=$2} END {gsub(/%/,\"\",p); print \"BAT:\" (p?p:0) \":\" (s?s:\"Unknown\")}'; " + "}; " + "get_bat; " + "dbus-monitor --system \"type='signal',interface='org.freedesktop.DBus.Properties'\" 2>/dev/null | while read -r line; do " + "  case \"$line\" in *member=PropertiesChanged*) sleep 0.1; get_bat;; esac; " + "done"]
        running: true

        stdout: SplitParser {
            onRead: (data) => {
                var line = data.trim();
                if (line.startsWith("BAT:")) {
                    var parts = line.substring(4).split(":");
                    if (parts.length >= 2) {
                        var parsedVal = parseInt(parts[0]);
                        if (!isNaN(parsedVal) && parsedVal >= 0 && parsedVal <= 100)
                            battery = parsedVal;

                        powerStatus = parts[1];
                        var st = powerStatus.toLowerCase();
                        charging = (st === "charging" || st === "full" || st === "fully-charged");
                    }
                }
            }
        }

    }

}
