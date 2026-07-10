import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Item {
  id: notifService

  property bool doNotDisturb: false

  property var notificationQueue: []
  property var latestNotification: null
  property var latestNotificationData: null
  property var storedNotifications: []
  property var _locks: ({})

  signal notificationReceived(var data, var notification)

  function _releaseLock(lock) {
    if (!lock) return;
    lock.locked = false;
    lock.destroy();
  }

  function _releaseLockById(id) {
    if (id === undefined || id === null) return;
    var lock = notifService._locks[id];
    if (lock) {
      notifService._releaseLock(lock);
      delete notifService._locks[id];
    }
  }

  NotificationServer {
    actionsSupported: true

    onNotification: (notification) => {
      var id = notification.id;

      var data = {
        appName: notification.appName,
        appIcon: notification.appIcon,
        summary: notification.summary,
        body: notification.body,
        urgency: notification.urgency,
        id: id,
        actions: notification.actions,
        hasInlineReply: notification.hasInlineReply,
        inlineReplyPlaceholder: notification.inlineReplyPlaceholder,
        timestamp: Date.now()
      };

      var lock = null;
      try {
        lock = Qt.createQmlObject(
          'import Quickshell; RetainableLock { }',
          notifService, "notifLock"
        );
        lock.object = notification;
        lock.locked = true;
      } catch (e) {}

      notifService._locks[id] = lock;

      if (!notifService.doNotDisturb) {
        notifService.latestNotification = notification;
        notifService.latestNotificationData = data;
        notifService.notificationReceived(data, notification);
      }

      var arr = notifService.storedNotifications.slice();
      arr.push(data);
      if (arr.length > 50) {
        var removed = arr.splice(0, arr.length - 50);
        for (var ri = 0; ri < removed.length; ri++) {
          notifService._releaseLockById(removed[ri].id);
        }
      }
      notifService.storedNotifications = arr;
    }
  }

  function dismissNotif(item) {
    if (!item) return;

    if (item.ref)
      item.ref.dismiss();
    else if (item.dismiss)
      item.dismiss();

    var itemId = item.id;
    if (itemId === undefined) return;

    notifService._releaseLockById(itemId);

    var arr = storedNotifications.slice();
    var idx = -1;
    for (var i = 0; i < arr.length; i++) {
      if (arr[i].id === itemId) { idx = i; break; }
    }
    if (idx >= 0) {
      arr.splice(idx, 1);
    }
    storedNotifications = arr;

    if (latestNotificationData && latestNotificationData.id === itemId)
      latestNotificationData = null;
    if (latestNotification && latestNotification.id === itemId)
      latestNotification = null;
  }

  function dismissBanner(item) {
    // Only clears the active banner, keeps notification in history
    var itemId = item && item.id;
    if (itemId === undefined) return;

    if (latestNotificationData && latestNotificationData.id === itemId)
      latestNotificationData = null;
    if (latestNotification && latestNotification.id === itemId)
      latestNotification = null;

    // Release the lock so the notification can be freed by the server
    notifService._releaseLockById(itemId);
  }

  function clearAll() {
    for (var key in notifService._locks) {
      notifService._releaseLockById(key);
    }
    storedNotifications = [];
    latestNotificationData = null;
    latestNotification = null;
  }
}
