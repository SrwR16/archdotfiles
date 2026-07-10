import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
  property string playbackStatus: "Stopped"
  property bool playing: playbackStatus === "Playing"

  readonly property string mediaState: {
    if (playbackStatus === "Stopped" || playbackStatus === "") return "Idle";
    if (title === "No Media") return "Loading";
    return playbackStatus; // "Playing" or "Paused"
  }

  property string title: "No Media"
  property string artist: "Unknown Artist"
  property string art: ""

  property var bars: [2, 2, 2, 2]

  property Process playerStatusProc: Process {
    command: [
      "playerctl",
      "-p", "playerctld",
      "status",
      "--follow"
    ]
    running: true

    stdout: SplitParser {
      onRead: (data) => {
        playbackStatus = data.trim();
        metaTimer.restart();
      }
    }
  }

  property Timer metaTimer: Timer {
    interval: 2000
    onTriggered: fetchMetadata()
  }

  function youtubeThumb(url) {
    if (!url) return "";
    var match = url.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})/);
    return match ? "https://img.youtube.com/vi/" + match[1] + "/hqdefault.jpg" : "";
  }

  function fetchMetadata() {
    playerMetadataProc.running = false;
    playerMetadataProc.command = [
      "playerctl",
      "-p", "playerctld",
      "metadata",
      "--format",
      "{{title}}|~|{{artist}}|~|{{mpris:artUrl}}|~|{{xesam:url}}"
    ];
    playerMetadataProc.running = true;
  }

  property Process playerMetadataProc: Process {
    command: ["true"]
    running: false
    stdout: SplitParser {
      onRead: (data) => {
        var parts = data.trim().split("|~|");
        if (parts.length < 4) return;

        title = parts[0] || "No Media";
        artist = parts[1] || "Unknown";

        var artUrl = parts[2];
        var pageUrl = parts[3];

        var newArt = "";
        if (artUrl && artUrl.startsWith("/"))
          newArt = "file://" + artUrl;
        else if (artUrl)
          newArt = artUrl;
        else if (pageUrl)
          newArt = youtubeThumb(pageUrl);

        if (newArt)
          art = newArt;
      }
    }
  }

  property Process cavaProc: Process {
    command: [
      "stdbuf", "-oL",
      "cava",
      "-p", Quickshell.shellPath("widgets/cava.conf")
    ]
    running: playing

    stdout: SplitParser {
      onRead: (data) => {
        var values = data.trim().split(";");
        if (values.length >= 4) {
          bars = [
            Math.max(2, values[0]),
            Math.max(2, values[1]),
            Math.max(2, values[2]),
            Math.max(2, values[3])
          ];
        }
      }
    }
  }
}
