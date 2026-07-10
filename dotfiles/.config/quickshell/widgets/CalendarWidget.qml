import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: calendarWidget
    spacing: 16

    property date today: new Date()
    property int currentMonth: today.getMonth()
    property int currentYear: today.getFullYear()
    
    // Array of day objects { date: int, isCurrentMonth: bool, isToday: bool }
    property var days: []

    function updateCalendar() {
        let firstDay = new Date(currentYear, currentMonth, 1).getDay();
        let daysInMonth = new Date(currentYear, currentMonth + 1, 0).getDate();
        let daysInPrevMonth = new Date(currentYear, currentMonth, 0).getDate();
        
        let newDays = [];
        // Previous month days
        for (let i = firstDay - 1; i >= 0; i--) {
            newDays.push({ date: daysInPrevMonth - i, isCurrentMonth: false, isToday: false });
        }
        // Current month days
        for (let i = 1; i <= daysInMonth; i++) {
            let isToday = (i === today.getDate() && currentMonth === today.getMonth() && currentYear === today.getFullYear());
            newDays.push({ date: i, isCurrentMonth: true, isToday: isToday });
        }
        // Next month days
        let remaining = 42 - newDays.length;
        for (let i = 1; i <= remaining; i++) {
            newDays.push({ date: i, isCurrentMonth: false, isToday: false });
        }
        days = newDays;
    }

    Component.onCompleted: updateCalendar()

    RowLayout {
        Layout.fillWidth: true
        
        Text {
            text: Qt.formatDateTime(new Date(currentYear, currentMonth, 1), "MMMM yyyy")
            color: Theme.text
            font { family: "JetBrains Mono"; pixelSize: 18; weight: 700 }
            Layout.fillWidth: true
        }

        RowLayout {
            spacing: 8
            Rectangle {
                width: 24; height: 24; radius: 12; color: prevMouse.containsMouse ? Theme.surfaceLight : "transparent"
                Text { anchors.centerIn: parent; text: "󰅁"; color: Theme.text; font.family: "JetBrainsMono Nerd Font" }
                MouseArea { id: prevMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { currentMonth--; if(currentMonth<0){currentMonth=11;currentYear--;} updateCalendar(); } }
            }
            Rectangle {
                width: 24; height: 24; radius: 12; color: nextMouse.containsMouse ? Theme.surfaceLight : "transparent"
                Text { anchors.centerIn: parent; text: "󰅂"; color: Theme.text; font.family: "JetBrainsMono Nerd Font" }
                MouseArea { id: nextMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { currentMonth++; if(currentMonth>11){currentMonth=0;currentYear++;} updateCalendar(); } }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Repeater {
            model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
            Text {
                text: modelData
                color: Theme.subtext
                font { family: "JetBrains Mono"; pixelSize: 12; weight: 700 }
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: 7
        rows: 6
        columnSpacing: 4
        rowSpacing: 4

        Repeater {
            model: calendarWidget.days
            
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: modelData.isToday ? Theme.primary : (dayMouse.containsMouse ? Theme.surfaceLight : "transparent")
                
                Text {
                    anchors.centerIn: parent
                    text: modelData.date
                    color: modelData.isToday ? Theme.onPrimary : (modelData.isCurrentMonth ? Theme.text : Theme.subtext)
                    opacity: modelData.isCurrentMonth ? 1.0 : 0.4
                    font { family: "JetBrains Mono"; pixelSize: 14; weight: modelData.isToday ? 700 : 500 }
                }

                MouseArea {
                    id: dayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }
        }
    }
}
