import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool isActive: false
    property string tunnelType: ""
    property string publicIp: "Checking..."
    property string latency: "..."

    Process {
        id: vpnMonitor
        running: true
        command: [
            "stdbuf", "-oL",
            "sh", "-c",
            "while true; do " +
            "  type=\"\"; " +
            "  if ip link show type wireguard 2>/dev/null | grep -q 'wireguard'; then type=\"WireGuard\"; " +
            "  elif ip link show type tun 2>/dev/null | grep -q 'tun'; then type=\"OpenVPN\"; " +
            "  elif pgrep ssh >/dev/null; then type=\"SSH Tunnel\"; fi; " +
            "  if [ -n \"$type\" ]; then " +
            "    echo \"UP|$type\"; " +
            "  else " +
            "    echo \"DOWN\"; " +
            "  fi; " +
            "  sleep 3; " +
            "done"
        ]
        stdout: SplitParser {
            onRead: (data) => {
                var parts = data.trim().split("|");
                if (parts[0] === "UP") {
                    root.isActive = true;
                    root.tunnelType = parts[1];
                    // Trigger fetch if not already fetching
                    if (!ipFetcher.running) ipFetcher.running = true;
                } else {
                    root.isActive = false;
                    root.tunnelType = "";
                    root.publicIp = "Checking...";
                    root.latency = "...";
                }
            }
        }
    }

    Timer {
        interval: 30000
        running: root.isActive
        repeat: true
        onTriggered: ipFetcher.running = true
    }

    Process {
        id: ipFetcher
        running: false
        command: [
            "sh", "-c",
            "ip=$(curl -s --max-time 3 ifconfig.me || echo 'Unknown'); " +
            "ping_res=$(ping -c 1 -W 2 1.1.1.1 2>/dev/null | awk -F'/' 'END{ print (/^rtt/? $5\" ms\":\"ERR\") }'); " +
            "echo \"$ip|$ping_res\""
        ]
        stdout: SplitParser {
            onRead: (data) => {
                var parts = data.trim().split("|");
                if (parts.length >= 2) {
                    root.publicIp = parts[0];
                    root.latency = parts[1];
                }
            }
        }
        onExited: running = false
    }

    function disconnect() {
        disconnectProc.command = [
            "sh", "-c",
            "if [ \"" + root.tunnelType + "\" = \"WireGuard\" ]; then " +
            "  nmcli connection down $(nmcli -t -f UUID,TYPE c s --active | grep wireguard | cut -d: -f1) 2>/dev/null || wg-quick down wg0; " +
            "elif [ \"" + root.tunnelType + "\" = \"OpenVPN\" ]; then " +
            "  nmcli connection down $(nmcli -t -f UUID,TYPE c s --active | grep tun | cut -d: -f1) 2>/dev/null || killall openvpn; " +
            "elif [ \"" + root.tunnelType + "\" = \"SSH Tunnel\" ]; then " +
            "  killall ssh 2>/dev/null; " +
            "fi"
        ];
        disconnectProc.running = true;
    }

    Process {
        id: disconnectProc
        running: false
        onExited: running = false
    }
}
