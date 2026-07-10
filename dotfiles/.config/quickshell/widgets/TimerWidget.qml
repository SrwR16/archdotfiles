import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: timerWidget

    property int remainingSeconds: 0
    property int setSeconds: 300 // 5 mins default
    property bool running: false

    function formatTime(s) {
        let m = Math.floor(s / 60);
        let sec = s % 60;
        return (m < 10 ? "0" + m : m) + ":" + (sec < 10 ? "0" + sec : sec);
    }

    Timer {
        interval: 1000
        running: timerWidget.running
        repeat: true
        onTriggered: {
            if (timerWidget.remainingSeconds > 0) {
                timerWidget.remainingSeconds--;
                if (timerWidget.remainingSeconds === 0) {
                    timerWidget.running = false;
                    notifyProc.command = ["notify-send", "-a", "Timer", "-i", "timer", "Timer Finished!", "Your timer is up!"];
                    notifyProc.running = true;
                }
            }
        }
    }

    Process { id: notifyProc }

    ColumnLayout {
        anchors.fill: parent
        spacing: 24

        // Circular progress + Big Text
        Item {
            Layout.alignment: Qt.AlignHCenter
            width: 200; height: 200
            
            Rectangle { anchors.fill: parent; radius: 100; color: Theme.surfaceContainer }
            Rectangle { width: 180; height: 180; radius: 90; anchors.centerIn: parent; color: Theme.background }

            Canvas {
                id: progressCanvas
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.beginPath();
                    var progress = setSeconds > 0 ? (setSeconds - remainingSeconds) / setSeconds : 0;
                    ctx.arc(width/2, height/2, 90, -Math.PI/2, -Math.PI/2 + (progress * 2 * Math.PI), false);
                    ctx.lineWidth = 10;
                    ctx.strokeStyle = Theme.primary;
                    ctx.lineCap = "round";
                    ctx.stroke();
                }
            }
            
            Timer {
                interval: 100
                running: timerWidget.running
                repeat: true
                onTriggered: progressCanvas.requestPaint()
            }

            Row {
                anchors.centerIn: parent
                spacing: 0
                
                Item {
                    width: minText.implicitWidth; height: minText.implicitHeight
                    Text {
                        id: minText
                        text: {
                            let t = timerWidget.remainingSeconds === 0 && !timerWidget.running ? timerWidget.setSeconds : timerWidget.remainingSeconds;
                            let m = Math.floor(t / 60);
                            return (m < 10 ? "0" + m : m);
                        }
                        color: (timerWidget.remainingSeconds === 0 && !timerWidget.running) ? Theme.primary : Theme.text
                        font.family: "JetBrains Mono"; font.pixelSize: 48; font.weight: Font.Black
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: !timerWidget.running ? Qt.SizeVerCursor : Qt.ArrowCursor
                        onWheel: (wheel) => {
                            if (timerWidget.running) return;
                            let m = Math.floor(timerWidget.setSeconds / 60);
                            let s = timerWidget.setSeconds % 60;
                            if (wheel.angleDelta.y > 0) m++; else m--;
                            if (m < 0) m = 0; if (m > 99) m = 99;
                            timerWidget.setSeconds = m * 60 + s;
                            timerWidget.remainingSeconds = timerWidget.setSeconds;
                            progressCanvas.requestPaint();
                        }
                    }
                }

                Text {
                    text: ":"
                    color: (timerWidget.remainingSeconds === 0 && !timerWidget.running) ? Theme.primary : Theme.text
                    font.family: "JetBrains Mono"; font.pixelSize: 48; font.weight: Font.Black
                }
                
                Item {
                    width: secText.implicitWidth; height: secText.implicitHeight
                    Text {
                        id: secText
                        text: {
                            let t = timerWidget.remainingSeconds === 0 && !timerWidget.running ? timerWidget.setSeconds : timerWidget.remainingSeconds;
                            let s = t % 60;
                            return (s < 10 ? "0" + s : s);
                        }
                        color: (timerWidget.remainingSeconds === 0 && !timerWidget.running) ? Theme.primary : Theme.text
                        font.family: "JetBrains Mono"; font.pixelSize: 48; font.weight: Font.Black
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: !timerWidget.running ? Qt.SizeVerCursor : Qt.ArrowCursor
                        onWheel: (wheel) => {
                            if (timerWidget.running) return;
                            let m = Math.floor(timerWidget.setSeconds / 60);
                            let s = timerWidget.setSeconds % 60;
                            if (wheel.angleDelta.y > 0) s++; else s--;
                            if (s < 0) s = 59; if (s > 59) s = 0;
                            timerWidget.setSeconds = m * 60 + s;
                            timerWidget.remainingSeconds = timerWidget.setSeconds;
                            progressCanvas.requestPaint();
                        }
                    }
                }
            }
            
            Text {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Scroll numbers to edit"
                color: Theme.subtext
                font.family: "Inter"; font.pixelSize: 10
                visible: !timerWidget.running
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 200 } }
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
                        timerWidget.running = false;
                        timerWidget.remainingSeconds = timerWidget.setSeconds;
                        progressCanvas.requestPaint();
                    }
                }
            }

            Rectangle {
                width: 64; height: 64; radius: 16
                color: Theme.primary
                Text {
                    anchors.centerIn: parent
                    text: timerWidget.running ? "󰏤" : "󰐊"
                    color: Theme.onPrimary; font { family: "JetBrainsMono Nerd Font"; pixelSize: 28 }
                    anchors.horizontalCenterOffset: timerWidget.running ? 0 : 2
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!timerWidget.running && timerWidget.remainingSeconds === 0) timerWidget.remainingSeconds = timerWidget.setSeconds;
                        timerWidget.running = !timerWidget.running;
                        progressCanvas.requestPaint();
                    }
                }
            }
        }
    }
}
