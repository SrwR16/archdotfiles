import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property int workMins: 25
    property int breakMins: 5
    property int sessions: 4
    
    property bool running: false
    property int currentSession: 1
    property int remainingSecs: workMins * 60
    property string phase: "FOCUS" // FOCUS, BREAK

    function formatTime(s) {
        let m = Math.floor(s / 60);
        let sec = s % 60;
        return (m < 10 ? "0" + m : m) + ":" + (sec < 10 ? "0" + sec : sec);
    }

    Timer {
        interval: 1000
        running: root.running
        repeat: true
        onTriggered: {
            if (root.remainingSecs > 0) {
                root.remainingSecs--;
            } else {
                root.running = false;
                if (root.phase === "FOCUS") {
                    root.phase = "BREAK";
                    root.remainingSecs = root.breakMins * 60;
                } else {
                    root.phase = "FOCUS";
                    root.currentSession++;
                    if (root.currentSession > root.sessions) root.currentSession = 1;
                    root.remainingSecs = root.workMins * 60;
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 24

        // Display
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.phase + " (" + root.currentSession + "/" + root.sessions + ")"
                font { family: "JetBrains Mono"; pixelSize: 16; weight: 700 }
                color: root.phase === "FOCUS" ? Theme.primary : "#A6E3A1" // Greenish for break
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: formatTime(root.remainingSecs)
                font { family: "JetBrains Mono"; pixelSize: 68; weight: Font.Black }
                color: Theme.text
            }
        }

        // Settings Grid
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            radius: 12
            color: Theme.surfaceLight
            border.width: 1
            border.color: Theme.surfaceVariant

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12

                Repeater {
                    model: [
                        { label: "Work (m)", val: root.workMins, step: 5, action: (v) => { root.workMins = v; if(!root.running && root.phase === "FOCUS") root.remainingSecs = v*60; } },
                        { label: "Break (m)", val: root.breakMins, step: 1, action: (v) => { root.breakMins = v; if(!root.running && root.phase === "BREAK") root.remainingSecs = v*60; } },
                        { label: "Sessions", val: root.sessions, step: 1, action: (v) => root.sessions = v }
                    ]
                    RowLayout {
                        Layout.preferredWidth: 240
                        Text { text: modelData.label; color: Theme.subtext; font.family: "JetBrains Mono"; font.pixelSize: 14; Layout.fillWidth: true }
                        
                        Rectangle {
                            width: 24; height: 24; radius: 6; color: Theme.surfaceVariant
                            Text { anchors.centerIn: parent; text: "-"; color: Theme.text; font { family: "JetBrains Mono"; pixelSize: 14 } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: modelData.action(Math.max(1, modelData.val - modelData.step)) }
                        }
                        
                        Text { text: modelData.val; color: Theme.text; font.family: "JetBrains Mono"; font.pixelSize: 16; font.weight: 700; Layout.minimumWidth: 24; horizontalAlignment: Text.AlignHCenter }
                        
                        Rectangle {
                            width: 24; height: 24; radius: 6; color: Theme.surfaceVariant
                            Text { anchors.centerIn: parent; text: "+"; color: Theme.text; font { family: "JetBrains Mono"; pixelSize: 14 } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: modelData.action(modelData.val + modelData.step) }
                        }
                    }
                }
            }
        }

        // Controls
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 20

            Rectangle {
                width: 50; height: 50; radius: 10
                color: Theme.surfaceLight
                border.width: 1; border.color: Theme.surfaceVariant
                Text { 
                    anchors.centerIn: parent
                    text: "󰑎" // Reset
                    color: Theme.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18 
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.running = false;
                        root.phase = "FOCUS";
                        root.currentSession = 1;
                        root.remainingSecs = root.workMins * 60;
                    }
                }
            }

            Rectangle {
                width: 64; height: 64; radius: 16
                color: Theme.primary
                Text {
                    anchors.centerIn: parent
                    text: root.running ? "󰏤" : "󰐊"
                    color: Theme.onPrimary; font { family: "JetBrainsMono Nerd Font"; pixelSize: 28 }
                    anchors.horizontalCenterOffset: root.running ? 0 : 2
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.running = !root.running
                }
            }
        }
    }
}
