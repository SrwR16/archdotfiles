import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Layouts

Item {
    id: stopwatchWidget

    property bool isRunning: false
    property var lapData: []
    property real startMs: 0
    property real currentDisplayMs: 0
    property real elapsedBeforePause: 0

    function formatTime(ms) {
        let date = new Date(ms);
        let m = Math.floor(ms / 60000);
        let s = Math.floor((ms % 60000) / 1000);
        let ms_part = Math.floor((ms % 1000) / 10);
        
        return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s) + "." + (ms_part < 10 ? "0" + ms_part : ms_part);
    }

    Timer {
        interval: 16
        running: stopwatchWidget.isRunning
        repeat: true
        onTriggered: {
            stopwatchWidget.currentDisplayMs = stopwatchWidget.elapsedBeforePause + (Date.now() - stopwatchWidget.startMs);
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // Time Display
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: formatTime(stopwatchWidget.currentDisplayMs)
            font { family: "JetBrains Mono"; pixelSize: 68; weight: Font.Black }
            color: Theme.text
        }

        // Laps List
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            color: "transparent"
            clip: true
            visible: stopwatchWidget.lapData.length > 0

            ListView {
                id: lapList
                anchors.fill: parent
                model: stopwatchWidget.lapData.length
                spacing: 8
                
                delegate: Rectangle {
                    width: lapList.width
                    height: 36
                    radius: 10
                    color: Theme.surfaceLight
                    border.width: 1
                    border.color: Theme.surfaceVariant
                    
                    property int trueIdx: stopwatchWidget.lapData.length - 1 - index
                    property var lapItem: stopwatchWidget.lapData[trueIdx]

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        Text { text: "Lap " + (trueIdx + 1); color: Theme.subtext; font.family: "JetBrains Mono"; font.pixelSize: 14; font.weight: 700; Layout.fillWidth: true }
                        Text { text: lapItem ? "+" + formatTime(lapItem.diff) : ""; color: Theme.primary; font.family: "JetBrains Mono"; font.pixelSize: 14 }
                        Text { text: lapItem ? formatTime(lapItem.total) : ""; color: Theme.text; font.family: "JetBrains Mono"; font.pixelSize: 14; font.weight: 700; Layout.alignment: Qt.AlignRight }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

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
                    text: stopwatchWidget.isRunning ? "󰑐" : "󰑎" // Lap (Flag) / Reset
                    color: Theme.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18 
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (stopwatchWidget.isRunning) {
                            let nowMs = stopwatchWidget.currentDisplayMs;
                            let lastMs = stopwatchWidget.lapData.length > 0 ? stopwatchWidget.lapData[stopwatchWidget.lapData.length - 1].total : 0;
                            let temp = stopwatchWidget.lapData.slice();
                            temp.push({ total: nowMs, diff: nowMs - lastMs });
                            stopwatchWidget.lapData = temp;
                        } else {
                            stopwatchWidget.lapData = [];
                            stopwatchWidget.currentDisplayMs = 0;
                            stopwatchWidget.elapsedBeforePause = 0;
                        }
                    }
                }
            }

            Rectangle {
                width: 64; height: 64; radius: 16
                color: Theme.primary
                Text {
                    anchors.centerIn: parent
                    text: stopwatchWidget.isRunning ? "󰏤" : "󰐊"
                    color: Theme.onPrimary; font { family: "JetBrainsMono Nerd Font"; pixelSize: 28 }
                    anchors.horizontalCenterOffset: stopwatchWidget.isRunning ? 0 : 2
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (stopwatchWidget.isRunning) {
                            stopwatchWidget.elapsedBeforePause = stopwatchWidget.currentDisplayMs;
                        } else {
                            stopwatchWidget.startMs = Date.now();
                        }
                        stopwatchWidget.isRunning = !stopwatchWidget.isRunning;
                    }
                }
            }
        }
    }
}
