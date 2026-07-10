import QtQuick
import Quickshell.Io



QtObject {
    id: root

    property real brightness: 0
    property bool capsLock: false
    property bool numLock: false
    property real kbdBrightness: 0

    property Process pollProc: Process {
        command: [
            "sh", "-c",
            "b_path=$(ls /sys/class/backlight/*/brightness 2>/dev/null | head -1); " +
            "c_path=$(ls /sys/class/leds/*::capslock/brightness 2>/dev/null | head -1); " +
            "n_path=$(ls /sys/class/leds/*::numlock/brightness 2>/dev/null | head -1); " +
            "k_path=$(ls /sys/class/leds/*kbd_backlight*/brightness 2>/dev/null | head -1); " +
            "b_max=$(cat ${b_path%/*}/max_brightness 2>/dev/null || echo 100); " +
            "k_max=$(cat ${k_path%/*}/max_brightness 2>/dev/null || echo 100); " +
            "last_b=\"\"; last_c=\"\"; last_n=\"\"; last_k=\"\"; " +
            "while true; do " +
            "  [ -n \"$b_path\" ] && read -r b < \"$b_path\" || b=0; " +
            "  [ -n \"$c_path\" ] && read -r c < \"$c_path\" || c=0; " +
            "  [ -n \"$n_path\" ] && read -r n < \"$n_path\" || n=0; " +
            "  [ -n \"$k_path\" ] && read -r k < \"$k_path\" || k=0; " +
            "  if [ \"$b\" != \"$last_b\" ] || [ \"$c\" != \"$last_c\" ] || [ \"$n\" != \"$last_n\" ] || [ \"$k\" != \"$last_k\" ]; then " +
            "    b_pct=$(( b * 100 / b_max )); k_pct=$(( k * 100 / k_max )); " +
            "    echo \"b=$b_pct\"; echo \"c=$c\"; echo \"n=$n\"; echo \"k=$k_pct\"; " +
            "    last_b=\"$b\"; last_c=\"$c\"; last_n=\"$n\"; last_k=\"$k\"; " +
            "  fi; " +
            "  sleep 0.3; " +
            "done"
        ]
        running: true
        stdout: SplitParser {
            onRead: (data) => {
                var line = data.trim();
                if (line.length < 2 || line.charAt(1) !== '=') return;
                var val = line.substring(2);
                if (line.charAt(0) === 'b') {
                    var pct = parseInt(val);
                    if (!isNaN(pct)) root.brightness = Math.max(0, Math.min(1, pct / 100));
                } else if (line.charAt(0) === 'c') {
                    root.capsLock = val.trim() === "1";
                } else if (line.charAt(0) === 'n') {
                    root.numLock = val.trim() === "1";
                } else if (line.charAt(0) === 'k') {
                    var kpct = parseInt(val);
                    if (!isNaN(kpct)) root.kbdBrightness = Math.max(0, Math.min(1, kpct / 100));
                }
            }
        }
    }
}
