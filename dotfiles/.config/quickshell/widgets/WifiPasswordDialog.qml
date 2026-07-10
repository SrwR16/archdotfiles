import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root

  property string pendingSsid: ""
  property string connectError: ""
  property bool connecting: false

  signal dismiss()
  signal connectRequested(string ssid, string password)

  readonly property real bannerWidth: 480
  readonly property real bannerHeight: 220
  readonly property real bannerRadius: 28

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.5)
    opacity: root.visible ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }
  }

  Rectangle {
    anchors.centerIn: parent
    width: bannerWidth
    height: bannerHeight
    radius: bannerRadius
    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.12)
    border.color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.2)
    border.width: 1
    clip: true
    layer.enabled: true
    layer.samples: 4

    ColumnLayout {
      id: content
      anchors.fill: parent
      anchors.margins: 20
      spacing: 10

      Text {
        text: "Connect to " + root.pendingSsid
        color: Theme.text
        font { family: "Inter"; pixelSize: 13; weight: 600 }
        Layout.fillWidth: true
        elide: Text.ElideRight
      }

      Rectangle {
        Layout.fillWidth: true
        height: 40
        radius: 10
          color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.15)

        TextField {
          id: pwField
          anchors.fill: parent
          anchors.margins: 4
          color: Theme.text
          echoMode: revealBtn.checked ? TextInput.Normal : TextInput.Password
          placeholderText: "Password"
          placeholderTextColor: Theme.subtext
          background: null
          font { family: "Inter"; pixelSize: 13 }
          focus: root.visible
          Keys.onReturnPressed: submit()
          Keys.onEscapePressed: root.dismiss()
        }
      }

      RowLayout {
        Layout.fillWidth: true
        CheckBox {
          id: revealBtn
          text: "Show password"
          contentItem: Text {
            text: revealBtn.text; color: Theme.text; opacity: 0.7
            leftPadding: revealBtn.indicator.width + 6; font { family: "Inter"; pixelSize: 11 }
          }
        }
      }

      Text {
        visible: root.connectError.length > 0
        text: root.connectError
        color: Theme.error
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        font { family: "Inter"; pixelSize: 11 }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Layout.topMargin: 4

        Rectangle {
          Layout.fillWidth: true
          height: 36
          radius: 10
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.15)
          Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.text; font { family: "Inter"; pixelSize: 12; weight: 600 } }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.dismiss(); pwField.text = ""; } }
        }

        Rectangle {
          Layout.fillWidth: true
          height: 36
          radius: 10
          color: Theme.primary
          Text { anchors.centerIn: parent; text: root.connecting ? "Connecting…" : "Connect"; color: Theme.primaryFg; font { family: "Inter"; pixelSize: 12; weight: 700 } }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: !root.connecting
            onClicked: submit()
          }
        }
      }
    }
  }

  function submit() {
    root.connectRequested(root.pendingSsid, pwField.text);
    pwField.text = "";
  }
}
