import "./Overview/common"
import "./Overview/services"
import "./Overview/modules/overview"
import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
  id: root

  Component.onCompleted: GlobalStates.overviewOpen = true

  Connections {
    target: GlobalStates
    function onOverviewOpenChanged() {
      if (!GlobalStates.overviewOpen) Qt.quit()
    }
  }

  Overview {
    id: overview
  }
}
