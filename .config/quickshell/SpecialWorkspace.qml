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
    font.family: Colors.fontPrimary
    font.pixelSize: Colors.fontSizeSmall
    color: root.state === "active" ? Colors.accent
         : root.state === "occupied" ? Colors.accentDim
         : Qt.rgba(1, 1, 1, 0.22)
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Hyprland.dispatch("togglespecialworkspace magic")
  }
}
