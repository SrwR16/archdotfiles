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

      var actionList = notification.actions.map(function (a) {
        return {
          identifier: a ? a.identifier : "",
          text: a ? a.text : "",
          invoke: function () { if (a) a.invoke(); }
        };
      });

      var data = {
        appName: notification.appName,
        appIcon: notification.appIcon,
        summary: notification.summary,
        body: notification.body,
        urgency: notification.urgency,
        id: id,
        actions: actionList,
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

  function dismissNotif(itemOrId) {
    // Accept either a stored notification object or a raw id.
    var id = (typeof itemOrId === "object" && itemOrId !== null)
      ? itemOrId.id
      : itemOrId;
    if (id === undefined || id === null) return;

    // Dismiss the live notification on the server (release its retain lock).
    if (typeof itemOrId === "object" && itemOrId) {
      try {
        if (itemOrId.ref && typeof itemOrId.ref.dismiss === "function")
          itemOrId.ref.dismiss();
        else if (typeof itemOrId.dismiss === "function")
          itemOrId.dismiss();
      } catch (e) {}
    }

    notifService._releaseLockById(id);

    var arr = storedNotifications.slice();
    for (var i = 0; i < arr.length; i++) {
      if (arr[i].id === id) { arr.splice(i, 1); break; }
    }
    storedNotifications = arr;

    if (latestNotificationData && latestNotificationData.id === id)
      latestNotificationData = null;
    if (latestNotification && latestNotification.id === id)
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
