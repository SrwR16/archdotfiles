import "../overlay"
import "../services"
import "../theme"
import "../widgets"
import QtQuick
import Quickshell
import Quickshell.Io

// Night Light backend. Persists state to scripts/night-light-state.json and
// drives scripts/nightlight.sh for manual / auto (day-night) modes.
Item {
    id: root

    property string nlStatePath: Quickshell.shellPath("scripts/night-light-state.json")
    property bool nlEnabled: false
    property string nlMode: "manual"
    property int nlTemp: 4500
    property int nlDayTemp: 6500
    property int nlNightTemp: 3500

    function applyNightLight() {
        if (!nlEnabled)
            nlProc.command = [Quickshell.shellPath("scripts/nightlight.sh"), "off"];
        else if (nlMode === "auto")
            nlProc.command = [Quickshell.shellPath("scripts/nightlight.sh"), "auto", String(nlDayTemp), String(nlNightTemp)];
        else
            nlProc.command = [Quickshell.shellPath("scripts/nightlight.sh"), "manual", String(nlTemp)];
        nlProc.running = true;
    }

    function saveNightLight() {
        var s = JSON.stringify({
            "enabled": nlEnabled,
            "mode": nlMode,
            "temperature": nlTemp,
            "dayTemp": nlDayTemp,
            "nightTemp": nlNightTemp
        });
        nlSaveProc.command = ["sh", "-c", "mkdir -p $(dirname \"" + root.nlStatePath + "\") && " + "printf '%s\\n' \"" + s.replace(/\"/g, '\\"') + "\" > \"" + root.nlStatePath + ".tmp\" && " + "mv -f \"" + root.nlStatePath + ".tmp\" \"" + root.nlStatePath + "\""];
        nlSaveProc.running = true;
    }

    function toggleNightLight() {
        nlEnabled = !nlEnabled;
        applyNightLight();
        saveNightLight();
    }

    function setNightLightTemp(temp) {
        nlTemp = Math.max(1000, Math.min(8000, temp));
        if (nlEnabled && nlMode === "manual")
            applyNightLight();

        saveNightLight();
    }

    function setNightLightMode(mode) {
        nlMode = mode;
        if (nlEnabled)
            applyNightLight();

        saveNightLight();
    }

    function setNightLightAutoTemp(day, night) {
        nlDayTemp = Math.max(1000, Math.min(8000, day));
        nlNightTemp = Math.max(1000, Math.min(8000, night));
        if (nlEnabled && nlMode === "auto")
            applyNightLight();

        saveNightLight();
    }

    FileView {
        id: nlStateFile

        path: root.nlStatePath
        Component.onCompleted: {
            var raw = nlStateFile.text().trim();
            if (!raw)
                return ;

            try {
                var s = JSON.parse(raw);
                root.nlEnabled = s.enabled || false;
                root.nlMode = s.mode || "manual";
                root.nlTemp = s.temperature || 4500;
                root.nlDayTemp = s.dayTemp || 6500;
                root.nlNightTemp = s.nightTemp || 3500;
            } catch (e) {
            }
            root.applyNightLight();
        }
    }

    Process {
        id: nlProc
    }

    Process {
        id: nlSaveProc
    }

}
