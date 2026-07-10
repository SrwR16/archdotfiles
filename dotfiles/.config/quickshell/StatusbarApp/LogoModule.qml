import Quickshell
import QtQuick

// Dotfiles logo -> toggles the Sidebar app via IPC.
BarButton {
    iconSrc: Quickshell.env("HOME") + "/.config/dotfiles/assets/dotfiles.svg"
    colorize: false
    onClicked: {
        Quickshell.execDetached(["qs", "ipc", "call", "sidebar", "toggle"])
    }
}
