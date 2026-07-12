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

  function _warm(t) {
    var x = Math.max(0, Math.min(1, (t - 1000) / 7000));
    return Qt.rgba(1, (120 + 135 * x) / 255, (40 + 215 * x) / 255, 1);
  }
  readonly property color _preview: _warm(nlMode === "auto" ? nlNightTemp : nlTemp)

  ColumnLayout {
    width: parent.width
    spacing: 12

    // ============ ENABLE CONTROL (title is in the panel header) ============
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 50
      radius: 14
      color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.85)
      border.color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.85)
      border.width: 1
      opacity: 0
      SequentialAnimation on opacity {
  PauseAnimation { duration: 0 }
  NumberAnimation { from: 0; to: 1; duration: Motion.durM; easing.type: Motion.easeStandard; objectName: "entrance" }
}

      RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Rectangle {
          width: 26; height: 26; radius: 8
          color: nlEnabled ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18) : Theme.surfaceLight
          Text {
            anchors.centerIn: parent
            text: "󰖔"
            color: nlEnabled ? Theme.primary : Theme.subtext
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
          }
        }
        Text {
          text: nlEnabled ? "Enabled" : "Disabled"
          color: nlEnabled ? Theme.primary : Theme.subtext
          font.family: "Inter"
          font.pixelSize: 12
          font.weight: 600
        }
        Item { Layout.fillWidth: true }
        Rectangle {
          width: 44; height: 25; radius: 12
          color: nlEnabled ? Theme.primary : Theme.border
          Behavior on color { ColorAnimation { duration: Motion.durXS } }

          Rectangle {
            width: 19; height: 19; radius: 9
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

    // ============ LIVE PREVIEW ============
    Rectangle {
      visible: nlEnabled
      Layout.fillWidth: true
      Layout.preferredHeight: 104
      radius: 18
      clip: true
      color: _preview
      opacity: 0
      Behavior on color { ColorAnimation { duration: Motion.durL } }
      SequentialAnimation on opacity {
  PauseAnimation { duration: 60 }
  NumberAnimation { from: 0; to: 0.95; duration: Motion.durM; easing.type: Motion.easeStandard; objectName: "entrance" }
}

      Canvas {
        id: nlSpec
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 14
        property real frac: Math.max(0, Math.min(1, ((nlMode === "auto" ? nlNightTemp : nlTemp) - 1000) / 7000))
        onFracChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          var w = width, h = height
          for (var x = 0; x < w; x++) {
            var xx = x / w
            ctx.fillStyle = Qt.rgba(1, (120 + 135 * xx) / 255, (40 + 215 * xx) / 255, 1)
            ctx.fillRect(x, 0, 1, h)
          }
          var mx = frac * w
          ctx.fillStyle = "#ffffff"
          ctx.fillRect(mx - 1.5, 0, 3, h)
        }
      }

      RowLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 12

        Rectangle {
          width: 46; height: 46; radius: 14
          color: "#000000"
          opacity: 0.12
          Text {
            anchors.centerIn: parent
            text: "󰖔"
            color: "#000000"
            opacity: 0.5
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 22
          }
        }
        ColumnLayout {
          spacing: 2
          Layout.fillWidth: true

          Text {
            text: "Warmth preview"
            color: "#1a1205"
            opacity: 0.75
            font.family: "Inter"
            font.pixelSize: 10
            font.weight: 600
          }
          Text {
            text: nlMode === "auto"
              ? "Following sunset — " + nlNightTemp + "K at night"
              : (nlTemp + "K")
            color: "#1a1205"
            font.family: "Inter"
            font.pixelSize: 14
            font.weight: 700
          }
        }
      }
    }

    // ============ MODE ============
    Rectangle {
      visible: nlEnabled
      Layout.fillWidth: true
      Layout.preferredHeight: 44
      radius: 14
      color: Theme.surfaceLight
      opacity: 0
      SequentialAnimation on opacity {
  PauseAnimation { duration: 120 }
  NumberAnimation { from: 0; to: 1; duration: Motion.durM; easing.type: Motion.easeStandard; objectName: "entrance" }
}

      Rectangle {
        id: nlSeg
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

    // ============ MANUAL ============
    ColumnLayout {
      visible: nlEnabled && nlMode === "manual"
      Layout.fillWidth: true
      spacing: 6

      Text { text: "Temperature"; color: Theme.muted; font.family: "Inter"; font.pixelSize: 11; font.weight: 700; leftPadding: 4 }
      IconSlider {
        iconText: "󰂚"
        value: (nlTemp - 1000) / 7000
        onMoved: val => setNightLightTemp(1000 + Math.round(val * 7000))
      }
      Text { text: nlTemp + "K"; color: Theme.text; font.family: "Inter"; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
    }

    // ============ AUTO ============
    ColumnLayout {
      visible: nlEnabled && nlMode === "auto"
      Layout.fillWidth: true
      spacing: 6

      Text { text: "Day Temperature"; color: Theme.muted; font.family: "Inter"; font.pixelSize: 11; font.weight: 700; leftPadding: 4 }
      IconSlider {
        iconText: "󰖕"
        value: (nlDayTemp - 1000) / 7000
        onMoved: val => setNightLightAutoTemp(1000 + Math.round(val * 7000), nlNightTemp)
      }
      Text { text: nlDayTemp + "K"; color: Theme.text; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }

      Item { height: 4 }
      Text { text: "Night Temperature"; color: Theme.muted; font.family: "Inter"; font.pixelSize: 11; font.weight: 700; leftPadding: 4 }
      IconSlider {
        iconText: "󰖔"
        value: (nlNightTemp - 1000) / 7000
        onMoved: val => setNightLightAutoTemp(nlDayTemp, 1000 + Math.round(val * 7000))
      }
      Text { text: nlNightTemp + "K"; color: Theme.text; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
      Text {
        text: "Requires geoclue2 for sunset / sunrise scheduling"
        color: Theme.subtext
        font.family: "Inter"
        font.pixelSize: 9
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
        Layout.topMargin: 4
      }
    }

    // ============ SAVE ============
    Rectangle {
      visible: nlEnabled
      Layout.fillWidth: true
      Layout.preferredHeight: 44
      radius: 14
      color: saveBtn.containsMouse ? Theme.surfaceHover : Theme.surfaceLight
      Behavior on color { ColorAnimation { duration: Motion.durXS } }

      Text {
        anchors.centerIn: parent
        text: "Save"
        color: Theme.primary
        font.family: "Inter"
        font.pixelSize: 12
        font.weight: 700
      }
      MouseArea {
        id: saveBtn
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { applyNightLight(); saveNightLight(); }
      }
    }

    Item { Layout.preferredHeight: 4 }
  }
}
