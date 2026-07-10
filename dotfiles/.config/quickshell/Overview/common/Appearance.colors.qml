
import QtQuick
import "../../../theme"

QtObject {
    id: m3

    property color m3primary: Theme.primary
    property color m3onPrimary: Theme.onPrimary

    property color m3primaryContainer: Theme.surfaceContainer
    property color m3onPrimaryContainer: Theme.text

    property color m3secondary: Theme.secondary
    property color m3onSecondary: Theme.backgroundFg

    property color m3secondaryContainer: Theme.surfaceContainer
    property color m3onSecondaryContainer: Theme.text

    property color m3background: Theme.background
    property color m3onBackground: Theme.backgroundFg

    property color m3surface: Theme.surface

    property color m3surfaceContainerLow: Theme.surfaceDim
    property color m3surfaceContainer: Theme.surfaceContainer
    property color m3surfaceContainerHigh: Theme.surfaceBright
    property color m3surfaceContainerHighest: Theme.surfaceVariant

    property color m3onSurface: Theme.surfaceFg

    property color m3surfaceVariant: Theme.surfaceVariant
    property color m3onSurfaceVariant: Theme.surfaceVariantFg

    property color m3inverseSurface: Theme.surfaceBright
    property color m3inverseOnSurface: Theme.background

    property color m3outline: Theme.outline
    property color m3outlineVariant: Theme.outlineVariant

    property color m3shadow: "#000000"
}
