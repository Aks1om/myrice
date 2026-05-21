import QtQuick
import Quickshell

ShellRoot {
  Variants {
    model: Quickshell.screens
    PanelWindow {
      property var modelData
      screen: modelData

      anchors {
        top: true
        left: true
        right: true
      }
      implicitHeight: 36
      color: "transparent"

      Bar {
        anchors.fill: parent
        screen: modelData
      }
    }
  }

  ScreenshotMenu {}
  PowerMenu {}
  ScaleMenu {}
  CloseWindowMenu {}
  AppLauncher {}
  DisplayMenu {}
  KeybindsMenu {}
}
