import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
  property bool open: false
  property bool dismissOnClick: true
  signal dismissed()
  screen: Hyprland.focusedMonitor?.screen ?? Quickshell.screens[0]
  visible: open
  color: "transparent"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  anchors { top: true; left: true; right: true; bottom: true }
  MouseArea {
    anchors.fill: parent
    enabled: parent.dismissOnClick
    onClicked: parent.dismissed()
  }
}
