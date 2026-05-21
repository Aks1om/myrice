import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

Scope {
  id: root
  property bool isOpen: false
  property int selected: 0

  readonly property var items: [
    { label: "Lock",     hint: "Заблокировать экран",    action: "lock",     icon: "lock"             },
    { label: "Logout",   hint: "Выйти из сессии",         action: "logout",   icon: "sign-out"         },
    { label: "Reboot",   hint: "Перезагрузить компьютер", action: "reboot",   icon: "arrow-clockwise"  },
    { label: "Shutdown", hint: "Выключить компьютер",     action: "shutdown", icon: "power"            }
  ]

  IpcHandler {
    target: "power"
    function open()   { root.selected = 0; root.isOpen = true }
    function close()  { root.isOpen = false }
    function toggle() { if (!root.isOpen) root.selected = 0; root.isOpen = !root.isOpen }
  }

  Process { id: cmdProc }

  function runCmd(parts) {
    root.isOpen = false
    cmdProc.command = parts
    cmdProc.running = true
  }

  function activate(idx) {
    const it = items[idx]
    switch (it.action) {
      case "lock":     runCmd(["hyprlock"]); break
      case "logout":   runCmd(["hyprctl", "dispatch", "exit"]); break
      case "reboot":   runCmd(["systemctl", "reboot"]); break
      case "shutdown": runCmd(["systemctl", "poweroff"]); break
    }
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
        Keys.onReturnPressed: root.activate(root.selected)
        Keys.onUpPressed:    root.selected = Math.max(0, root.selected - 1)
        Keys.onDownPressed:  root.selected = Math.min(root.items.length - 1, root.selected + 1)
        Keys.onTabPressed:   root.selected = (root.selected + 1) % root.items.length
      }

      MouseArea {
        anchors.fill: parent
        onClicked: root.isOpen = false
      }

      Rectangle {
        anchors.centerIn: parent
        width: 380
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
          spacing: 8

          // Header
          ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.topMargin: 2
            Layout.bottomMargin: 2
            spacing: 1
            Text {
              text: "Power"
              color: "#ffffff"
              font.family: "Inter"
              font.pixelSize: 14
              font.weight: Font.DemiBold
            }
            Text {
              text: "Выбери действие"
              color: "#7a7a7a"
              font.family: "Inter"
              font.pixelSize: 10
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: "#1f1f1f"
          }

          Repeater {
            model: root.items
            delegate: Item {
              required property var modelData
              required property int index
              property bool isFocused: hoverArea.containsMouse || index === root.selected
              Layout.fillWidth: true
              height: 44

              Rectangle {
                anchors.fill: parent
                color: parent.isFocused ? "#1c1c1c" : "transparent"
                radius: 8
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 14
                spacing: 12

                Icon {
                  name: modelData.icon
                  color: parent.parent.isFocused ? "#ffffff" : "#cfcfcf"
                  size: 16
                }
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 0
                  Text {
                    Layout.fillWidth: true
                    text: modelData.label
                    color: parent.parent.parent.isFocused ? "#ffffff" : "#cfcfcf"
                    font.family: "Manrope"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                  }
                  Text {
                    Layout.fillWidth: true
                    visible: modelData.hint.length > 0
                    text: modelData.hint
                    color: "#7a7a7a"
                    font.family: "Manrope"
                    font.pixelSize: 10
                    elide: Text.ElideRight
                  }
                }
              }

              MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selected = parent.index
                onClicked: root.activate(parent.index)
              }
            }
          }
        }
      }
    }
  }
}
