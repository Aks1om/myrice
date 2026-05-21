import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

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

    sourceComponent: PanelWindow {
      screen: Hyprland.focusedMonitor?.screen ?? Quickshell.screens[0]
      visible: true
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      anchors {
        top: true
        left: true
        right: true
        bottom: true
      }

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

      MouseArea {
        anchors.fill: parent
        onClicked: root.isOpen = false
      }

      Rectangle {
        anchors.centerIn: parent
        width: 320
        implicitHeight: col.implicitHeight + 24
        color: "#000000"
        radius: 14
        border.width: 1
        border.color: "#3a3a3a"

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
          id: col
          anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
          }
          spacing: 10

          Text {
            Layout.fillWidth: true
            text: "Close window?"
            color: "#ffffff"
            font.family: "Manrope"
            font.pixelSize: 12
            font.weight: Font.DemiBold
          }

          Text {
            Layout.fillWidth: true
            text: root.activeTitle || "(untitled)"
            color: "#cfcfcf"
            font.family: "Manrope"
            font.pixelSize: 11
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
          }

          RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8

            // Cancel
            Rectangle {
              property bool isFocused: root.selected === 0 || cancelArea.containsMouse
              Layout.fillWidth: true
              Layout.preferredHeight: 36
              radius: 8
              color: isFocused ? "#1c1c1c" : "transparent"
              border.width: 1
              border.color: "#3a3a3a"

              Text {
                anchors.centerIn: parent
                text: "Cancel"
                color: "#cfcfcf"
                font.family: "Manrope"
                font.pixelSize: 12
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
              radius: 8
              color: isFocused ? "#e6e6e6" : "#ffffff"
              border.width: 0

              Text {
                anchors.centerIn: parent
                text: "Close"
                color: "#000000"
                font.family: "Manrope"
                font.pixelSize: 12
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
