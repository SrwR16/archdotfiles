import QtQuick
import Quickshell

QtObject {
  id: manager

  readonly property int priorityCritical: 0
  readonly property int priorityInteractive: 1
  readonly property int priorityTimeSensitive: 2
  readonly property int priorityPassive: 3

  property var _queue: []
  property var activeActivity: null
  property int pendingCount: 0

  signal activityDismissed(var activity)

  property Timer _dismissTimer: Timer {
    interval: 1000
    running: false
    repeat: false
    property string currentId: ""
    onTriggered: {
      if (currentId) manager.dismiss(currentId)
    }
  }

  function push(type, data, priority, duration, sticky) {
    var id = type + "_" + Date.now() + "_" + Math.floor(Math.random() * 100000)
    _queue.push({
      id: id,
      type: type,
      data: data,
      priority: priority !== undefined ? priority : priorityPassive,
      duration: duration || 2000,
      dismissAt: (sticky || !duration || duration <= 0) ? 0 : Date.now() + duration,
      timestamp: Date.now(),
      sticky: sticky || false
    })
    _sort()
    _process()
    return id
  }

  function dismiss(id) {
    var removed = []
    _queue = _queue.filter(function(a) {
      if (a.id === id) { removed.push(a); return false; }
      return true
    })
    _process()
    for (var i = 0; i < removed.length; i++)
      activityDismissed(removed[i])
  }

  function dismissByType(type) {
    var removed = []
    _queue = _queue.filter(function(a) {
      if (a.type === type) { removed.push(a); return false; }
      return true
    })
    _process()
    for (var i = 0; i < removed.length; i++)
      activityDismissed(removed[i])
  }

  function dismissAll() {
    var removed = _queue.slice()
    _queue = []
    _process()
    for (var i = 0; i < removed.length; i++)
      activityDismissed(removed[i])
  }

  function pauseAutoDismiss() {
    if (_dismissTimer.running) _dismissTimer.stop()
  }

  function resumeAutoDismiss() {
    if (activeActivity && !activeActivity.sticky && activeActivity.dismissAt > 0) {
      var remaining = Math.max(50, activeActivity.dismissAt - Date.now())
      _dismissTimer.interval = remaining
      _dismissTimer.currentId = activeActivity.id
      _dismissTimer.restart()
    }
  }

  function _sort() {
    _queue.sort(function(a, b) {
      if (a.priority !== b.priority) return a.priority - b.priority
      return a.timestamp - b.timestamp
    })
  }

  function _process() {
    var now = Date.now()
    var expired = []
    _queue = _queue.filter(function(a) {
      if (a.dismissAt !== 0 && now >= a.dismissAt) { expired.push(a); return false; }
      return true
    })
    for (var i = 0; i < expired.length; i++)
      activityDismissed(expired[i])
    activeActivity = _queue.length > 0 ? _queue[0] : null
    pendingCount = Math.max(0, _queue.length - 1)

    if (activeActivity && !activeActivity.sticky && activeActivity.dismissAt > 0) {
      var remaining = Math.max(50, activeActivity.dismissAt - Date.now())
      _dismissTimer.interval = remaining
      _dismissTimer.currentId = activeActivity.id
      _dismissTimer.restart()
    } else {
      _dismissTimer.stop()
    }
  }
}
