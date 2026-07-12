import "../overlay"
import "../services"
import "../theme"
import "../widgets"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

QtObject {
    id: root

    property var player: root._pick()
    property string playbackStatus: {
        if (!root.player)
            return "Stopped";

        if (root.player.isPlaying)
            return "Playing";

        return root.player.playbackState === MprisPlaybackState.Paused ? "Paused" : "Stopped";
    }
    property bool playing: playbackStatus === "Playing"
    readonly property string mediaState: {
        if (playbackStatus === "Stopped" || playbackStatus === "")
            return "Idle";

        if (title === "No Media")
            return "Loading";

        return playbackStatus;
    }
    property string title: root.player ? (root.player.trackTitle || "No Media") : "No Media"
    property string artist: root.player ? (root.player.trackArtist || "Unknown Artist") : "Unknown Artist"
    property string art: root._resolveArt(root.player)
    property var bars: [2, 2, 2, 2]
    property Process cavaProc

    function _pick() {
        var list = Mpris.players.values || [];
        for (var i = 0; i < list.length; ++i) {
            if (list[i].isPlaying)
                return list[i];

        }
        return list.length > 0 ? list[0] : null;
    }

    function _resolveArt(p) {
        if (!p)
            return "";

        var artUrl = p.trackArtUrl || "";
        var pageUrl = (p.metadata && p.metadata["xesam:url"]) || "";
        if (artUrl.startsWith("/"))
            return "file://" + artUrl;

        if (artUrl)
            return artUrl;

        if (pageUrl) {
            var m = pageUrl.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})/);
            if (m)
                return "https://img.youtube.com/vi/" + m[1] + "/hqdefault.jpg";

        }
        return "";
    }

    cavaProc: Process {
        command: ["stdbuf", "-oL", "cava", "-p", Quickshell.shellPath("widgets/cava.conf")]
        running: playing

        stdout: SplitParser {
            onRead: (data) => {
                var values = data.trim().split(";");
                if (values.length >= 4)
                    bars = [Math.max(2, values[0]), Math.max(2, values[1]), Math.max(2, values[2]), Math.max(2, values[3])];

            }
        }

    }

}
