import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

RowLayout {
    id: mediaSection
    spacing: 8

    property string trackTitle: "No Media"
    property string trackArtist: "Unknown Artist"
    property string trackArt: ""
    property string mediaState: "Idle"
    property var barHeights: [2, 2, 2, 2]
    property bool isHovered: false

    function checkHover() {
        var h = false;
        if (typeof prevMouse !== "undefined") h = h || prevMouse.containsMouse;
        if (typeof playMouse !== "undefined") h = h || playMouse.containsMouse;
        if (typeof nextMouse !== "undefined") h = h || nextMouse.containsMouse;
        isHovered = h;
    }

    Process { id: prevProc; command: ["playerctl", "previous"] }
    Process { id: playProc; command: ["playerctl", "play-pause"] }
    Process { id: nextProc; command: ["playerctl", "next"] }

    Rectangle {
        width: 48
        height: 48
        radius: 12
        color: Theme.surfaceLight
        clip: true

        Image {
            anchors.fill: parent
            source: mediaSection.trackArt || ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 96
            sourceSize.height: 96

            Rectangle {
                anchors.fill: parent
                color: Theme.surfaceLight
                visible: parent.status !== Image.Ready

                Text {
                    anchors.centerIn: parent
                    text: "󰎆"
                    color: Theme.primary
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 20 }
                }
            }
        }

        // Cava Waveform Overlay on Album Art
        Rectangle {
            anchors.fill: parent
            color: "#66000000" // Semi-transparent black overlay
            visible: mediaSection.mediaState === "Playing"

            Row {
                anchors.centerIn: parent
                spacing: 4
                height: 24

                Rectangle { width: 4; height: Math.min(24, mediaSection.barHeights[0] * 2); radius: 2; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 4; height: Math.min(24, mediaSection.barHeights[1] * 2); radius: 2; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 4; height: Math.min(24, mediaSection.barHeights[2] * 2); radius: 2; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 4; height: Math.min(24, mediaSection.barHeights[3] * 2); radius: 2; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    ColumnLayout {
        spacing: 4
        Layout.alignment: Qt.AlignVCenter

        Text {
            text: mediaSection.trackTitle
            color: mediaSection.mediaState === "Idle" ? Theme.subtext : Theme.text
            opacity: mediaSection.mediaState === "Idle" ? 0.6 : 1.0
            elide: Text.ElideRight
            Layout.maximumWidth: 140
            font { family: "Inter"; pixelSize: 14; weight: 600 }
        }

        RowLayout {
            spacing: 20
            visible: mediaSection.mediaState !== "Idle"

            Text {
                text: "󰒮"
                color: prevMouse.containsMouse ? Theme.primary : Theme.text
                opacity: prevMouse.containsMouse ? 1.0 : 0.7
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 20 }
                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: prevProc.running = true
                    onContainsMouseChanged: mediaSection.checkHover()
                }
            }
            Text {
                text: mediaSection.mediaState === "Playing" ? "󰏤" : "󰐊"
                color: playMouse.containsMouse ? Theme.primary : Theme.text
                opacity: playMouse.containsMouse ? 1.0 : 0.9
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 26 }
                MouseArea {
                    id: playMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: playProc.running = true
                    onContainsMouseChanged: mediaSection.checkHover()
                }
            }
            Text {
                text: "󰒭"
                color: nextMouse.containsMouse ? Theme.primary : Theme.text
                opacity: nextMouse.containsMouse ? 1.0 : 0.7
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 20 }
                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: nextProc.running = true
                    onContainsMouseChanged: mediaSection.checkHover()
                }
            }
        }
    }
}
