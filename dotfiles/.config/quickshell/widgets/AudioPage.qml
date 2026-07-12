import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
  id: sv
  padding: 0
  ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
  ScrollBar.vertical.policy: ScrollBar.AsNeeded
  contentWidth: width

  property var audioSinks: []
  property var audioSink: null
  property var audioSources: []
  property var audioSource: null
  property real audioVolume: 0
  property bool audioMuted: false
  property real audioSourceVolume: 0
  property bool audioSourceMuted: false
  property var volumeIcon: null

  signal backRequested()
  signal setVolume(real vol)
  signal toggleMute()
  signal setAudioSourceVolume(real vol)
  signal toggleAudioSourceMute()
  signal setDefaultSink(var node)
  signal setDefaultSource(var node)

  readonly property var _activeSink: audioSink
    || (audioSinks.length ? audioSinks[0] : null)
  readonly property var _activeSource: audioSource
    || (audioSources.length ? audioSources[0] : null)

  ColumnLayout {
    width: parent.width
    spacing: 12

    // ============ OUTPUT MASTER ============
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: outCol.implicitHeight + 28
      opacity: 0
      SequentialAnimation on opacity {
  PauseAnimation { duration: 0 }
  NumberAnimation { from: 0; to: 1; duration: Motion.durM; easing.type: Motion.easeStandard; objectName: "entrance" }
}

      Rectangle {
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.85)
        border.color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.85)
        border.width: 1
      }

      ColumnLayout {
        id: outCol
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
          Layout.fillWidth: true
          spacing: 12

          Rectangle {
            width: 42; height: 42; radius: 13
            color: audioMuted ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.16)
                                    : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
            Text {
              anchors.centerIn: parent
              text: volumeIcon ? volumeIcon(audioVolume, audioMuted) : "󰓃"
              color: audioMuted ? Theme.error : Theme.primary
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 20
            }
          }
          ColumnLayout {
            spacing: 1
            Layout.fillWidth: true

            Text {
              text: "Output"
              color: Theme.subtext
              font.family: "Inter"
              font.pixelSize: 10
              font.weight: 600
            }
            Text {
              text: _activeSink ? (_activeSink.description || _activeSink.name) : "No output"
              color: Theme.text
              elide: Text.ElideRight
              Layout.fillWidth: true
              font.family: "Inter"
              font.pixelSize: 13
              font.weight: 700
            }
          }
          Text {
            text: (audioMuted ? 0 : Math.round(audioVolume * 100)) + "%"
            color: Theme.text
            font.family: "Inter"
            font.pixelSize: 13
            font.weight: 700
          }
          RowLayout {
            spacing: 3
            Repeater {
              model: 14
              Rectangle {
                required property int index
                width: 4; height: 22; radius: 2
                color: {
                  var lit = (audioMuted ? 0 : audioVolume) * 14 > index
                  if (!lit) return Theme.outline
                  var f = index / 13
                  return f > 0.85 ? Theme.error : (f > 0.65 ? Theme.warning : Theme.primary)
                }
              }
            }
          }
          Rectangle {
            width: 38; height: 38; radius: 12
            color: muteOut.containsMouse ? Theme.surfaceHover : Theme.surfaceLight
            Behavior on color { ColorAnimation { duration: Motion.durXS } }

            Text {
              anchors.centerIn: parent
              text: audioMuted ? "󰝟" : "󰕾"
              color: audioMuted ? Theme.error : Theme.text
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 16
            }
            MouseArea {
              id: muteOut
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: toggleMute()
            }
          }
        }

        IconSlider {
          Layout.fillWidth: true
          iconText: ""
          value: audioMuted ? 0 : audioVolume
          onMoved: val => setVolume(val)
        }
      }
    }

    // ============ OUTPUT DEVICES ============
    Text {
      text: "Output Devices"
      color: Theme.muted
      font.family: "Inter"
      font.pixelSize: 11
      font.weight: 700
      leftPadding: 4
      opacity: 0
      SequentialAnimation on opacity {
  PauseAnimation { duration: 60 }
  NumberAnimation { from: 0; to: 1; duration: Motion.durM; easing.type: Motion.easeStandard; objectName: "entrance" }
}
    }

    Repeater {
      model: audioSinks

      QsCard {
        required property var modelData
        Layout.fillWidth: true
        Layout.preferredHeight: 48
        highlighted: modelData === audioSink
        onClicked: setDefaultSink(modelData)

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 14
          anchors.rightMargin: 14
          spacing: 10

          Text {
            text: "󰓃"
            color: modelData === audioSink ? Theme.primary : Theme.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
              text: modelData.description || modelData.name || ""
              color: Theme.text
              elide: Text.ElideRight
              Layout.fillWidth: true
              font.family: "Inter"
              font.pixelSize: 12
              font.weight: modelData === audioSink ? 600 : 400
            }
            Text {
              text: modelData.nickname || ""
              visible: text !== ""
              color: Theme.subtext
              elide: Text.ElideRight
              Layout.fillWidth: true
              font.family: "Inter"
              font.pixelSize: 9
            }
          }
          Text {
            text: modelData === audioSink ? "✓" : ""
            color: Theme.primary
            font.family: "Inter"
            font.pixelSize: 13
            font.weight: 700
          }
        }
      }
    }

    Item { Layout.preferredHeight: 6 }

    // ============ INPUT MASTER ============
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: inCol.implicitHeight + 28
      opacity: 0
      SequentialAnimation on opacity {
  PauseAnimation { duration: 120 }
  NumberAnimation { from: 0; to: 1; duration: Motion.durM; easing.type: Motion.easeStandard; objectName: "entrance" }
}

      Rectangle {
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.85)
        border.color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.85)
        border.width: 1
      }

      ColumnLayout {
        id: inCol
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
          Layout.fillWidth: true
          spacing: 12

          Rectangle {
            width: 42; height: 42; radius: 13
            color: audioSourceMuted ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.16)
                                        : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
            Text {
              anchors.centerIn: parent
              text: "󰍬"
              color: audioSourceMuted ? Theme.error : Theme.primary
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 20
            }
          }
          ColumnLayout {
            spacing: 1
            Layout.fillWidth: true

            Text {
              text: "Input"
              color: Theme.subtext
              font.family: "Inter"
              font.pixelSize: 10
              font.weight: 600
            }
            Text {
              text: _activeSource ? (_activeSource.description || _activeSource.name) : "No input"
              color: Theme.text
              elide: Text.ElideRight
              Layout.fillWidth: true
              font.family: "Inter"
              font.pixelSize: 13
              font.weight: 700
            }
          }
          Text {
            text: (audioSourceMuted ? 0 : Math.round(audioSourceVolume * 100)) + "%"
            color: Theme.text
            font.family: "Inter"
            font.pixelSize: 13
            font.weight: 700
          }
          RowLayout {
            spacing: 3
            Repeater {
              model: 14
              Rectangle {
                required property int index
                width: 4; height: 22; radius: 2
                color: {
                  var lit = (audioSourceMuted ? 0 : audioSourceVolume) * 14 > index
                  if (!lit) return Theme.outline
                  var f = index / 13
                  return f > 0.85 ? Theme.error : (f > 0.65 ? Theme.warning : Theme.primary)
                }
              }
            }
          }
          Rectangle {
            width: 38; height: 38; radius: 12
            color: muteIn.containsMouse ? Theme.surfaceHover : Theme.surfaceLight
            Behavior on color { ColorAnimation { duration: Motion.durXS } }

            Text {
              anchors.centerIn: parent
              text: audioSourceMuted ? "󰝟" : "󰕾"
              color: audioSourceMuted ? Theme.error : Theme.text
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 16
            }
            MouseArea {
              id: muteIn
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: toggleAudioSourceMute()
            }
          }
        }

        IconSlider {
          Layout.fillWidth: true
          iconText: ""
          value: audioSourceMuted ? 0 : audioSourceVolume
          onMoved: val => setAudioSourceVolume(val)
        }
      }
    }

    // ============ INPUT DEVICES ============
    Text {
      text: "Input Devices"
      color: Theme.muted
      font.family: "Inter"
      font.pixelSize: 11
      font.weight: 700
      leftPadding: 4
      opacity: 0
      SequentialAnimation on opacity {
  PauseAnimation { duration: 180 }
  NumberAnimation { from: 0; to: 1; duration: Motion.durM; easing.type: Motion.easeStandard; objectName: "entrance" }
}
    }

    Repeater {
      model: audioSources

      QsCard {
        required property var modelData
        Layout.fillWidth: true
        Layout.preferredHeight: 48
        highlighted: modelData === audioSource
        onClicked: setDefaultSource(modelData)

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 14
          anchors.rightMargin: 14
          spacing: 10

          Text {
            text: "󰍬"
            color: modelData === audioSource ? Theme.primary : Theme.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
              text: modelData.description || modelData.name || ""
              color: Theme.text
              elide: Text.ElideRight
              Layout.fillWidth: true
              font.family: "Inter"
              font.pixelSize: 12
              font.weight: modelData === audioSource ? 600 : 400
            }
            Text {
              text: modelData.nickname || ""
              visible: text !== ""
              color: Theme.subtext
              elide: Text.ElideRight
              Layout.fillWidth: true
              font.family: "Inter"
              font.pixelSize: 9
            }
          }
          Text {
            text: modelData === audioSource ? "✓" : ""
            color: Theme.primary
            font.family: "Inter"
            font.pixelSize: 13
            font.weight: 700
          }
        }
      }
    }

    Item { Layout.preferredHeight: 4 }
  }
}
