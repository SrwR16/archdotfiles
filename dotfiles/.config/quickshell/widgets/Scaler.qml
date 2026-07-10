import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false

    property real currentWidth: 1920.0
    property real currentHeight: 1080.0
    property real uiScale: 1.0

    property real baseScale: uiScale * Math.min(currentWidth / 1920, currentHeight / 1080)

    function s(val) {
        return val * baseScale;
    }

    Process {
        id: scaleReader
        command: ["bash", "-c", "cat ~/.config/hypr/settings.json 2>/dev/null || echo '{}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (this.text && this.text.trim().length > 0 && this.text.trim() !== "{}") {
                        let parsed = JSON.parse(this.text);
                        if (parsed.uiScale !== undefined && root.uiScale !== parsed.uiScale) {
                            root.uiScale = parsed.uiScale;
                        }
                    }
                } catch (e) {}
            }
        }
    }

    // EVENT-DRIVEN WATCHER
    Process {
        id: scaleWatcher
        // -qq keeps it completely silent. It waits for the file to exist, listens for a write, and then exits.
        command: ["bash", "-c", "while [ ! -f ~/.config/hypr/settings.json ]; do sleep 1; done; inotifywait -qq -e modify,close_write ~/.config/hypr/settings.json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                // 1. Read the new data
                scaleReader.running = false;
                scaleReader.running = true;
                // 2. Restart the watcher for the next event
                scaleWatcher.running = false;
                scaleWatcher.running = true;
            }
        }
    }
}
