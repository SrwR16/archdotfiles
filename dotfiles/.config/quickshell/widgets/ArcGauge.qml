import QtQuick

Canvas {
  id: root
  property real value: 0
  property color color: Theme.primary
  property color trackColor: Theme.outline
  property int thickness: 7
  property real fromDeg: 135
  property real sweepDeg: 270
  property bool rounded: true
  property string centerText: ""
  property color centerColor: Theme.text
  property int centerSize: 12
  property bool centerBold: true

  onValueChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onColorChanged: requestPaint()
  onTrackColorChanged: requestPaint()
  onCenterTextChanged: requestPaint()
  Component.onCompleted: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    var cx = width / 2
    var cy = height / 2
    var r = Math.min(width, height) / 2 - thickness / 1.5
    var a0 = fromDeg * Math.PI / 180
    var a1 = (fromDeg + sweepDeg) * Math.PI / 180

    ctx.lineWidth = thickness
    ctx.lineCap = rounded ? "round" : "butt"
    ctx.strokeStyle = trackColor
    ctx.beginPath()
    ctx.arc(cx, cy, r, a0, a1)
    ctx.stroke()

    var v = Math.max(0, Math.min(1, value))
    if (v > 0.001) {
      ctx.strokeStyle = color
      ctx.beginPath()
      ctx.arc(cx, cy, r, a0, a0 + sweepDeg * v)
      ctx.stroke()
    }

    if (centerText.length > 0) {
      ctx.fillStyle = centerColor
      ctx.font = (centerBold ? "bold " : "") + centerSize + "px Inter, sans-serif"
      ctx.textAlign = "center"
      ctx.textBaseline = "middle"
      ctx.fillText(centerText, cx, cy)
    }
  }
}
