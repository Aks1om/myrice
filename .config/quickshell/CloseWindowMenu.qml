import "theme"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "ui" as Ui

Scope {
  id: root
  property bool isOpen: false
  property string activeTitle: ""
  property string activeAddress: ""
  property int selected: 1  // 0 = Cancel, 1 = Close (default)

  IpcHandler {
    target: "closewindow"
    function open(addr: string, title: string): void {
      root.activeAddress = addr || ""
      root.activeTitle = title || ""
      root.selected = 1
      if (root.activeAddress) root.isOpen = true
    }
    function close(): void { root.isOpen = false }
  }

  Process { id: killProc }

  function confirmKill() {
    root.isOpen = false
    if (!root.activeAddress) return
    killProc.command = ["hyprctl", "dispatch", "closewindow", "address:" + root.activeAddress]
    killProc.running = true
  }

  Loader {
    id: loader
    active: root.isOpen
    asynchronous: true

    sourceComponent: Ui.ModalOverlay {
      open: root.isOpen
      onDismissed: root.isOpen = false

      Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.isOpen = false
        Keys.onReturnPressed: {
          if (root.selected === 0) root.isOpen = false
          else root.confirmKill()
        }
        Keys.onLeftPressed: root.selected = 0
        Keys.onRightPressed: root.selected = 1
        Keys.onTabPressed: root.selected = (root.selected + 1) % 2
      }

      Ui.PanelSurface {
        anchors.centerIn: parent
        width: Metrics.panelWidth
        implicitHeight: col.implicitHeight + Metrics.menuPadding * 2

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
          id: col
          anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Metrics.menuPadding
          }
          spacing: Colors.spacingLg

          Text {
            Layout.fillWidth: true
            text: "Close window?"
            color: Colors.textPrim
            font.family: Colors.fontSecondary
            font.pixelSize: Colors.fontSizeBase
            font.weight: Font.DemiBold
          }

          Text {
            Layout.fillWidth: true
            text: root.activeTitle || "(untitled)"
            color: Colors.textSecondary
            font.family: Colors.fontSecondary
            font.pixelSize: Colors.fontSizeSmall
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
          }

          RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: Colors.spacingMd

            // Cancel
            Rectangle {
              property bool isFocused: root.selected === 0 || cancelArea.containsMouse
              Layout.fillWidth: true
              Layout.preferredHeight: 36
              radius: Colors.radiusMd
              color: isFocused ? Colors.surface : "transparent"
              border.width: 1
              border.color: Colors.border

              Text {
                anchors.centerIn: parent
                text: "Cancel"
                color: Colors.textSecondary
                font.family: Colors.fontSecondary
                font.pixelSize: Colors.fontSizeBase
              }
              MouseArea {
                id: cancelArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selected = 0
                onClicked: root.isOpen = false
              }
            }

            // Close (primary)
            Rectangle {
              property bool isFocused: root.selected === 1 || closeArea.containsMouse
              Layout.fillWidth: true
              Layout.preferredHeight: 36
              radius: Colors.radiusMd
              color: isFocused ? Colors.textSecondary : Colors.textPrim
              border.width: 0

              Text {
                anchors.centerIn: parent
                text: "Close"
                color: Colors.bgBase
                font.family: Colors.fontSecondary
                font.pixelSize: Colors.fontSizeBase
              }
              MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selected = 1
                onClicked: root.confirmKill()
              }
            }
          }
        }
      }
    }
  }
}
