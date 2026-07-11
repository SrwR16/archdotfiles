import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "../widgets"
import "../theme"
import "../services"
import "../overlay"

Item {
    id: window
    focus: true

    Caching { id: paths }
    MatugenColors { id: _theme }
    WallpaperService { id: wpSvc }
    Scaler { id: scaler; currentWidth: Screen.width }

    // --- design tokens (match MovieWidget) ---
    readonly property color base:      _theme.base
    readonly property color mantle:    _theme.mantle
    readonly property color crust:     _theme.crust
    readonly property color text:      _theme.text
    readonly property color subtext0:  _theme.subtext0
    readonly property color subtext1:  _theme.subtext1
    readonly property color surface0:  _theme.surface0
    readonly property color surface1:  _theme.surface1
    readonly property color surface2:  _theme.surface2
    readonly property color mauve:     _theme.mauve || "#cba6f7"
    readonly property color blue:      _theme.blue || "#89b4fa"
    readonly property color green:     _theme.green || "#a6e3a1"
    readonly property color red:       _theme.red || "#f38ba8"
    readonly property string fontUI: ".AppleSystemUIFont, SF Pro Display, SF Pro Text, Inter, Segoe UI, sans-serif"
    readonly property color shadowColor: Qt.rgba(0, 0, 0, 0.38)
    readonly property color hairline: Qt.rgba(text.r, text.g, text.b, 0.08)
    readonly property color accent: mauve
    function rXS() { return s(8) }
    function rSM() { return s(12) }
    function rMD() { return s(16) }
    function rLG() { return s(20) }
    function rXL() { return s(28) }
    function s(val) { return scaler.s(val) }

    // --- ANIMATIONS & FOCUS (match MovieWidget) ---
    property real introPhase: 0
    NumberAnimation on introPhase {
        id: introPhaseAnim
        from: 0; to: 1; duration: 800; easing.type: Easing.OutQuart; running: true
    }

    // --- state ---
    property string tab: "local"                 // "local" | "online"
    property string baseDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    property string currentFolder: baseDir
    property string selectedPath: ""
    property string selectedUrl: ""
    property bool   selectedIsVideo: false
    property bool   searchRunning: false
    property bool   themeOn: true
    property string statusMsg: ""
    property bool   showStatus: false
    readonly property string onlineSaveDir: paths.getCacheDir("wallpaper_picker") + "/online"
    readonly property var imageExts: ["jpg","jpeg","png","webp","gif","bmp"]
    readonly property var videoExts: ["mp4","webm","mov"]

    function isVideoPath(p) {
        var e = p.split("?")[0].toLowerCase()
        for (var i = 0; i < videoExts.length; i++)
            if (e.endsWith("." + videoExts[i])) return true
        return false
    }
    function extOf(u) {
        var m = u.split("?")[0]
        var e = m.substr(m.lastIndexOf(".") + 1).toLowerCase()
        if (imageExts.indexOf(e) >= 0) return "." + e
        return ".jpg"
    }
    function toFileUrl(p) { return "file://" + encodeURI(p) }

    function showToast(msg) {
        window.statusMsg = msg
        window.showStatus = true
        statusTimer.restart()
    }
    function runStatic(p) {
        if (window.themeOn) wpSvc.applyWallpaper(p)
        else Quickshell.execDetached(["awww", "img", p])
        showToast("Wallpaper set" + (window.themeOn ? " · theme applied" : ""))
    }
    function runVideo(p) {
        Quickshell.execDetached([Quickshell.shellPath("wallpaper/set_video.sh"), p])
        showToast("Video wallpaper set")
    }
    function saveAndApply(url) {
        var out = onlineSaveDir + "/online_" + Date.now() + extOf(url)
        saveProc.fullUrl = url
        saveProc.targetPath = out
        saveProc.command = [Quickshell.shellPath("wallpaper/save_url.sh"), url, out]
        saveProc.running = true
        showToast("Downloading…")
    }
    function applySelection() {
        if (!window.selectedPath && !window.selectedUrl) { showToast("Select a wallpaper first"); return }
        if (window.selectedIsVideo && window.selectedUrl === "") { runVideo(window.selectedPath); return }
        if (window.selectedUrl !== "") { saveAndApply(window.selectedUrl); return }
        runStatic(window.selectedPath)
    }
    function closePanel() { root.overlayView = "island" }
    function runSearch(q) {
        q = (q || "").trim()
        if (!q) return
        window.searchRunning = true
        window.searchModel.clear()
        searchProc.query = q
        searchProc.command = [Quickshell.shellPath("wallpaper/search.sh"), q]
        searchProc.running = true
    }

    Timer {
        id: statusTimer
        interval: 2600
        onTriggered: window.showStatus = false
    }

    FolderListModel {
        id: localModel
        folder: toFileUrl(window.currentFolder)
        showDirs: false
        showFiles: true
        showDotAndDotDot: false
        nameFilters: ["*.jpg","*.jpeg","*.png","*.webp","*.gif","*.bmp",
                      "*.JPG","*.JPEG","*.PNG","*.WEBP","*.MP4","*.WEBM","*.MOV",
                      "*.mp4","*.webm","*.mov"]
    }
    FolderListModel {
        id: foldersModel
        folder: toFileUrl(window.baseDir)
        showDirs: true
        showFiles: false
        showDotAndDotDot: false
    }
    ListModel { id: searchModel }

    Process {
        id: searchProc
        property string query
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                window.searchRunning = false
                var lines = this.text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var ln = lines[i].trim()
                    if (!ln || ln === "DONE") continue
                    var parts = ln.split("|")
                    if (parts.length >= 2 && parts[0])
                        window.searchModel.append({ path: parts[0], url: parts[1] })
                }
                if (window.searchModel.count === 0) showToast("No results for \"" + searchProc.query + "\"")
            }
        }
        stderr: StdioCollector {
            onStreamFinished: { if (this.text.trim()) console.error("wallpaper search:", this.text.trim()) }
        }
    }
    Process {
        id: saveProc
        property string targetPath
        property string fullUrl
        running: false
        stdout: StdioCollector { onStreamFinished: { runStatic(saveProc.targetPath) } }
        stderr: StdioCollector { onStreamFinished: { if (this.text.trim()) showToast("Download failed") } }
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", onlineSaveDir])
        window.currentFolder = window.baseDir
    }

    Keys.onPressed: {
        if (event.key === Qt.Key_Escape) { closePanel(); event.accepted = true }
    }

    // ---------------- full-screen sheet (matches MovieWidget) ----------------
    Rectangle {
        id: mainBg
        width: parent.width; height: parent.height
        anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
        radius: window.rXL()
        color: Qt.rgba(window.base.r, window.base.g, window.base.b, 0.96)
        border.color: window.hairline
        border.width: 1
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: window.shadowColor
            shadowBlur: 0.8; shadowVerticalOffset: 8; shadowOpacity: 0.35
        }
        clip: true
        transform: Translate { y: (1 - window.introPhase) * window.s(50) }
        opacity: window.introPhase

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ---------- header ----------
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: window.s(64)
                Layout.leftMargin: window.s(22); Layout.rightMargin: window.s(18)
                Layout.topMargin: window.s(8)
                spacing: window.s(14)

                Text {
                    text: "Wallpapers"
                    color: text
                    font.family: fontUI
                    font.pixelSize: s(22)
                    font.weight: Font.DemiBold
                }

                // segmented control: Local | Online (matches Movies/TV)
                Rectangle {
                    Layout.preferredWidth: s(180); Layout.preferredHeight: s(36)
                    radius: rLG(); color: surface0
                    Rectangle {
                        id: tabHighlight
                        width: parent.width / 2 - s(4); height: parent.height - s(6)
                        y: s(3); radius: rMD(); color: text
                        property real targetX: window.tab === "local" ? s(3) : (parent.width / 2 + s(1))
                        property real actualX: targetX
                        Behavior on actualX { NumberAnimation { duration: 340; easing.type: Easing.OutExpo } }
                        x: actualX
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true; shadowColor: shadowColor
                            shadowBlur: 0.6; shadowVerticalOffset: 2; shadowOpacity: 0.28
                        }
                    }
                    RowLayout {
                        anchors.fill: parent; spacing: 0
                        MouseArea {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            onClicked: window.tab = "local"
                            Text {
                                anchors.centerIn: parent; text: "Local"
                                font.family: fontUI
                                font.weight: window.tab === "local" ? Font.DemiBold : Font.Medium
                                font.pixelSize: s(13)
                                color: window.tab === "local" ? base : subtext0
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                        }
                        MouseArea {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            onClicked: window.tab = "online"
                            Text {
                                anchors.centerIn: parent; text: "Online"
                                font.family: fontUI
                                font.weight: window.tab === "online" ? Font.DemiBold : Font.Medium
                                font.pixelSize: s(13)
                                color: window.tab === "online" ? base : subtext0
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // online search bar
                TextField {
                    id: searchField
                    visible: window.tab === "online"
                    Layout.preferredWidth: s(240); Layout.preferredHeight: s(36)
                    placeholderText: "Search wallpapers…"
                    color: text
                    font.family: fontUI
                    font.pixelSize: s(13)
                    background: Rectangle {
                        radius: rLG(); color: surface0
                        border.color: parent.activeFocus ? surface2 : surface1
                        border.width: 1
                    }
                    onAccepted: runSearch(text)
                }
                Rectangle {
                    visible: window.tab === "online"
                    width: s(36); height: s(36); radius: rLG()
                    color: searchBtnMouse.containsMouse ? surface1 : surface0
                    border.color: surface1; border.width: 1
                    Text { anchors.centerIn: parent; text: "🔍"; font.pixelSize: s(14) }
                    MouseArea {
                        id: searchBtnMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: runSearch(searchField.text)
                    }
                }

                // close button (matches MovieWidget ✕)
                Rectangle {
                    width: s(32); height: s(32); radius: s(16)
                    color: closeMouse.containsMouse ? surface2 : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "✕"; color: text
                        font.pixelSize: s(13); font.weight: Font.Bold
                    }
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: closePanel()
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: hairline }

            // ---------- body ----------
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // ----- sidebar -----
                ColumnLayout {
                    Layout.preferredWidth: s(240)
                    Layout.fillHeight: true
                    Layout.leftMargin: s(16); Layout.rightMargin: s(12)
                    Layout.topMargin: s(14); Layout.bottomMargin: s(14)
                    spacing: s(8)

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: s(34)
                        radius: rMD()
                        color: (window.tab === "local" && window.currentFolder === window.baseDir) ? surface1 : "transparent"
                        Text {
                            anchors.left: parent.left; anchors.leftMargin: s(12)
                            anchors.verticalCenter: parent.verticalCenter
                            text: "🖼  All Wallpapers"
                            color: (window.tab === "local" && window.currentFolder === window.baseDir) ? text : subtext0
                            font.family: fontUI; font.pixelSize: s(13)
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { window.tab = "local"; window.currentFolder = window.baseDir }
                        }
                    }

                    Text {
                        visible: window.tab === "local"
                        text: "FOLDERS"
                        color: subtext0
                        font.family: fontUI; font.pixelSize: s(11)
                        font.weight: Font.DemiBold
                        leftPadding: s(4)
                    }

                    ListView {
                        id: folderList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: window.tab === "local"
                        model: foldersModel
                        clip: true
                        spacing: s(4)
                        delegate: Rectangle {
                            width: ListView.view.width
                            height: s(30)
                            radius: rSM()
                            color: window.currentFolder === model.filePath ? surface1 : "transparent"
                            Text {
                                anchors.left: parent.left; anchors.leftMargin: s(10)
                                anchors.verticalCenter: parent.verticalCenter
                                text: model.fileName
                                color: window.currentFolder === model.filePath ? text : subtext0
                                font.family: fontUI; font.pixelSize: s(12.5)
                                elide: Text.ElideMiddle
                                width: parent.width - s(20)
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.currentFolder = model.filePath
                            }
                        }
                    }

                    Item { Layout.fillHeight: true; visible: window.tab === "local" }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: s(34)
                        radius: rMD()
                        color: browseMouse.containsMouse ? surface1 : surface0
                        border.color: surface1; border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "Browse…"
                            color: text; font.family: fontUI; font.pixelSize: s(12.5)
                        }
                        MouseArea {
                            id: browseMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: folderDialog.open()
                        }
                    }

                    Text {
                        visible: window.tab === "local"
                        text: window.baseDir
                        color: subtext0
                        font.family: fontUI; font.pixelSize: s(10)
                        wrapMode: Text.WrapAnywhere
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: hairline }

                // ----- grid -----
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    GridView {
                        id: grid
                        anchors.fill: parent
                        anchors.margins: s(16)
                        cellWidth: s(184); cellHeight: s(154)
                        model: window.tab === "local" ? localModel : searchModel
                        delegate: WallDelegate {}
                        clip: true
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: s(8) }
                    }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width * 0.7
                        horizontalAlignment: Text.AlignHCenter
                        color: subtext0
                        font.family: fontUI
                        font.pixelSize: s(14)
                        wrapMode: Text.Wrap
                        text: window.tab === "local"
                            ? "No wallpapers here.\nDrop images into " + window.baseDir + "\nor hit “Browse…”."
                            : (window.searchRunning ? "Searching DuckDuckGo…" : "Search online wallpapers above.")
                        visible: (window.tab === "local" ? localModel.count : searchModel.count) === 0
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: hairline }

            // ---------- footer ----------
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: s(72)
                Layout.leftMargin: s(18); Layout.rightMargin: s(18)
                spacing: s(12)

                Rectangle {
                    width: s(46); height: s(46); radius: rMD()
                    color: surface0
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: (window.selectedPath && !window.selectedIsVideo) ? toFileUrl(window.selectedPath) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: window.selectedIsVideo
                        text: "▶"; color: text; font.pixelSize: s(18)
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !window.selectedPath && !window.selectedIsVideo
                        text: "—"; color: subtext0; font.pixelSize: s(16)
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: s(2)
                    Text {
                        text: window.selectedPath ? window.selectedPath.split("/").pop() : "No wallpaper selected"
                        color: text
                        font.family: fontUI; font.pixelSize: s(13)
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }
                    Text {
                        text: window.selectedIsVideo ? "Video wallpaper" : (window.themeOn ? "Static · Matugen theme on" : "Static")
                        color: subtext0
                        font.family: fontUI; font.pixelSize: s(11)
                    }
                }

                Rectangle {
                    width: s(86); height: s(34); radius: s(17)
                    color: window.themeOn ? accent : surface0
                    Text {
                        anchors.centerIn: parent
                        text: "Theme"
                        color: window.themeOn ? base : subtext0
                        font.family: fontUI; font.pixelSize: s(11.5); font.weight: Font.Medium
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.themeOn = !window.themeOn
                    }
                }

                Rectangle {
                    Layout.preferredWidth: s(150); Layout.preferredHeight: s(38)
                    radius: rLG()
                    color: (window.selectedPath !== "" || window.selectedUrl !== "")
                        ? (setBtnMouse.containsMouse ? Qt.lighter(accent, 1.12) : accent)
                        : surface1
                    Text {
                        anchors.centerIn: parent
                        text: window.selectedIsVideo ? "Set Video" : "Set Wallpaper"
                        color: (window.selectedPath !== "" || window.selectedUrl !== "") ? base : subtext0
                        font.family: fontUI; font.pixelSize: s(13); font.weight: Font.DemiBold
                    }
                    MouseArea {
                        id: setBtnMouse
                        anchors.fill: parent
                        enabled: (window.selectedPath !== "" || window.selectedUrl !== "")
                        cursorShape: Qt.PointingHandCursor
                        onClicked: applySelection()
                    }
                }
            }
        }

        // toast
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - s(86)
            width: Math.min(s(360), parent.width * 0.8)
            height: s(38)
            radius: s(19)
            color: Qt.rgba(crust.r, crust.g, crust.b, 0.96)
            border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.5); border.width: 1
            visible: window.showStatus
            opacity: window.showStatus ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Text {
                anchors.centerIn: parent
                text: window.statusMsg
                color: text; font.family: fontUI; font.pixelSize: s(12.5)
                elide: Text.ElideMiddle; width: parent.width - s(20)
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    component WallDelegate: Rectangle {
        id: card
        readonly property string _src:   model.fileURL ? model.fileURL : (model.path ? model.path : "")
        readonly property string _apply: model.filePath ? model.filePath : (model.path ? model.path : "")
        readonly property string _full:  model.url ? model.url : ""
        property bool _vid: isVideoPath(_apply)
        property bool _sel: window.selectedPath === _apply
        width: GridView.view.cellWidth; height: GridView.view.cellHeight
        color: "transparent"

        Rectangle {
            id: inner
            anchors.fill: parent
            anchors.margins: s(8)
            radius: rMD()
            color: crust
            clip: true
            scale: hov.containsMouse ? 1.045 : 1.0
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutExpo } }
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true; shadowColor: shadowColor
                shadowBlur: hov.containsMouse ? 0.7 : 0.35
                shadowVerticalOffset: hov.containsMouse ? 6 : 2
                shadowOpacity: hov.containsMouse ? 0.4 : 0.2
                Behavior on shadowBlur { NumberAnimation { duration: 220 } }
                Behavior on shadowVerticalOffset { NumberAnimation { duration: 220 } }
                Behavior on shadowOpacity { NumberAnimation { duration: 220 } }
            }

            Image {
                id: img
                anchors.fill: parent
                source: _src
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                cache: true
                sourceSize.width: s(240); sourceSize.height: s(160)
                visible: status === Image.Ready
            }
            Rectangle {
                anchors.fill: parent
                color: surface0
                visible: _src === "" || img.status === Image.Error || img.status === Image.Null
                Column {
                    anchors.centerIn: parent
                    spacing: s(6)
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: _vid ? "▶" : "🖼"; font.pixelSize: s(22) }
                    Text {
                        width: parent.width
                        text: _apply.split("/").pop() || "Unknown"
                        color: subtext0
                        font.family: fontUI; font.pixelSize: s(11)
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        maximumLineCount: 3; elide: Text.ElideRight
                    }
                }
            }
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: parent.height * 0.5
                visible: img.status === Image.Ready
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.82) }
                }
            }
            Text {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                anchors.margins: s(8)
                visible: img.status === Image.Ready
                text: _apply.split("/").pop()
                color: "#ffffff"
                font.family: fontUI; font.weight: Font.DemiBold; font.pixelSize: s(11)
                wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; lineHeight: 1.15
            }
            Rectangle {
                anchors.fill: parent
                radius: rMD()
                color: "transparent"
                border.width: _sel ? s(3) : 0
                border.color: accent
            }
            MouseArea {
                id: hov
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    window.selectedPath = _apply
                    window.selectedUrl = _full
                    window.selectedIsVideo = _vid
                }
                onDoubleClicked: applySelection()
            }
        }
    }

    FolderDialog {
        id: folderDialog
        title: "Choose wallpaper folder"
        currentFolder: toFileUrl(window.baseDir)
        onAccepted: {
            var u = selectedFolder.toString()
            window.baseDir = u.replace(/^file:\/\//, "")
            window.currentFolder = window.baseDir
        }
    }
}
