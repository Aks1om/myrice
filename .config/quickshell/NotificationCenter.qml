import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland
import "theme"

Scope {
  id: root

  property bool isOpen: false
  property bool mounted: false
  property int transitionId: 0
  readonly property int count: server.trackedNotifications?.values?.length ?? 0

  Timer {
    id: closeTimer
    interval: Metrics.notificationPanelAnimationMs
    repeat: false

    onTriggered: {
      if (!root.isOpen)
        root.mounted = false
    }
  }

  function toggle() {
    if (root.isOpen) {
      root.isOpen = false
      root.transitionId++
      surface.x = surface.width
      closeTimer.restart()
    } else {
      closeTimer.stop()
      root.mounted = true
      root.isOpen = true
      root.transitionId++
      const transition = root.transitionId
      surface.x = surface.width
      Qt.callLater(() => {
        if (root.isOpen && root.transitionId === transition)
          surface.x = 0
      })
    }
  }

  function clear() {
    const items = server.trackedNotifications?.values ?? []
    items.forEach(notification => notification.dismiss())
  }

  NotificationServer {
    id: server
    bodySupported: true
    bodyMarkupSupported: false
    bodyImagesSupported: true
    imageSupported: true
    actionsSupported: true

    onNotification: notification => {
      notification.tracked = true
    }
  }

  IpcHandler {
    target: "notifications"

    function toggle() {
      root.toggle()
    }

    function clear() {
      root.clear()
    }
  }

  PanelWindow {
    id: panelWindow
    screen: Hyprland.focusedMonitor?.screen ?? Quickshell.screens[0]
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    anchors {
      top: true
      right: true
      bottom: true
    }
    margins.top: Metrics.popupInset
    margins.bottom: Metrics.popupInset
    margins.right: 0
    implicitWidth: Metrics.notificationPanelWidth
    visible: root.mounted

    Item {
      id: panel
      anchors.fill: parent
      clip: true

      Rectangle {
        id: surface
        width: parent.width
        height: parent.height
        color: Colors.bgBase
        radius: Colors.radiusXl

        Behavior on x {
          NumberAnimation {
            duration: Metrics.notificationPanelAnimationMs
            easing.type: Easing.OutCubic

            onStopped: {
              if (!root.isOpen)
                root.mounted = false
            }
          }
        }

        // Cover only the screen-facing corners; the free left edge keeps its radius.
        Rectangle {
          anchors {
            top: parent.top
            right: parent.right
            bottom: parent.bottom
          }
          width: Colors.radiusXl
          color: Colors.bgBase
        }

        ColumnLayout {
          anchors {
            fill: parent
            margins: Metrics.panelPadding
          }
          spacing: Colors.spacingMd

          RowLayout {
            Layout.fillWidth: true

            Text {
              Layout.fillWidth: true
              text: "Notifications"
              color: Colors.textPrim
              font.family: Colors.fontPrimary
              font.pixelSize: Colors.fontSizeLarge
              font.weight: Font.Medium
            }

            Text {
              text: root.count
              color: Colors.textSecondary
              font.family: Colors.fontPrimary
              font.pixelSize: Colors.fontSizeBase
            }

            Text {
              text: "Clear"
              color: Colors.textSecondary
              font.family: Colors.fontPrimary
              font.pixelSize: Colors.fontSizeSmall

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.clear()
              }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            height: Metrics.dividerHeight
            color: Colors.border
          }

          ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Colors.spacingMd
            clip: true
            model: server.trackedNotifications

            delegate: NotificationCard {
              required property var modelData
              width: ListView.view.width
              notification: modelData
            }

            Text {
              anchors.centerIn: parent
              visible: root.count === 0
              text: "No notifications"
              color: Colors.textMuted
              font.family: Colors.fontPrimary
              font.pixelSize: Colors.fontSizeBase
            }
          }
        }
      }
    }
  }
}
