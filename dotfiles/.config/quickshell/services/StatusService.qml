import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
  property int battery: 0
  property bool charging: false
  property string wifi: "Disconnected"
  property int wifiSignal: 0
  property string powerStatus: "Unknown"
  property string connType: "disconnected"

  readonly property string powerState: {
    var ps = powerStatus.toLowerCase();
    if (ps === "charging") return "Charging";
    if (ps === "full" || ps === "fully-charged") return "Full";
    return "Discharging";
  }

  readonly property string networkState: connType === "disconnected" ? "Disconnected" : "Connected"

  property Process batProc: Process {
    command: [
      "sh", "-c",
      "get_bat() { " +
      "  batdev=$(upower -e 2>/dev/null | grep -m1 battery); " +
      "  [ -z \"$batdev\" ] && batdev=\"/org/freedesktop/UPower/devices/DisplayDevice\"; " +
      "  upower -i \"$batdev\" 2>/dev/null | awk '/percentage:/ {p=$2} /state:/ {s=$2} END {gsub(/%/,\"\",p); print \"BAT:\" (p?p:0) \":\" (s?s:\"Unknown\")}'; " +
      "}; " +
      "get_bat; " +
      "dbus-monitor --system \"type='signal',interface='org.freedesktop.DBus.Properties'\" 2>/dev/null | while read -r line; do " +
      "  case \"$line\" in *member=PropertiesChanged*) sleep 0.1; get_bat;; esac; " +
      "done"
    ]
    running: true
    stdout: SplitParser {
      onRead: (data) => {
        var line = data.trim();
        if (line.startsWith("BAT:")) {
          var parts = line.substring(4).split(":");
          if (parts.length >= 2) {
            var parsedVal = parseInt(parts[0]);
            if (!isNaN(parsedVal) && parsedVal >= 0 && parsedVal <= 100) {
              battery = parsedVal;
            }
            powerStatus = parts[1];
            var st = powerStatus.toLowerCase();
            charging = (st === "charging" || st === "full" || st === "fully-charged");
          }
        }
      }
    }
  }

  property Process wifiProc: Process {
    command: [
      "sh", "-c",
      "while true; do " +
      "  types=$(nmcli -t -f TYPE,NAME con show --active 2>/dev/null); " +
      "  ssid=$(echo \"$types\" | grep '^802-11-wireless:' | cut -d: -f2 -s); " +
      "  [ -z \"$ssid\" ] && ssid=$(iwgetid -r 2>/dev/null); " +
      "  eth=$(echo \"$types\" | grep '^802-3-ethernet:' | cut -d: -f2 -s); " +
      "  ctype=disconnected; " +
      "  [ -n \"$ssid\" ] && ctype=wifi; " +
      "  [ -z \"$ssid\" ] && [ -n \"$eth\" ] && { ssid=\"$eth\"; ctype=wired; }; " +
      "  [ -z \"$ssid\" ] && ssid=Disconnected; " +
      "  sig=$(awk 'NR>2{if($3!=\"\"){gsub(/\\./,\"\",$3); q=$3+0; print int(q*100/70)}}' /proc/net/wireless 2>/dev/null || echo 0); " +
      "  echo \"WIFI:$ssid:$sig:$ctype\"; " +
      "  sleep 5; " +
      "done"
    ]
    running: true
    stdout: SplitParser {
      onRead: (data) => {
        var line = data.trim();
        if (line.startsWith("WIFI:")) {
          var parts = line.split(":");
          if (parts.length >= 4) {
            wifi = parts.slice(1, parts.length - 2).join(":");
            wifiSignal = parseInt(parts[parts.length - 2]);
            connType = parts[parts.length - 1];
          }
        }
      }
    }
  }
}
