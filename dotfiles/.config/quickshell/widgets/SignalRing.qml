import QtQuick
import QtQuick.Shapes
import "../theme"

// A radial arc gauge used throughout the Wi‑Fi page in place of the generic
// four-bar signal icon: one motif for the hero (large), list rows (small),
// and the enable toggle / lock state (icon-only, value driven by state
// rather than signal strength). Center content (glyph or text) is supplied
// by the parent via the default `content` item so the same ring can host a
// percentage, a lock glyph, or a spinner-friendly cutout.
Item {
    id: ring

    property real value: 0
    // 0..100
    property real trackWidth: 4
    property color ringColor: Theme.primary
    property color trackColor: Theme.border
    property bool animate: true
    // When true, ignores `value` and spins a fixed short arc — an
    // in-progress state that stays visually the same ring motif instead of
    // swapping in an unrelated spinner glyph.
    property bool indeterminate: false
    default property alias content: contentSlot.data

    implicitWidth: 40
    implicitHeight: 40

    RotationAnimation on rotation {
        running: ring.indeterminate
        loops: Animation.Infinite
        from: 0
        to: 360
        duration: 900
    }

    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: ring.trackColor
            strokeWidth: ring.trackWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: (ring.width - ring.trackWidth) / 2
                radiusY: (ring.height - ring.trackWidth) / 2
                startAngle: 0
                sweepAngle: 359.9
            }

        }

        ShapePath {
            strokeColor: ring.ringColor
            strokeWidth: ring.trackWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: (ring.width - ring.trackWidth) / 2
                radiusY: (ring.height - ring.trackWidth) / 2
                startAngle: -90
                sweepAngle: ring.indeterminate ? 70 : 360 * Math.max(0, Math.min(1, ring.value / 100))

                Behavior on sweepAngle {
                    enabled: ring.animate && !ring.indeterminate
                    NumberAnimation {
                        duration: Motion.durM
                        easing.type: Motion.easeStandard
                    }

                }

            }

        }

    }

    Item {
        id: contentSlot

        anchors.fill: parent
        anchors.margins: ring.trackWidth + 2
    }

}
