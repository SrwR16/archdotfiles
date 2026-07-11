import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
  id: sv
  visible: false
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

  ColumnLayout {
    width: parent.width
    spacing: 10

    // ============ OUTPUT ============
    RowLayout {
      Layout.fillWidth: true
      Layout.leftMargin: 4
      spacing: 8

      Text {
        text: "Output"
        color: Theme.muted
        font.family: "Inter"
        font.pixelSize: 11
        font.weight: 700
      }
      Item { Layout.fillWidth: true }
      QsButton {
        text: audioMuted ? "Unmute" : "Mute"
        outline: true
        onClicked: toggleMute()
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

    IconSlider {
      Layout.fillWidth: true
      iconText: volumeIcon ? volumeIcon(audioVolume, audioMuted) : ""
      value: audioMuted ? 0 : audioVolume
      onMoved: val => setVolume(val)
    }

    Item { Layout.preferredHeight: 8 }

    // ============ INPUT ============
    RowLayout {
      Layout.fillWidth: true
      Layout.leftMargin: 4
      spacing: 8

      Text {
        text: "Input"
        color: Theme.muted
        font.family: "Inter"
        font.pixelSize: 11
        font.weight: 700
      }
      Item { Layout.fillWidth: true }
      QsButton {
        text: audioSourceMuted ? "Unmute" : "Mute"
        outline: true
        onClicked: toggleAudioSourceMute()
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

    IconSlider {
      Layout.fillWidth: true
      iconText: volumeIcon ? volumeIcon(audioSourceVolume, audioSourceMuted) : ""
      value: audioSourceMuted ? 0 : audioSourceVolume
      onMoved: val => setAudioSourceVolume(val)
    }

    Item { Layout.preferredHeight: 4 }
  }
}
