import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Notifications

Rectangle {
  id: historyRoot

  property var storedNotifications: []
  property var expandedGroups: ({})

  signal dismissNotif(var notifRef)
  signal clearAll()

  radius: 18
  color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
  border.color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.55)
  border.width: 1
  clip: true

  function buildGroups(arr) {
    if (!arr || arr.length === 0) return [];
    var groups = [];
    var current = null;
    for (var i = 0; i < arr.length; i++) {
      var item = arr[i];
      var app = item.appName || "Unknown";
      if (!current || current.appName !== app) {
        current = { appName: app, appIcon: item.appIcon, items: [] };
        groups.push(current);
      }
      current.items.push(item);
    }
    return groups;
  }

  function toggleGroup(appName) {
    var key = appName || "Unknown";
    var copy = {};
    for (var k in historyRoot.expandedGroups)
      copy[k] = historyRoot.expandedGroups[k];
    if (copy[key])
      copy[key] = false;
    else
      copy[key] = true;
    historyRoot.expandedGroups = copy;
  }

  function isGroupExpanded(appName) {
    return historyRoot.expandedGroups[appName || "Unknown"] === true;
  }

  function relTime(ts) {
    if (!ts) return "";
    var diff = Date.now() - ts;
    if (diff < 60000) return "now";
    if (diff < 3600000) return Math.floor(diff / 60000) + "m";
    if (diff < 86400000) return Math.floor(diff / 3600000) + "h";
    var days = Math.floor(diff / 86400000);
    return days === 1 ? "1d" : days + "d";
  }

  readonly property var groupedNotifs: buildGroups(storedNotifications)
  readonly property int totalCount: (storedNotifications?.length ?? 0)

  function safeActions(actions) {
    if (!actions) return [];
    var result = [];
    for (var i = 0; i < actions.length; i++) {
      var a = actions[i];
      if (a && a.text != null)
        result.push({ text: a.text, invoke: a.invoke });
    }
    return result;
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 14
    spacing: 12

    // ---- Header ----
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Rectangle {
        width: 26; height: 26; radius: 13
        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
        Text {
          anchors.centerIn: parent
          text: "󰔞"
          color: Theme.primary
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
        }
      }

      Text {
        text: "Notifications"
        color: Theme.text
        font { family: "Inter"; pixelSize: 13; weight: 700 }
      }

      Rectangle {
        visible: totalCount > 0
        implicitWidth: countBadge.implicitWidth + 10
        implicitHeight: 18
        radius: 9
        color: Qt.rgba(Theme.surfaceBright.r, Theme.surfaceBright.g, Theme.surfaceBright.b, 0.7)
        Text {
          id: countBadge
          anchors.centerIn: parent
          text: totalCount
          color: Theme.subtext
          font { family: "Inter"; pixelSize: 10; weight: 700 }
        }
      }

      Item { Layout.fillWidth: true }

      Text {
        text: "Clear all"
        color: totalCount > 0 ? Theme.primary : Theme.muted
        font { family: "Inter"; pixelSize: 11; weight: 600 }
        visible: totalCount > 0
        MouseArea {
          anchors.fill: parent
          anchors.margins: -6
          cursorShape: Qt.PointingHandCursor
          onClicked: historyRoot.clearAll()
        }
      }
    }

    // ---- Empty state ----
    Item {
      visible: totalCount === 0
      Layout.fillWidth: true
      Layout.fillHeight: true
      ColumnLayout {
        anchors.centerIn: parent
        spacing: 8
        Text {
          text: "󰔞"
          color: Theme.muted
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 34 }
          Layout.alignment: Qt.AlignHCenter
        }
        Text {
          text: "You're all caught up"
          color: Theme.subtext
          font { family: "Inter"; pixelSize: 12; weight: 600 }
          Layout.alignment: Qt.AlignHCenter
        }
      }
    }

    // ---- List ----
    ScrollView {
      id: notifScroll
      Layout.fillWidth: true
      Layout.fillHeight: true
      visible: totalCount > 0
      clip: true
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
      ScrollBar.vertical.policy: ScrollBar.AsNeeded
      contentWidth: width

      Column {
        spacing: 10
        width: notifScroll.availableWidth

        Repeater {
          model: historyRoot.groupedNotifs

          delegate: Rectangle {
            id: groupCard
            required property var modelData
            width: parent.width
            implicitHeight: headerRow.implicitHeight + 20
              + (bodyCol.visible ? bodyCol.implicitHeight + 8 : 0)
            radius: 16
            color: Qt.rgba(Theme.surfaceLight.r, Theme.surfaceLight.g, Theme.surfaceLight.b, 0.4)
            border.color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
            border.width: 1

            property string groupAppName: modelData.appName
            property bool groupExpanded: historyRoot.isGroupExpanded(groupAppName)

            ColumnLayout {
              anchors.fill: parent
              spacing: 0

              // Group header (always visible)
              RowLayout {
                id: headerRow
                Layout.fillWidth: true
                Layout.margins: 10
                spacing: 10

                NotifIcon {
                  iconSize: 22
                  appIcon: modelData.appIcon || ""
                  appName: modelData.appName || ""
                }

                Text {
                  text: modelData.appName || "Unknown"
                  color: Theme.text
                  font { family: "Inter"; pixelSize: 12; weight: 700 }
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                Rectangle {
                  implicitWidth: grpCount.implicitWidth + 10
                  implicitHeight: 18
                  radius: 9
                  color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.85)
                  visible: modelData.items.length > 1
                  Text {
                    id: grpCount
                    anchors.centerIn: parent
                    text: modelData.items.length
                    color: Theme.muted
                    font { family: "Inter"; pixelSize: 10; weight: 600 }
                  }
                }

                Text {
                  text: groupCard.groupExpanded ? "󰒍" : "󰒌"
                  color: Theme.subtext
                  font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                  MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: historyRoot.toggleGroup(groupCard.groupAppName)
                  }
                }
              }

              // Grouped items (revealed on expand); single-item groups show directly
              Column {
                id: bodyCol
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                Layout.bottomMargin: 8
                spacing: 6
                visible: groupCard.groupExpanded || modelData.items.length === 1

                Repeater {
                  model: modelData.items

                  delegate: Rectangle {
                    id: notifCard
                    required property var modelData
                    width: parent.width
                    implicitHeight: row.implicitHeight + 16
                    radius: 12
                    color: modelData.urgency === NotificationUrgency.Critical
                      ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
                      : "transparent"
                    readonly property var _actions: historyRoot.safeActions(modelData.actions)

                    RowLayout {
                      id: row
                      anchors.fill: parent
                      anchors.margins: 8
                      spacing: 10

                      Rectangle {
                        visible: modelData.urgency === NotificationUrgency.Critical
                        width: 3
                        Layout.fillHeight: true
                        radius: 2
                        color: Theme.error
                        Layout.maximumHeight: parent.height
                      }

                      ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                          Layout.fillWidth: true
                          spacing: 6

                          Text {
                            text: modelData.summary || ""
                            color: modelData.urgency === NotificationUrgency.Critical
                              ? Theme.error : Theme.text
                            font { family: "Inter"; pixelSize: 12; weight: 600 }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                          }

                          Text {
                            text: historyRoot.relTime(modelData.timestamp)
                            color: Theme.muted
                            font { family: "Inter"; pixelSize: 9; weight: 500 }
                            opacity: 0.7
                          }
                        }

                        Text {
                          text: modelData.body || ""
                          visible: text !== ""
                          color: Theme.subtext
                          font { family: "Inter"; pixelSize: 10 }
                          Layout.fillWidth: true
                          Layout.topMargin: 1
                          maximumLineCount: 3
                          wrapMode: Text.WordWrap
                        }

                        Flow {
                          visible: notifCard._actions.length > 0
                          Layout.topMargin: 4
                          spacing: 6

                          Repeater {
                            model: notifCard._actions

                            delegate: Rectangle {
                              required property var modelData
                              implicitWidth: actText.implicitWidth + 14
                              implicitHeight: 22
                              radius: 11
                              color: actHover.containsMouse ? Theme.surfaceHover : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.9)
                              scale: actHover.pressed ? 0.94 : 1.0
                              Behavior on color { ColorAnimation { duration: Motion.durXS } }
                              Behavior on scale { NumberAnimation { duration: Motion.durXS; easing.type: Motion.easeStandard } }

                              Text {
                                id: actText
                                anchors.centerIn: parent
                                text: modelData.text || ""
                                color: Theme.primary
                                font { family: "Inter"; pixelSize: 9; weight: 600 }
                              }

                              MouseArea {
                                id: actHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                  if (modelData.invoke) modelData.invoke();
                                }
                              }
                            }
                          }
                        }
                      }

                      // Close button (reliably wired)
                      Rectangle {
                        Layout.alignment: Qt.AlignTop
                        width: 24; height: 24; radius: 12
                        color: closeHover.containsMouse ? Theme.surfaceHover : "transparent"
                        Behavior on color { ColorAnimation { duration: Motion.durXS } }
                        Text {
                          anchors.centerIn: parent
                          text: "✕"
                          color: closeHover.containsMouse ? Theme.text : Theme.muted
                          font { family: "Inter"; pixelSize: 10 }
                        }
                        MouseArea {
                          id: closeHover
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: historyRoot.dismissNotif(modelData.id)
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
