import "../overlay"
import "../services"
import "../theme"
import "../widgets"
import QtQuick
import Quickshell
import Quickshell.Io

// Media player backend (playerctld). Exposes `activePlayer` (track metadata +
// transport controls) and `playerArt` for the Control Center media UI.
// Note: the DynamicIsland uses the separate `MediaService` (cava bars API);
// this is the full player used by the Control Center page.
Item {
    id: root

    property QtObject activePlayer: playerctlData
    property string playerArt: ""
    property var playerctlData

    playerctlData: QtObject {
        property string identity: "Media Player"
        property string trackTitle: ""
        property string trackArtist: ""
        property string artUrl: ""
        property bool isPlaying: false
        property real position: 0
        property real length: 1

        function previous() {
            playerctlCmd.command = ["playerctl", "--player=playerctld", "previous"];
            playerctlCmd.running = true;
        }

        function togglePlaying() {
            playerctlCmd.command = ["playerctl", "--player=playerctld", "play-pause"];
            playerctlCmd.running = true;
        }

        function next() {
            playerctlCmd.command = ["playerctl", "--player=playerctld", "next"];
            playerctlCmd.running = true;
        }

        function fetch() {
            metaProc.running = false;
            metaProc.command = ["playerctl", "--player=playerctld", "metadata", "--format", "{{title}}|~|{{artist}}|~|{{mpris:artUrl}}|~|{{xesam:url}}|~|{{mpris:length}}|~|{{mpris:position}}"];
            metaProc.running = true;
        }

    }

    property Process playerctlCmd

    playerctlCmd: Process {
        command: ["true"]
        running: false
    }

    property Process playerctlStatusProc

    playerctlStatusProc: Process {
        command: ["playerctl", "--player=playerctld", "status", "--follow"]
        running: true

        stdout: SplitParser {
            onRead: (data) => {
                var s = data.trim();
                if (s !== "Playing" && s !== "Paused") {
                    playerctlData.isPlaying = false;
                    playerctlData.trackTitle = "";
                    playerctlData.trackArtist = "";
                    playerctlData.artUrl = "";
                    playerArt = "";
                } else {
                    playerctlData.isPlaying = s === "Playing";
                    playerctlData.fetch();
                }
            }
        }

    }

    property Process metaProc

    metaProc: Process {
        command: ["true"]
        running: false

        stdout: SplitParser {
            onRead: (data) => {
                var parts = data.trim().split("|~|");
                if (parts.length < 6)
                    return ;

                playerctlData.trackTitle = parts[0] || "";
                playerctlData.trackArtist = parts[1] || "";
                var artUrl = parts[2] || "";
                var pageUrl = parts[3] || "";
                var len = parseFloat(parts[4]) || 0;
                var pos = parseFloat(parts[5]) || 0;
                playerctlData.length = len > 0 ? len / 1e+06 : 1;
                playerctlData.position = pos > 0 ? pos / 1e+06 : 0;
                var newArt = "";
                if (artUrl.startsWith("/")) {
                    newArt = "file://" + artUrl;
                } else if (artUrl) {
                    newArt = artUrl;
                } else if (pageUrl) {
                    var m = pageUrl.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})/);
                    if (m)
                        newArt = "https://img.youtube.com/vi/" + m[1] + "/hqdefault.jpg";

                }
                playerctlData.artUrl = newArt;
                if (newArt)
                    playerArt = newArt;

            }
        }

    }

}
