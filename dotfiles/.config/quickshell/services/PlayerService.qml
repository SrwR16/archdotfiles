import "../overlay"
import "../services"
import "../theme"
import "../widgets"
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Media player backend built on the native Quickshell.Services.Mpris API.
// Exposes `activePlayer` (a native MprisPlayer: track metadata + transport
// controls) and `playerArt` (resolved art URL) for the Control Center UI.
// Note: the DynamicIsland uses the separate `MediaService` (cava bars).
Item {
    id: root

    property var activePlayer: root._pickActive()
    property string playerArt: root._resolveArt(root.activePlayer)

    function _pickActive() {
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

}
