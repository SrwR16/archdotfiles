import "./services"
import "./widgets"
import "./theme"
import QtQuick
import QtQuick.Layouts
import Quickshell

FloatingWindow {
  id: root
  visible: true
  flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
  color: "transparent"
  width: 620
  height: 480

  WallpaperService { id: wallpaperSvc }

  Component.onCompleted: {
    var s = root.screen
    root.x = (s.width - width) / 2
    root.y = (s.height - height) / 2
    wallpaperSvc.rescan()
  }

  Keys.onEscapePressed: Qt.quit()

  Rectangle {
    anchors.fill: parent
    radius: 20
    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.65)
    border.width: 1
    border.color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.25)

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 16
      spacing: 12

      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          text: "󰸉"
          color: Theme.tertiary
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
        }

        Text {
          text: "Wallpapers"
          color: Theme.text
          font { family: "Inter"; pixelSize: 16; weight: Font.Bold }
          Layout.fillWidth: true
        }

        Text {
          text: "✕"
          color: Theme.text
          opacity: 0.5
          font.pixelSize: 14
          MouseArea {
            anchors.fill: parent
            anchors.margins: -8
            cursorShape: Qt.PointingHandCursor
            onClicked: Qt.quit()
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 12
        color: Theme.container
        clip: true

        WallpaperGrid {
          anchors.fill: parent
          anchors.margins: 8
          wallpaperModel: root.wallpaperSvc.wallpapers
          wallService: root.wallpaperSvc
          onWallpaperChosen: Qt.callLater(Qt.quit)
        }
      }
    }
  }
}
