import "../overlay"
import "../services"
import "../theme"
import "../widgets"
import QtQuick
import Quickshell
import Quickshell.Io

// Screen brightness backend. Detects the backlight sysfs device, mirrors its
// current value into `brightness`, and writes changes via brightnessctl.
Item {
    id: root

    property real brightness: 0.8
    property string backlightDevice: ""

    function syncBrightnessFromSysfs() {
        const cur = parseInt(brightnessCurrentFile.text());
        const max = parseInt(brightnessMaxFile.text());
        if (!isNaN(cur) && !isNaN(max) && max > 0)
            brightness = cur / max;

    }

    function setBrightness(val) {
        brightness = Math.max(0, Math.min(1, val));
        brightnessSetProc.command = ["brightnessctl", "set", Math.round(brightness * 100) + "%"];
        brightnessSetProc.running = true;
    }

    function brightnessIcon(val) {
        if (val < 0.34)
            return "󰃞";

        if (val < 0.67)
            return "󰃟";

        return "󰃠";
    }

    Component.onCompleted: backlightDetectProc.running = true

    Process {
        id: backlightDetectProc

        command: ["sh", "-c", "ls /sys/class/backlight 2>/dev/null | head -n1"]

        stdout: StdioCollector {
            onStreamFinished: {
                const name = this.text.trim();
                if (name)
                    root.backlightDevice = name;

            }
        }

    }

    FileView {
        id: brightnessCurrentFile

        path: root.backlightDevice ? `/sys/class/backlight/${root.backlightDevice}/brightness` : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.syncBrightnessFromSysfs()
        onTextChanged: root.syncBrightnessFromSysfs()
    }

    FileView {
        id: brightnessMaxFile

        path: root.backlightDevice ? `/sys/class/backlight/${root.backlightDevice}/max_brightness` : ""
    }

    Process {
        id: brightnessSetProc
    }

}
