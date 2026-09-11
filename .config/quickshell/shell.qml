//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark
import QtQuick
import Quickshell
import "theme"

ShellRoot {
  NotificationCenter { id: notificationCenter }

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
      implicitHeight: Metrics.px(36)
      color: "transparent"

      Bar {
        anchors.fill: parent
        screen: modelData
        notificationCenter: notificationCenter
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
