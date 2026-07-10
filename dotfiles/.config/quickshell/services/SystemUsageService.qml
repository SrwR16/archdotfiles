import "../overlay"
import "../widgets"
import "../services"
import "../theme"
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: sysSvc

  property real cpuUsage: 0.0
  property real ramUsage: 0.0
  property real diskUsage: 0.0

  Process {
    command: ["sh", "-c",
      "while true; do " +
      "  cpu=$(top -bn1 | grep 'Cpu(s)' | awk '{print $2 + $4}'); " +
      "  ram=$(free | awk '/Mem/ {printf(\"%.2f\", $3/$2 * 100.0)}'); " +
      "  disk=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%'); " +
      "  echo \"$cpu|$ram|$disk\"; " +
      "  sleep 2; " +
      "done"
    ]
    running: true
    stdout: SplitParser {
      onRead: (data) => {
        var parts = data.trim().split("|")
        if (parts.length === 3) {
          sysSvc.cpuUsage = parseFloat(parts[0]) / 100.0
          sysSvc.ramUsage = parseFloat(parts[1]) / 100.0
          sysSvc.diskUsage = parseFloat(parts[2]) / 100.0
        }
      }
    }
  }
}
