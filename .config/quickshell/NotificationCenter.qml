import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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
  property bool doNotDisturb: false
  property var toastNotifications: []
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
      closeTimer.restart()
    } else {
      closeTimer.stop()
      root.isOpen = true
      root.mounted = true
    }
  }

  function setDoNotDisturb(enabled) {
    root.doNotDisturb = enabled
    if (enabled)
      root.toastNotifications = []
  }

  function toggleDoNotDisturb() {
    root.setDoNotDisturb(!root.doNotDisturb)
  }

  function clear() {
    // Dismissing mutates the live ObjectModel, so iterate over a snapshot.
    const items = [...(server.trackedNotifications?.values ?? [])]
    items.forEach(notification => notification.dismiss())
  }

  function addToast(notification) {
    // Clients can close notifications before ListView finishes incubating a card.
    // Remove them before Quickshell destroys the underlying QObject.
    notification.closed.connect(() => root.removeToast(notification))
    root.toastNotifications = [notification, ...root.toastNotifications.filter(item => item !== notification)].slice(0, 3)
  }

  function removeToast(notification) {
    root.toastNotifications = root.toastNotifications.filter(item => item !== notification)
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
      if (!root.doNotDisturb)
        root.addToast(notification)
    }
  }

  PanelWindow {
    id: toastWindow
    screen: Hyprland.focusedMonitor?.screen ?? Quickshell.screens[0]
    color: "transparent"
    visible: root.toastNotifications.length > 0
    WlrLayershell.layer: WlrLayer.Top
    anchors {
      top: true
      right: true
    }
    margins.top: 46
    margins.right: Metrics.popupInset
    implicitWidth: 380
    implicitHeight: toasts.height

    ListView {
      id: toasts
      width: parent.width
      height: contentHeight
      interactive: false
      spacing: Metrics.popupInset
      model: root.toastNotifications

      delegate: NotificationCard {
        required property var modelData
        width: toasts.width
        notification: modelData

        Timer {
          interval: modelData && modelData.expireTimeout > 0 ? modelData.expireTimeout * 1000 : 5000
          running: true
          repeat: false
          onTriggered: root.removeToast(modelData)
        }

        onDismissed: root.removeToast(modelData)
      }
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

    function toggleDoNotDisturb() {
      root.toggleDoNotDisturb()
    }

    function status(): string {
      return JSON.stringify({ open: root.isOpen, mounted: root.mounted,
        doNotDisturb: root.doNotDisturb, count: root.count,
        toastCount: root.toastNotifications.length, surfaceX: surface.x })
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
    margins.top: Metrics.px(46)
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
        x: root.isOpen ? 0 : width
        width: parent.width
        height: parent.height
        color: Colors.bgBase
        radius: Colors.radiusXl

        Behavior on x {
          enabled: root.mounted
          NumberAnimation {
            duration: Metrics.notificationPanelAnimationMs
            easing.type: Easing.OutCubic

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

            Item {
              Layout.preferredWidth: Metrics.px(28)
              Layout.preferredHeight: Metrics.px(28)

              Icon {
                anchors.centerIn: parent
                name: "x"
                color: Colors.textSecondary
                size: Metrics.iconSize
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggle()
              }
            }
          }

          RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
              Layout.fillWidth: true
              spacing: Colors.spacingXs

              Text {
                text: "Не беспокоить"
                color: Colors.textPrim
                font.family: Colors.fontPrimary
                font.pixelSize: Colors.fontSizeMedium
              }

              Text {
                text: root.doNotDisturb ? "Только история, без всплывающих окон" : "Всплывающие уведомления включены"
                color: Colors.textSecondary
                font.family: Colors.fontPrimary
                font.pixelSize: Colors.fontSizeSmall
              }
            }

            Switch {
              id: dndSwitch
              checked: root.doNotDisturb
              onToggled: root.setDoNotDisturb(checked)
              Accessible.name: "Не беспокоить"
              implicitWidth: Metrics.px(48)
              implicitHeight: Metrics.px(32)

              indicator: Rectangle {
                anchors.centerIn: parent
                width: Metrics.px(40)
                height: Metrics.px(22)
                radius: height / 2
                color: dndSwitch.checked ? Colors.accent : Colors.border
                border.width: dndSwitch.visualFocus ? 2 : 0
                border.color: Colors.textPrim

                Rectangle {
                  x: dndSwitch.checked ? parent.width - width - Metrics.px(3) : Metrics.px(3)
                  anchors.verticalCenter: parent.verticalCenter
                  width: Metrics.px(16)
                  height: width
                  radius: width / 2
                  color: dndSwitch.checked ? Colors.bgBase : Colors.textPrim

                  Behavior on x {
                    NumberAnimation { duration: 120 }
                  }
                }
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
