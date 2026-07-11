import QtQuick
import QtQuick.Window
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

    // --- theme tokens (mirrors MovieWidget) ---
    readonly property color mantle:    _theme.mantle
    readonly property color crust:     _theme.crust
    readonly property color base:      _theme.base
    readonly property color text:      _theme.text
    readonly property color subtext0:  _theme.subtext0
    readonly property color subtext1:  _theme.subtext1
    readonly property color surface0:  _theme.surface0
    readonly property color surface1:  _theme.surface1
    readonly property color surface2:  _theme.surface2
    readonly property color accent:    _theme.mauve || "#cba6f7"
    readonly property color green:     _theme.green || "#a6e3a1"
    readonly property color red:       _theme.red || "#f38ba8"
    readonly property string fontUI: ".AppleSystemUIFont, SF Pro Display, Inter, Segoe UI, sans-serif"
    function s(v) { return Math.max(1, Math.round(v * (Screen.width / 1920))) }

    // --- state ---
    property string tab: "local"                 // "local" | "online"
    property string baseDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    property string currentFolder: baseDir
    property string selectedPath: ""             // local file of current selection (preview / direct apply)
    property string selectedUrl: ""               // full image url when selection is from online search
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

    // local file listing
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
    // subfolder listing for the sidebar
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
                if (window.searchModel.count === 0) showToast("No results for “" + searchProc.query + "”")
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
        stdout: StdioCollector {
            onStreamFinished: { runStatic(saveProc.targetPath) }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim()) showToast("Download failed")
            }
        }
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", onlineSaveDir])
        window.currentFolder = window.baseDir
    }

    Keys.onPressed: {
        if (event.key === Qt.Key_Escape) { closePanel(); event.accepted = true }
    }

    // ---------------- backdrop ----------------
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        MouseArea {
            anchors.fill: parent
            onClicked: closePanel()
        }
    }

    // ---------------- panel ----------------
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(s(1180), Screen.width * 0.94)
        height: Math.min(s(760), Screen.height * 0.92)
        radius: s(26)
        color: mantle
        border.color: Qt.rgba(text.r, text.g, text.b, 0.10)
        border.width: 1
        clip: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ---------- header ----------
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: s(58)
                Layout.leftMargin: s(20); Layout.rightMargin: s(16)
                spacing: s(12)

                Text {
                    text: "Wallpapers"
                    color: text
                    font.family: fontUI
                    font.pixelSize: s(20)
                    font.weight: Font.DemiBold
                }
                Text {
                    text: "· " + (window.tab === "local"
                        ? (window.currentFolder === window.baseDir ? "All" : window.currentFolder.split("/").pop())
                        : "Online")
                    color: subtext0
                    font.family: fontUI
                    font.pixelSize: s(13)
                }

                Item { Layout.fillWidth: true }

                // tab toggles
                Row {
                    spacing: s(4)
                    Repeater {
                        model: [["local","Local"], ["online","Online"]]
                        delegate: Rectangle {
                            width: s(64); height: s(30)
                            radius: s(15)
                            color: window.tab === modelData[0] ? accent : surface0
                            Text {
                                anchors.centerIn: parent
                                text: modelData[1]
                                color: window.tab === modelData[0] ? "#11111b" : subtext0
                                font.family: fontUI
                                font.pixelSize: s(12)
                                font.weight: Font.Medium
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.tab = modelData[0]
                            }
                        }
                    }
                }

                Rectangle {
                    width: s(32); height: s(32); radius: s(16)
                    color: surface0
                    Text {
                        anchors.centerIn: parent
                        text: "✕"; color: text
                        font.pixelSize: s(13); font.weight: Font.Bold
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: closePanel()
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(text.r, text.g, text.b, 0.08) }

            // ---------- body ----------
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // ----- sidebar -----
                ColumnLayout {
                    Layout.preferredWidth: s(232)
                    Layout.fillHeight: true
                    Layout.leftMargin: s(14); Layout.rightMargin: s(10)
                    Layout.topMargin: s(12); Layout.bottomMargin: s(12)
                    spacing: s(8)

                    // search box (online) / folder note (local)
                    TextField {
                        Layout.fillWidth: true
                        visible: window.tab === "online"
                        placeholderText: "Search wallpapers…"
                        color: text
                        font.family: fontUI
                        font.pixelSize: s(13)
                        background: Rectangle {
                            radius: s(10); color: surface0
                            border.color: parent.activeFocus ? surface2 : surface1
                            border.width: 1
                        }
                        onAccepted: runSearch(text)
                    }

                    Button {
                        Layout.fillWidth: true
                        visible: window.tab === "online"
                        text: window.searchRunning ? "Searching…" : "Search"
                        enabled: !window.searchRunning
                        onClicked: runSearch(searchField.text)
                        background: Rectangle {
                            radius: s(10); color: parent.hovered ? surface1 : surface0
                            border.color: surface1; border.width: 1
                        }
                        contentItem: Text {
                            text: parent.text; color: text; font.family: fontUI
                            font.pixelSize: s(13); horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    // "All Wallpapers" entry
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: s(34)
                        radius: s(9)
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
                        text: "Folders"
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
                            radius: s(8)
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

                    Button {
                        Layout.fillWidth: true
                        text: "Browse…"
                        onClicked: folderDialog.open()
                        background: Rectangle {
                            radius: s(10); color: parent.hovered ? surface1 : surface0
                            border.color: surface1; border.width: 1
                        }
                        contentItem: Text {
                            text: parent.text; color: text; font.family: fontUI
                            font.pixelSize: s(12.5); horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
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

                Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: Qt.rgba(text.r, text.g, text.b, 0.08) }

                // ----- grid -----
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    GridView {
                        id: grid
                        anchors.fill: parent
                        anchors.margins: s(14)
                        cellWidth: s(184); cellHeight: s(152)
                        model: window.tab === "local" ? localModel : searchModel
                        delegate: WallDelegate {}
                        clip: true
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: s(8) }
                    }

                    // empty state
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

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(text.r, text.g, text.b, 0.08) }

            // ---------- footer ----------
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: s(70)
                Layout.leftMargin: s(16); Layout.rightMargin: s(16)
                spacing: s(12)

                Rectangle {
                    width: s(46); height: s(46); radius: s(10)
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

                // theme toggle
                Rectangle {
                    width: s(86); height: s(34); radius: s(17)
                    color: window.themeOn ? accent : surface0
                    Text {
                        anchors.centerIn: parent
                        text: "Theme"
                        color: window.themeOn ? "#11111b" : subtext0
                        font.family: fontUI; font.pixelSize: s(11.5); font.weight: Font.Medium
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.themeOn = !window.themeOn
                    }
                }

                Button {
                    text: window.selectedIsVideo ? "Set Video" : "Set Wallpaper"
                    enabled: window.selectedPath !== "" || window.selectedUrl !== ""
                    onClicked: applySelection()
                    background: Rectangle {
                        radius: s(10)
                        color: parent.enabled ? (parent.hovered ? Qt.lighter(accent, 1.12) : accent) : surface1
                    }
                    contentItem: Text {
                        text: parent.text
                        color: parent.enabled ? "#11111b" : subtext0
                        font.family: fontUI; font.pixelSize: s(13); font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
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
        readonly property string _src:   model.fileURL ? model.fileURL : (model.path ? model.path : "")
        readonly property string _apply: model.filePath ? model.filePath : (model.path ? model.path : "")
        readonly property string _full:  model.url ? model.url : ""
        property bool _vid: isVideoPath(_apply)
        width: GridView.view.cellWidth; height: GridView.view.cellHeight
        color: "transparent"

        Rectangle {
            id: card
            anchors.fill: parent
            anchors.margins: s(6)
            radius: s(12)
            color: surface0
            clip: true
            scale: hov.containsMouse ? 1.04 : 1.0
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            Image {
                anchors.fill: parent
                source: _src
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Rectangle {
                id: scrim
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0)
                Behavior on color { ColorAnimation { duration: 140 } }
                states: State {
                    when: hov.containsMouse
                    PropertyChanges { target: scrim; color: Qt.rgba(0, 0, 0, 0.28) }
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: s(12)
                color: "transparent"
                border.width: window.selectedPath === _apply ? s(3) : 0
                border.color: accent
            }
            Text {
                visible: _vid
                text: "▶"; color: "#ffffff"; font.pixelSize: s(22)
                anchors.centerIn: parent
            }
            MouseArea {
                id: hov
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
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
