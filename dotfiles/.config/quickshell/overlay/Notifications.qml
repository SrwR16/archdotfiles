import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications

Rectangle {
  id: root

  property var notificationData: null
  property int pendingCount: 0
  readonly property bool expanded: notificationData !== null
  property bool bannerHovered: false

  readonly property real bannerWidth: 480
  readonly property real bannerRadius: 28

  readonly property real bannerHeight: {
    if (!notificationData) return 0;
    var base = 144;
    if (notificationData.actions && notificationData.actions.length > 0) base += 30;
    return base;
  }

  signal dismissed(var notifRef)

  color: Theme.background
  clip: true
  layer.enabled: true
  layer.samples: 4

  property real dragOffset: 0

  Rectangle {
    visible: root.notificationData && root.notificationData.urgency === NotificationUrgency.Critical
    width: 4
    anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
    radius: 2
    color: Theme.error
  }

  opacity: expanded ? 1.0 : 0.0
  Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }

  RowLayout {
    id: content
    anchors.fill: parent
    anchors { leftMargin: 24; rightMargin: 20; topMargin: 18; bottomMargin: 16 }
    spacing: 14

    NotifIcon {
      iconSize: 42
      appIcon: root.notificationData?.appIcon ?? ""
      appName: root.notificationData?.appName ?? ""
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      spacing: 1

      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          text: root.notificationData?.appName ?? ""
          color: Theme.subtext
          font { family: "Inter"; pixelSize: 10; weight: 600 }
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        Text {
          text: root.notificationData ? relTime(root.notificationData.timestamp) : ""
          color: Theme.muted
          font { family: "Inter"; pixelSize: 9; weight: 500 }
          opacity: 0.7
        }
      }

      Text {
        text: root.notificationData?.summary ?? ""
        color: root.notificationData
          && root.notificationData.urgency === NotificationUrgency.Critical
          ? Theme.error : Theme.text
        font { family: "Inter"; pixelSize: 13; weight: 700 }
        elide: Text.ElideRight
        Layout.fillWidth: true
        Layout.maximumHeight: 18
      }

      Text {
        text: root.notificationData?.body ?? ""
        visible: expanded && text !== ""
        color: Theme.muted
        font { family: "Inter"; pixelSize: 10; weight: 400 }
        elide: Text.ElideRight
        Layout.fillWidth: true
        maximumLineCount: 2
        wrapMode: Text.WordWrap
      }

      Flow {
        visible: expanded && root.notificationData?.actions?.length > 0
        Layout.topMargin: 4
        spacing: 6

        Repeater {
          model: root.notificationData?.actions ?? []

          delegate: Rectangle {
            required property var modelData
            implicitWidth: btnText.implicitWidth + 16
            implicitHeight: 22
            radius: 11
            color: Theme.surfaceLight

            Text {
              id: btnText
              anchors.centerIn: parent
              text: modelData.text || ""
              color: Theme.primary
              font { family: "Inter"; pixelSize: 10; weight: 600 }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (modelData.invoke) modelData.invoke();
                root.dismissed(root.notificationData);
              }
            }
          }
        }
      }
    }

    Text {
      text: "󰅂"
      color: Theme.subtext
      font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
      Layout.alignment: Qt.AlignTop | Qt.AlignRight
      Layout.topMargin: 0

      MouseArea {
        anchors.fill: parent
        anchors.margins: -8
        cursorShape: Qt.PointingHandCursor
        onClicked: root.dismissed(root.notificationData)
      }
    }
  }

  DragHandler {
    id: dragHandler
    target: null
    xAxis { minimum: -bannerWidth; maximum: bannerWidth }
    onActiveChanged: {
      if (!active) {
        if (Math.abs(root.dragOffset) > 80)
          root.dismissed(root.notificationData);
        root.dragOffset = 0;
      }
    }
    onTranslationChanged: (delta) => {
      root.dragOffset = delta.x;
    }
  }

  transform: Translate {
    x: root.dragOffset
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onContainsMouseChanged: root.bannerHovered = containsMouse
    onClicked: {
      if (Math.abs(root.dragOffset) < 10)
        root.dismissed(root.notificationData);
    }
  }

  function relTime(ts) {
    if (!ts) return "";
    var diff = Date.now() - ts;
    if (diff < 60000) return "now";
    if (diff < 3600000) return Math.floor(diff / 60000) + "m";
    if (diff < 86400000) return Math.floor(diff / 3600000) + "h";
    return Math.floor(diff / 86400000) + "d";
  }
}
