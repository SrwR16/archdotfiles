import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Layouts
import "."

RowLayout {
  id: pomodoroSection
  spacing: 16

  // Circular progress ring
  Item {
    width: 44
    height: 44
    Layout.alignment: Qt.AlignVCenter

    Rectangle {
      anchors.fill: parent
      radius: 22
      color: Theme.surfaceLight
    }

    Rectangle {
      width: 40; height: 40
      radius: 20
      anchors.centerIn: parent
      color: Theme.background
    }

    Canvas {
      id: progressCanvas
      anchors.fill: parent
      onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        ctx.beginPath()
        ctx.arc(width/2, height/2, 21, -Math.PI/2, -Math.PI/2 + (PomodoroService.progress * 2 * Math.PI), false)
        ctx.lineWidth = 2
        ctx.strokeStyle = PomodoroService.sessionState === "Work" ? Theme.primary : Theme.tertiary
        ctx.stroke()
      }
      Connections {
        target: PomodoroService
        function onProgressChanged() { progressCanvas.requestPaint() }
      }
    }

    Text {
      anchors.centerIn: parent
      text: ""
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 18
      color: PomodoroService.sessionState === "Work" ? Theme.primary : Theme.tertiary
    }
  }

  ColumnLayout {
    spacing: 2
    Layout.alignment: Qt.AlignVCenter

    Text {
      text: PomodoroService.sessionState === "Idle" ? "Focus Time" : (PomodoroService.sessionState === "Work" ? "Deep Work" : "Short Break")
      color: Theme.text
      font.family: "Inter"
      font.pixelSize: 14
      font.weight: 600
    }

    Text {
      text: PomodoroService.formatTime()
      color: Theme.subtext
      font.family: "JetBrains Mono"
      font.pixelSize: 22
      font.weight: 700
    }
  }

  Item { Layout.fillWidth: true }

  RowLayout {
    spacing: 12
    Layout.alignment: Qt.AlignVCenter

    Rectangle {
      width: 32; height: 32; radius: 16
      color: Theme.surfaceLight
      Text {
        anchors.centerIn: parent
        text: PomodoroService.sessionState === "Idle" || PomodoroService.isPaused ? "▶" : "⏸"
        color: Theme.text
        font.pixelSize: 14
      }
      MouseArea {
        anchors.fill: parent
        onClicked: PomodoroService.togglePause()
        cursorShape: Qt.PointingHandCursor
      }
    }

    Rectangle {
      width: 32; height: 32; radius: 16
      color: Theme.surfaceLight
      visible: PomodoroService.sessionState !== "Idle"
      Text {
        anchors.centerIn: parent
        text: "⏹"
        color: Theme.text
        font.pixelSize: 14
      }
      MouseArea {
        anchors.fill: parent
        onClicked: PomodoroService.stop()
        cursorShape: Qt.PointingHandCursor
      }
    }
  }
}
