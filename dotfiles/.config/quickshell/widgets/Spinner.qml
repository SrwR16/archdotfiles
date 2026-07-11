import "../overlay"
import "../widgets"
import "../services"
import "../theme"
import QtQuick

// Lightweight indeterminate spinner. A rotating arc drawn on a Canvas, sized to
// `size`. Pauses its rotation animation when `running` is false (e.g. hidden).
Item {
  id: root
  property int size: 16
  property color color: Theme.primary
  property int lineWidth: 2
  property bool running: true
  property int period: 800     // ms per rotation

  implicitWidth: size
  implicitHeight: size

  Canvas {
    id: cv
    anchors.fill: parent
    onPaint: {
      var ctx = getContext("2d");
      ctx.reset();
      var w = cv.width, h = cv.height;
      var cx = w / 2, cy = h / 2;
      var r = Math.min(w, h) / 2 - root.lineWidth;
      ctx.lineWidth = root.lineWidth;
      ctx.lineCap = "round";
      ctx.strokeStyle = root.color;
      ctx.beginPath();
      ctx.arc(cx, cy, r, 0, Math.PI * 1.4);
      ctx.stroke();
    }
    Behavior on rotation { NumberAnimation { duration: root.period; easing.type: Motion.easeStandard } }
    rotation: root.running ? 360 : 0
    Component.onCompleted: { cv.requestPaint(); }
  }

  onColorChanged: cv.requestPaint()
  onSizeChanged: cv.requestPaint()
}
