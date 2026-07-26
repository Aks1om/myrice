import QtQuick
import Quickshell.Hyprland
import "theme"

Text {
  id: root
  property var screen
  readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
  readonly property var activeWs: monitor?.activeWorkspace
  readonly property var activeClient: Hyprland.toplevels.values.find(c =>
    c.workspace?.id === activeWs?.id && c.activated
  )

  text: activeClient?.title ?? ""
  color: Qt.rgba(1, 1, 1, 0.88)
  font.family: Colors.fontPrimary
  font.pixelSize: Colors.fontSizeMedium
  font.weight: Font.Bold
  elide: Text.ElideRight
  verticalAlignment: Text.AlignVCenter
}
