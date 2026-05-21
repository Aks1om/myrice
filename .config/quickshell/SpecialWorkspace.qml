import QtQuick
import Quickshell.Hyprland
import "theme"

Item {
  id: root
  property var screen
  readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
  readonly property string specialName: "special:magic"
  readonly property bool visible_: monitor?.activeSpecialWorkspace?.name === specialName
  readonly property bool occupied: Hyprland.toplevels.values.some(t => t.workspace?.name === specialName)
  readonly property string state: visible_ ? "active" : occupied ? "occupied" : "empty"

  implicitWidth: txt.implicitWidth
  implicitHeight: 14

  Text {
    id: txt
    anchors.centerIn: parent
    text: "◆"
    font.family: "Inter"
    font.pixelSize: 11
    color: root.state === "active" ? "#c4b5fd"
         : root.state === "occupied" ? "#8b5cf6"
         : Qt.rgba(1, 1, 1, 0.22)
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Hyprland.dispatch("togglespecialworkspace magic")
  }
}
