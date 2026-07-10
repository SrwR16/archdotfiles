import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth


Rectangle {
    id: statusCapsule
    color: capsuleMouseArea.containsMouse ? Theme.surfaceHover : Theme.surface
    radius: 12
    height: 24
    width: layout.implicitWidth + 24

    Behavior on color { ColorAnimation { duration: 150 } }

    property QtObject statusSvc: null
    property string wifiName: statusSvc ? statusSvc.wifi : "Disconnected"
    property int wifiSignal: statusSvc ? statusSvc.wifiSignal : 0
    property int batteryPercent: statusSvc ? statusSvc.battery : 0
    property bool isCharging: statusSvc ? statusSvc.charging : false
    property string powerState: statusSvc ? statusSvc.powerState : "Disconnected"
    property string networkState: statusSvc ? statusSvc.networkState : "Disconnected"
    property string connectionType: statusSvc ? statusSvc.connType : "disconnected"
    property bool isHovered: capsuleMouseArea.containsMouse
    signal clicked()

    property var btAdapter: Bluetooth.defaultAdapter
    property bool btConnected: {
        if (!btAdapter || !btAdapter.enabled) return false;
        var devs = btAdapter.devices.values;
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].state === BluetoothDeviceState.Connected) return true;
        }
        return false;
    }

    MouseArea {
        id: capsuleMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: statusCapsule.clicked()
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 10

        Text {
            text: statusCapsule.networkState === "Disconnected" ? "󰤭"
                : statusCapsule.connectionType === "wired" ? "󰌚"
                : statusCapsule.wifiSignal > 75 ? "󰤨"
                : statusCapsule.wifiSignal > 50 ? "󰤥"
                : statusCapsule.wifiSignal > 25 ? "󰤢"
                : "󰤟"
            color: statusCapsule.networkState === "Disconnected" ? Theme.subtext : Theme.text
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
        }

        Text {
            visible: statusCapsule.btConnected
            text: "󰂱"
            color: Theme.text
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
        }

        Item {
            width: 32; height: 14
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 25; height: 12
                radius: 4
                color: "transparent"
                border.color: Theme.text
                border.width: 1
                opacity: 0.4
            }

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 2
                anchors.leftMargin: 2
                height: 8
                // Clamp max width to 21 to prevent overflow bugs if system reports > 100% battery
                width: Math.max(0, Math.min(21, 21 * (statusCapsule.batteryPercent / 100)))
                radius: 2
                color: statusCapsule.isCharging ? "#34c759" : (statusCapsule.batteryPercent <= 20 ? Theme.error : Theme.text)
            }

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 26
                anchors.verticalCenter: parent.verticalCenter
                width: 2; height: 4
                radius: 1
                color: Theme.text
                opacity: 0.4
            }

        }

        Text {
            visible: statusCapsule.isCharging
            text: "󱐋"
            color: "#34c759"
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
        }

        Text {
            text: statusCapsule.batteryPercent + "%"
            color: statusCapsule.isCharging ? "#34c759" : (statusCapsule.batteryPercent <= 20 ? Theme.error : Theme.text)
            font { family: "Inter"; pixelSize: 11; weight: 700 }
        }
    }
}
