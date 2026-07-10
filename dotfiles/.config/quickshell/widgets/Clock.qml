import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick

Item {
  width: mainWidget.width
  height: mainWidget.height

  signal toggleControlCenter()
  signal notifDismissed(var notifRef)
  signal notifBannerDismissed(var notifRef)

  property var latestNotification: null
  property var latestNotificationData: null
  property var storedNotifications: []
  property alias showPowerSection: mainWidget.showPowerSection
  property alias showAskpass: mainWidget.showAskpass
  property alias showAppLauncher: mainWidget.showAppLauncher
  property alias showPomodoro: mainWidget.showPomodoro
  property alias showSys: mainWidget.showSys
  property alias showTray: mainWidget.showTray
  property alias modeSvc: mainWidget.modeSvc
  property alias askpassSvc: mainWidget.askpassSvc
  property alias showControlCenter: mainWidget.showControlCenter
  property alias anyOverlayActive: mainWidget.anyOverlayActive

  function showModeIndicator() { mainWidget.showModeIndicator(); }

  ClockWidget {
    id: mainWidget
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter

    latestNotification: parent.latestNotification
    latestNotificationData: parent.latestNotificationData
    storedNotifications: parent.storedNotifications

    onToggleControlCenter: parent.toggleControlCenter()
    onNotifDismissed: (notifRef) => parent.notifDismissed(notifRef)
    onNotifBannerDismissed: (notifRef) => parent.notifBannerDismissed(notifRef)
  }
}
