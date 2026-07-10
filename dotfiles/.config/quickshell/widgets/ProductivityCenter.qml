import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: prodCenter
    property bool isOpen: false
    property string page: "time"
    signal requestClose()
    
    visible: isOpen
    implicitHeight: 450

    property int activeMode: 0 // 0: Timer, 1: Stopwatch, 2: Pomodoro

    Item {
        anchors.fill: parent
        clip: true

        // ---- CALENDAR PAGE ----
        Item {
            anchors.fill: parent
            anchors.margins: 20
            visible: prodCenter.page === "calendar"
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 16
                
                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: "󰅁"
                        color: Theme.text
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
                        MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: prodCenter.requestClose() }
                    }
                    Text { text: "Calendar"; color: Theme.text; font.family: "Inter"; font.pixelSize: 15; font.weight: 700; Layout.fillWidth: true }
                }
                
                CalendarWidget { Layout.fillWidth: true; Layout.fillHeight: true }
            }
        }

        // ---- TIME PAGE (TABBED UI) ----
        Item {
            anchors.fill: parent
            anchors.margins: 20
            visible: prodCenter.page === "time"

            // Header + Tab Bar
            Rectangle {
                id: tabBar
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: 340
                height: 36
                radius: 10
                color: Theme.surfaceLight
                border.width: 1
                border.color: Theme.surfaceVariant
                z: 10

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: -32
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰅁"
                    color: Theme.text
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
                    MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: prodCenter.requestClose() }
                }

                Rectangle {
                    id: tabActiveHighlight
                    y: 2
                    height: 32
                    radius: 8
                    color: Theme.primary
                    z: 0

                    property int prevIdx: 0
                    property int curIdx: prodCenter.activeMode
                    onCurIdxChanged: {
                        if (curIdx > prevIdx) { rightAnim.duration = 200; leftAnim.duration = 350; }
                        else if (curIdx < prevIdx) { leftAnim.duration = 200; rightAnim.duration = 350; }
                        prevIdx = curIdx;
                    }
                    property real stepSize: (parent.width - 4) / 3
                    property real targetLeft: 2 + (curIdx * stepSize)
                    property real targetRight: targetLeft + stepSize
                    property real actualLeft: targetLeft
                    property real actualRight: targetRight

                    Behavior on actualLeft { NumberAnimation { id: leftAnim; duration: 250; easing.type: Easing.OutExpo } }
                    Behavior on actualRight { NumberAnimation { id: rightAnim; duration: 250; easing.type: Easing.OutExpo } }

                    x: actualLeft
                    width: actualRight - actualLeft
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 2
                    z: 1

                    Repeater {
                        model: ["Timer", "Stopwatch", "Pomodoro"]
                        Item {
                            width: (tabBar.width - 4) / 3
                            height: parent.height
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font.family: "Inter"
                                font.bold: true
                                font.pixelSize: 12
                                color: prodCenter.activeMode === index ? Theme.onPrimary : Theme.text
                                Behavior on color { ColorAnimation { duration: 250 } }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: prodCenter.activeMode = index }
                        }
                    }
                }
            }

            // View Containers
            Item {
                anchors.top: tabBar.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 20

                Item {
                    anchors.fill: parent
                    visible: prodCenter.activeMode === 0
                    opacity: visible ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                    TimerWidget { anchors.fill: parent }
                }
                Item {
                    anchors.fill: parent
                    visible: prodCenter.activeMode === 1
                    opacity: visible ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                    StopwatchWidget { anchors.fill: parent }
                }
                Item {
                    anchors.fill: parent
                    visible: prodCenter.activeMode === 2
                    opacity: visible ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                    PomodoroConfigWidget { anchors.fill: parent }
                }
            }
        }
    }
}
