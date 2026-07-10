import QtQuick
import QtQuick.Layouts
import "../theme"

Item {
    id: vpnRoot
    implicitWidth: 320
    implicitHeight: 140
    property QtObject vpnSvc

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            
            Rectangle {
                width: 32; height: 32; radius: 16
                color: Theme.surfaceLight
                Text {
                    anchors.centerIn: parent
                    text: "󰒄"
                    color: Theme.primary
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: vpnSvc ? vpnSvc.tunnelType : "VPN"
                    color: Theme.text
                    font { family: "Inter"; pixelSize: 14; weight: 700 }
                }
                Text {
                    text: "Connected Securely"
                    color: Theme.success
                    font { family: "Inter"; pixelSize: 12 }
                }
            }

            Rectangle {
                width: 80; height: 30; radius: 8
                color: Theme.surfaceVariant
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (vpnSvc) vpnSvc.disconnect()
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: "Disconnect"
                    color: Theme.error
                    font { family: "Inter"; pixelSize: 11; weight: 700 }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.surfaceVariant
        }

        RowLayout {
            Layout.fillWidth: true
            
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: "Public IP"
                    color: Theme.subtext
                    font { family: "Inter"; pixelSize: 11 }
                }
                Text {
                    text: vpnSvc ? vpnSvc.publicIp : "..."
                    color: Theme.text
                    font { family: "JetBrains Mono"; pixelSize: 13; weight: 600 }
                }
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 2
                Text {
                    text: "Latency"
                    color: Theme.subtext
                    font { family: "Inter"; pixelSize: 11 }
                    horizontalAlignment: Text.AlignRight
                    Layout.fillWidth: true
                }
                Text {
                    text: vpnSvc ? vpnSvc.latency : "..."
                    color: Theme.text
                    font { family: "JetBrains Mono"; pixelSize: 13; weight: 600 }
                    horizontalAlignment: Text.AlignRight
                    Layout.fillWidth: true
                }
            }
        }
    }
}
