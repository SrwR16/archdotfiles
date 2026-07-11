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
  contentWidth: width
  required property bool nlEnabled
  required property string nlMode
  required property int nlTemp
  required property int nlDayTemp
  required property int nlNightTemp

  signal backRequested()
  signal toggleNightLight()
  signal setNightLightTemp(int temp)
  signal setNightLightAutoTemp(int day, int night)
  signal setNightLightMode(string mode)
  signal applyNightLight()
  signal saveNightLight()

  ColumnLayout {
    width: parent.width
    spacing: 10

    // ============ ENABLE HEADER ============
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 52
      radius: 16
      color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.85)
      border.color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.85)
      border.width: 1

      RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        Text {
          text: "Night Light"
          color: Theme.text
          font.family: "Inter"
          font.pixelSize: 14
          font.weight: 700
        }
        Item { Layout.fillWidth: true }
        Text {
          text: nlEnabled ? "On" : "Off"
          color: nlEnabled ? Theme.primary : Theme.subtext
          font.family: "Inter"
          font.pixelSize: 11
          font.weight: 600
          opacity: 0.8
        }
        Rectangle {
          width: 46; height: 26; radius: 13
          color: nlEnabled ? Theme.primary : Theme.border
          Behavior on color { ColorAnimation { duration: Motion.durXS } }

          Rectangle {
            width: 20; height: 20; radius: 10
            color: Theme.backgroundFg
            anchors.verticalCenter: parent.verticalCenter
            x: nlEnabled ? parent.width - width - 3 : 3
            Behavior on x { NumberAnimation { duration: Motion.durS; easing.type: Motion.easeStandard } }
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleNightLight()
          }
        }
      }
    }

    // ============ MODE SEGMENTED CONTROL ============
    Text {
      text: "Mode"
      color: Theme.muted
      font.family: "Inter"
      font.pixelSize: 11
      font.weight: 700
      leftPadding: 4
    }

    Rectangle {
      id: seg
      Layout.fillWidth: true
      height: 40
      radius: 14
      color: Theme.surfaceLight

      Rectangle {
        id: segIndicator
        width: parent.width / 2
        height: parent.height
        radius: 14
        color: Theme.surfaceHover
        x: nlMode === "auto" ? parent.width / 2 : 0
        Behavior on x { NumberAnimation { duration: Motion.durS; easing.type: Motion.easeStandard } }
      }

      RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: "transparent"
          Text {
            anchors.centerIn: parent
            text: "Manual"
            color: nlMode === "manual" ? Theme.text : Theme.subtext
            font.family: "Inter"
            font.pixelSize: 12
            font.weight: nlMode === "manual" ? 600 : 400
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: setNightLightMode("manual")
          }
        }
        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: "transparent"
          Text {
            anchors.centerIn: parent
            text: "Auto"
            color: nlMode === "auto" ? Theme.text : Theme.subtext
            font.family: "Inter"
            font.pixelSize: 12
            font.weight: nlMode === "auto" ? 600 : 400
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: setNightLightMode("auto")
          }
        }
      }
    }

    // Temperature slider for manual mode
    ColumnLayout {
      visible: nlMode === "manual"
      Layout.fillWidth: true
      spacing: 6

      Text {
        text: "Temperature"
        color: Theme.muted
        font.family: "Inter"
        font.pixelSize: 11
        font.weight: 700
        leftPadding: 4
      }

      Item { height: 4 }

      IconSlider {
        iconText: "󰂚"
        value: (nlTemp - 1000) / 7000
        onMoved: val => setNightLightTemp(1000 + Math.round(val * 7000))
      }

      Text {
        text: nlTemp + "K"
        color: Theme.text
        font.family: "Inter"
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
      }
    }

    // Temperature sliders for auto mode
    ColumnLayout {
      visible: nlMode === "auto"
      Layout.fillWidth: true
      spacing: 6

      Text {
        text: "Day Temperature"
        color: Theme.muted
        font.family: "Inter"
        font.pixelSize: 11
        font.weight: 700
        leftPadding: 4
      }

      IconSlider {
        iconText: "󰖕"
        value: (nlDayTemp - 1000) / 7000
        onMoved: val => setNightLightAutoTemp(1000 + Math.round(val * 7000), nlNightTemp)
      }

      Text {
        text: nlDayTemp + "K"
        color: Theme.text
        font.family: "Inter"
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
      }

      Item { height: 4 }

      Text {
        text: "Night Temperature"
        color: Theme.muted
        font.family: "Inter"
        font.pixelSize: 11
        font.weight: 700
        leftPadding: 4
      }

      IconSlider {
        iconText: "󰖔"
        value: (nlNightTemp - 1000) / 7000
        onMoved: val => setNightLightAutoTemp(nlDayTemp, 1000 + Math.round(val * 7000))
      }

      Text {
        text: nlNightTemp + "K"
        color: Theme.text
        font.family: "Inter"
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
      }

      Text {
        text: "Requires geoclue2 service for sunset/sunrise"
        color: Theme.subtext
        font.family: "Inter"
        font.pixelSize: 9
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
        Layout.topMargin: 4
      }
    }

    Item { Layout.preferredHeight: 4 }
  }
}
