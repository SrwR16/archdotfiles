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
import "../services"

Item {
    id: window
    focus: true

    Caching { id: paths }
    MatugenColors { id: _theme }
    WallpaperService { id: wpSvc }
    Scaler { id: scaler; currentWidth: Screen.width }

    // --- design tokens (identical to MovieWidget) ---
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

    // --- ANIMATIONS (identical to MovieWidget) ---
    property real introPhase: 0
    NumberAnimation on introPhase {
        id: introPhaseAnim
        from: 0; to: 1; duration: 800; easing.type: Easing.OutQuart; running: true
    }

    // --- STATE ---
    property string currentView: "search"   // "search" (browse) | "series" (detail)
    property string baseDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    property string currentFolder: baseDir
    property int    segIndex: 0
    readonly property var segValues: ["all", "images", "videos"]
    property bool   browseOpen: false
    property string selectedPath: ""
    property bool   selectedIsVideo: false
    property string selectedName: ""
    property bool   themeOn: true
    property bool   isKeyboardNav: false
    property string statusMsg: ""
    property bool   showStatus: false
    readonly property var imageExts: ["jpg","jpeg","png","webp","gif","bmp"]
    readonly property var videoExts: ["mp4","webm","mov"]

    function isVideoPath(p) {
        var e = p.split("?")[0].toLowerCase()
        for (var i = 0; i < videoExts.length; i++)
            if (e.endsWith("." + videoExts[i])) return true
        return false
    }
    function toFileUrl(p) { return "file://" + encodeURI(p) }

    function showToast(msg) {
        window.statusMsg = msg
        window.showStatus = true
        statusTimer.restart()
    }
    function saveState(key, val) {
        Quickshell.execDetached([Quickshell.shellPath("wallpaper/save_state.sh"), key, val])
    }
    function rebuildFilters() {
        var q = filterInput.text.trim()
        var pool = window.segValues[window.segIndex] === "videos" ? videoExts
                 : window.segValues[window.segIndex] === "images" ? imageExts
                 : imageExts.concat(videoExts)
        var pats = []
        for (var i = 0; i < pool.length; i++) {
            var ext = pool[i]
            if (q === "") { pats.push("*." + ext); pats.push("*." + ext.toUpperCase()) }
            else { pats.push("*" + q + "*." + ext); pats.push("*" + q + "*." + ext.toUpperCase()) }
        }
        localModel.nameFilters = pats
    }
    function applySort(name) {
        if (name === "time") localModel.sortField = FolderListModel.Time
        else if (name === "size") localModel.sortField = FolderListModel.Size
        else localModel.sortField = FolderListModel.Name
    }
    function runStatic(p) {
        if (window.themeOn) wpSvc.applyWallpaper(p)
        else Quickshell.execDetached(["awww", "img", p])
        saveState("last", p)
        showToast("Wallpaper set" + (window.themeOn ? " · theme applied" : ""))
    }
    function runVideo(p) {
        Quickshell.execDetached([Quickshell.shellPath("wallpaper/set_video.sh"), p])
        saveState("last", p)
        showToast("Video wallpaper set")
    }
    function closePanel() { root.overlayView = "island" }

    Timer {
        id: statusTimer
        interval: 2600
        onTriggered: window.showStatus = false
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", window.baseDir])
        window.currentFolder = window.baseDir
    }

    Keys.onPressed: {
        if (event.key === Qt.Key_Escape) {
            closePanel(); event.accepted = true
        }
    }

    // restore persisted wallpaper folder on startup
    Process {
        id: loadDirProc
        running: true
        command: ["sh", "-c", "cat \"$HOME/.local/state/quickshell/wallpaper_picker/dir.txt\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var d = this.text.trim()
                if (d !== "") { window.baseDir = d; window.currentFolder = d }
            }
        }
    }

    FolderListModel {
        id: localModel
        folder: toFileUrl(window.currentFolder)
        showDirs: false
        showFiles: true
        showDotAndDotDot: false
        sortField: FolderListModel.Name
        nameFilters: ["*.jpg","*.jpeg","*.png","*.webp","*.gif","*.bmp",
                      "*.JPG","*.JPEG","*.PNG","*.WEBP","*.MP4","*.WEBM","*.MOV",
                      "*.mp4","*.webm","*.mov"]
    }

    FolderDialog {
        id: folderDialog
        title: "Choose wallpaper folder"
        currentFolder: toFileUrl(window.currentFolder)
        onAccepted: {
            var p = folderDialog.selectedFolder.toString().replace(/^file:\/\//, "")
            window.currentFolder = p
            saveState("dir", p)
            window.browseOpen = false
        }
    }

    // ==========================================
    // BROWSE VIEW (chromeless sheet, identical to MovieWidget)
    // ==========================================
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
        visible: window.currentView === "search"
        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ---------- toolbar container (identical height/structure to MovieWidget) ----------
            Rectangle {
                Layout.alignment: Qt.AlignTop; Layout.fillWidth: true
                Layout.preferredHeight: window.s(120) + (window.browseOpen ? window.s(104) : 0)
                Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutQuart } }
                color: "transparent"
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: window.s(15); spacing: window.s(10)
                    RowLayout {
                        Layout.fillWidth: true; spacing: window.s(15)
                        // segmented control: All | Images | Videos
                        Rectangle {
                            Layout.preferredWidth: window.s(200); Layout.preferredHeight: window.s(36)
                            radius: window.rLG(); color: window.surface0
                            Rectangle {
                                id: segHighlight
                                height: parent.height - window.s(6)
                                width: (parent.width - window.s(6)) / 3
                                y: window.s(3); radius: window.rMD(); color: window.text; z: 0
                                property real targetX: window.s(3) + window.segIndex * ((parent.width - window.s(6)) / 3)
                                property real actualX: targetX
                                Behavior on actualX { NumberAnimation { duration: 340; easing.type: Easing.OutExpo } }
                                x: actualX
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    shadowEnabled: true; shadowColor: window.shadowColor
                                    shadowBlur: 0.6; shadowVerticalOffset: 2; shadowOpacity: 0.28
                                }
                            }
                            RowLayout {
                                anchors.fill: parent; spacing: 0
                                Repeater {
                                    model: [["all","All"],["images","Images"],["videos","Videos"]]
                                    MouseArea {
                                        Layout.fillWidth: true; Layout.fillHeight: true
                                        onClicked: { window.segIndex = index; rebuildFilters() }
                                        Text {
                                            anchors.centerIn: parent; text: modelData[1]
                                            font.family: window.fontUI
                                            font.weight: window.segIndex === index ? Font.DemiBold : Font.Medium
                                            font.pixelSize: window.s(13)
                                            color: window.segIndex === index ? window.base : window.subtext0
                                            Behavior on color { ColorAnimation { duration: 200 } }
                                        }
                                    }
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            Layout.preferredWidth: window.s(88); Layout.preferredHeight: window.s(36); radius: window.rLG()
                            color: window.browseOpen ? window.text : (browseBtnMouse.containsMouse ? window.surface1 : window.surface0)
                            Behavior on color { ColorAnimation { duration: 180 } }
                            RowLayout {
                                anchors.centerIn: parent; spacing: window.s(6)
                                Text { text: "📁"; font.pixelSize: window.s(12); color: window.browseOpen ? window.base : window.text }
                                Text { text: "Browse"; font.family: window.fontUI; font.weight: Font.Medium; font.pixelSize: window.s(12); color: window.browseOpen ? window.base : window.text }
                            }
                            MouseArea {
                                id: browseBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { window.browseOpen = !window.browseOpen; if (window.browseOpen) folderDialog.open() }
                            }
                        }
                        CustomComboBox {
                            id: sortSelector
                            Layout.preferredWidth: window.s(180)
                            model: ["Name", "Date", "Size"]
                            onActivated: { window.applySort(["name","time","size"][index]) }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: window.browseOpen ? window.s(100) : 0
                        clip: true
                        radius: window.rMD()
                        color: window.surface0
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 260; easing.type: Easing.OutExpo } }
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: window.s(14); spacing: window.s(10)
                            opacity: window.browseOpen ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                            RowLayout {
                                Layout.fillWidth: true; spacing: window.s(10)
                                Text { text: "SORT"; font.family: window.fontUI; font.pixelSize: window.s(10); font.weight: Font.DemiBold; font.letterSpacing: 0.8; color: window.subtext0; Layout.preferredWidth: window.s(42) }
                                Repeater {
                                    model: [["name","Name"],["time","Date"],["size","Size"]]
                                    Rectangle {
                                        Layout.preferredWidth: window.s(72); Layout.preferredHeight: window.s(28); radius: height / 2
                                        property bool on: (["name","time","size"][localModel.sortField === FolderListModel.Name ? 0 : (localModel.sortField === FolderListModel.Time ? 1 : 2)] === modelData[0])
                                        color: on ? window.text : window.surface1
                                        Behavior on color { ColorAnimation { duration: 180 } }
                                        Text { anchors.centerIn: parent; text: modelData[1]; color: on ? window.base : window.subtext0; font.family: window.fontUI; font.pixelSize: window.s(11); font.weight: Font.Medium }
                                        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { window.applySort(modelData[0]); window.browseOpen = false } }
                                    }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true; spacing: window.s(10)
                                Text { text: "THEME"; font.family: window.fontUI; font.pixelSize: window.s(10); font.weight: Font.DemiBold; font.letterSpacing: 0.8; color: window.subtext0; Layout.preferredWidth: window.s(42) }
                                Rectangle {
                                    Layout.preferredWidth: window.s(96); Layout.preferredHeight: window.s(28); radius: height / 2
                                    color: window.themeOn ? window.accent : window.surface1
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                    Text { anchors.centerIn: parent; text: window.themeOn ? "Matugen On" : "Matugen Off"; color: window.themeOn ? window.base : window.subtext0; font.family: window.fontUI; font.pixelSize: window.s(11); font.weight: Font.Medium }
                                    MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { window.themeOn = !window.themeOn } }
                                }
                            }
                        }
                    }
                    TextField {
                        id: filterInput
                        Layout.fillWidth: true; Layout.preferredHeight: window.s(44)
                        background: Rectangle {
                            color: filterInput.activeFocus ? window.surface1 : window.surface0
                            radius: height / 2
                            border.color: filterInput.activeFocus ? window.accent : "transparent"
                            border.width: filterInput.activeFocus ? 2 : 0
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Behavior on border.color { ColorAnimation { duration: 200 } }
                            Text {
                                text: "⌕"
                                anchors.left: parent.left; anchors.leftMargin: window.s(16)
                                anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: window.s(17); font.weight: Font.DemiBold
                                color: window.subtext0
                            }
                        }
                        color: window.text; font.family: window.fontUI; font.pixelSize: window.s(15); leftPadding: window.s(38)
                        placeholderText: "Filter wallpapers…"
                        placeholderTextColor: window.subtext0
                        verticalAlignment: TextInput.AlignVCenter
                        onTextChanged: rebuildFilters()
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.5) }

            // ---------- content ----------
            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                GridView {
                    id: wallGrid
                    anchors.fill: parent
                    model: localModel
                    cellWidth: Math.floor(width / 5)
                    cellHeight: cellWidth * 0.62 + window.s(44)
                    boundsBehavior: Flickable.StopAtBounds
                    highlightFollowsCurrentItem: false
                    clip: true
                    Behavior on contentY { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }
                    highlight: gridHighlightComp
                    header: wpHeaderComp
                    delegate: wallDelegate
                }
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: window.s(8)
                    visible: localModel.count === 0
                    Text { Layout.alignment: Qt.AlignHCenter; text: "🖼"; font.pixelSize: window.s(40); font.weight: Font.Light; color: window.subtext0; opacity: 0.5 }
                    Text { Layout.alignment: Qt.AlignHCenter; text: "No wallpapers in this folder"; color: window.text; font.family: window.fontUI; font.weight: Font.DemiBold; font.pixelSize: window.s(16) }
                    Text { Layout.alignment: Qt.AlignHCenter; text: "Drop images into " + window.baseDir + " or hit Browse."; color: window.subtext0; font.family: window.fontUI; font.pixelSize: window.s(12) }
                }
            }
        }
    }

    // --- toast (shared) ---
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

    component CustomComboBox: ComboBox {
        id: control
        font.family: window.fontUI; font.pixelSize: window.s(14)
        delegate: ItemDelegate {
            width: control.width; height: window.s(36)
            contentItem: Text { text: modelData || model.name; color: window.text; font: control.font; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: control.highlightedIndex === index ? window.surface1 : "transparent"; radius: window.s(10) }
        }
        indicator: Canvas {
            id: canvas
            x: control.width - width - control.rightPadding; y: control.topPadding + (control.availableHeight - height) / 2
            width: 12; height: 8; contextType: "2d"
            Connections { target: control; function onPressedChanged() { canvas.requestPaint() } }
            onPaint: { var ctx = canvas.getContext("2d"); ctx.reset(); ctx.moveTo(0, 0); ctx.lineTo(width, 0); ctx.lineTo(width / 2, height); ctx.fillStyle = window.subtext0; ctx.fill() }
        }
        contentItem: Text { leftPadding: window.s(10); rightPadding: control.indicator.width + control.spacing; text: control.currentText; font: control.font; color: window.text; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
        background: Rectangle { implicitWidth: window.s(180); implicitHeight: window.s(36); color: window.surface0; border.color: control.activeFocus ? window.surface2 : window.surface1; border.width: control.visualFocus ? 2 : 1; radius: height / 2 }
        popup: Popup {
            y: control.height + window.s(4); width: control.width; implicitHeight: contentItem.implicitHeight; padding: window.s(4)
            contentItem: ListView { clip: true; implicitHeight: contentHeight; model: control.popup.visible ? control.delegateModel : null; currentIndex: control.highlightedIndex }
            background: Rectangle { color: window.crust; border.color: window.surface1; radius: window.s(14) }
        }
    }

    component wallDelegate: Rectangle {
        id: delegateRoot
        width: GridView.view.cellWidth; height: GridView.view.cellHeight; z: 1
        readonly property string _src: model.fileURL ? model.fileURL : ""
        readonly property string _apply: model.filePath ? model.filePath : ""
        readonly property string _name: model.fileName ? model.fileName : ""
        property bool _vid: isVideoPath(_apply)
        property bool _sel: window.selectedPath === _apply
        readonly property bool posterReady: img.status === Image.Ready

        Rectangle {
            id: cardRoot
            anchors.fill: parent; anchors.margins: window.s(6)
            radius: window.rMD(); color: window.crust; clip: true
            border.color: _sel ? window.accent : "transparent"
            border.width: _sel ? 2 : 0
            readonly property bool lifted: cardMouse.containsMouse || _sel
            scale: lifted ? 1.035 : 1.0
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutExpo } }
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true; shadowColor: window.shadowColor
                shadowBlur: cardRoot.lifted ? 0.75 : 0.3
                shadowVerticalOffset: cardRoot.lifted ? 8 : 2
                shadowOpacity: cardRoot.lifted ? 0.42 : 0.18
                Behavior on shadowBlur { NumberAnimation { duration: 220 } }
                Behavior on shadowVerticalOffset { NumberAnimation { duration: 220 } }
                Behavior on shadowOpacity { NumberAnimation { duration: 220 } }
            }

            Image {
                id: img
                anchors.fill: parent
                source: _src
                fillMode: Image.PreserveAspectCrop
                asynchronous: true; smooth: true; cache: true
                sourceSize.width: window.s(360)
                visible: status === Image.Ready
            }
            Rectangle {
                anchors.fill: parent; color: window.surface0
                visible: _src === "" || img.status === Image.Error || img.status === Image.Loading
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
                anchors.margins: window.s(11)
                visible: img.status === Image.Ready
                text: _name
                color: "#ffffff"; font.family: window.fontUI; font.pixelSize: window.s(12.5); font.weight: Font.Medium
                elide: Text.ElideRight
            }
            Rectangle {
                visible: _vid
                anchors.top: parent.top; anchors.right: parent.right; anchors.margins: window.s(8)
                width: window.s(26); height: window.s(26); radius: window.s(13)
                color: Qt.rgba(0, 0, 0, 0.55)
                Text { anchors.centerIn: parent; text: "▶"; color: "#ffffff"; font.pixelSize: window.s(11) }
            }
            MouseArea {
                id: cardMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (_vid) runVideo(_apply)
                    else runStatic(_apply)
                }
            }
        }
    }

    Component {
        id: wpHeaderComp
        Item {
            width: GridView.view.width
            height: window.s(54)
            Column {
                anchors.left: parent.left; anchors.leftMargin: window.s(18)
                anchors.top: parent.top; anchors.topMargin: window.s(14); spacing: window.s(2)
                Text {
                    text: "Wallpapers"
                    color: window.text
                    font.family: window.fontUI; font.weight: Font.DemiBold; font.pixelSize: window.s(19); font.letterSpacing: -0.3
                }
                Text {
                    text: window.currentFolder
                    color: window.subtext0
                    font.family: window.fontUI; font.pixelSize: window.s(11)
                    elide: Text.ElideMiddle; width: Math.max(window.s(200), GridView.view.width - window.s(40))
                }
            }
        }
    }

    Component {
        id: gridHighlightComp
        Item {
            z: 0
            Rectangle {
                color: window.surface0; border.color: window.surface1; border.width: 1; radius: window.s(10)
                property real actX: parent.GridView.view.currentItem ? parent.GridView.view.currentItem.x + window.s(5) : 0
                property real actY: parent.GridView.view.currentItem ? parent.GridView.view.currentItem.y + window.s(5) : 0
                x: actX; y: actY; width: parent.GridView.view.cellWidth - window.s(10); height: parent.GridView.view.cellHeight - window.s(10)
                Behavior on actX { enabled: window.isKeyboardNav; NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
                Behavior on actY { enabled: window.isKeyboardNav; NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
                opacity: parent.GridView.view.count > 0 && parent.GridView.view.currentIndex >= 0 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }
        }
    }
}
