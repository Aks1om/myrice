import "theme"
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
  property var monitors: []

  readonly property var items: [
    { label: "Только этот экран",  hint: "Использовать только встроенный",          mode: "internal-only", icon: "laptop"            },
    { label: "Дублировать",         hint: "Повторить изображение на внешнем",        mode: "mirror",         icon: "copy"              },
    { label: "Расширить",           hint: "Использовать как отдельные рабочие столы", mode: "extend",         icon: "frame-corners"     },
    { label: "Только внешний",      hint: "Отключить встроенный экран",              mode: "external-only",  icon: "monitor"           }
  ]

  IpcHandler {
    target: "display"
    function open()   { root.selected = 0; loadProc.running = true; root.isOpen = true }
    function close()  { root.isOpen = false }
    function toggle() { if (!root.isOpen) { root.selected = 0; loadProc.running = true } root.isOpen = !root.isOpen }
  }

  Process {
    id: loadProc
    command: ["hyprctl", "-j", "monitors", "all"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.monitors = JSON.parse(text) ?? [] } catch (_) { root.monitors = [] }
      }
    }
  }

  Process { id: applyProc }

  function internalName() {
    const m = root.monitors.find(x => /^(eDP|LVDS|DSI)/i.test(x.name ?? ""))
    return m?.name || ""
  }
  function externalNames() {
    return root.monitors.filter(x => !/^(eDP|LVDS|DSI)/i.test(x.name ?? "")).map(x => x.name)
  }

  function apply(mode) {
    root.isOpen = false
    const internal = internalName()
    const externals = externalNames()
    const cmds = []

    switch (mode) {
      case "internal-only":
        if (internal) cmds.push(`hyprctl keyword monitor ${internal},preferred,auto,1`)
        for (const e of externals) cmds.push(`hyprctl keyword monitor ${e},disable`)
        break
      case "external-only":
        if (internal) cmds.push(`hyprctl keyword monitor ${internal},disable`)
        for (const e of externals) cmds.push(`hyprctl keyword monitor ${e},preferred,auto,1`)
        break
      case "mirror":
        if (internal) cmds.push(`hyprctl keyword monitor ${internal},preferred,auto,1`)
        for (const e of externals) {
          cmds.push(`hyprctl keyword monitor ${e},preferred,auto,1,mirror,${internal}`)
        }
        break
      case "extend":
        if (internal) cmds.push(`hyprctl keyword monitor ${internal},preferred,auto,1`)
        for (const e of externals) {
          cmds.push(`hyprctl keyword monitor ${e},preferred,auto-right,1`)
        }
        break
    }

    if (cmds.length === 0) return
    applyProc.command = ["bash", "-c", cmds.join(" && ")]
    applyProc.running = true
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
        Keys.onReturnPressed: root.apply(root.items[root.selected].mode)
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
        color: Colors.bgBase
        radius: Colors.radiusXl
        border.width: 1
        border.color: Colors.border

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
          id: col
          anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
          }
          spacing: Colors.spacingMd

          ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.topMargin: 2
            Layout.bottomMargin: 2
            spacing: 1
            Text {
              text: "Display"
              color: Colors.textPrim
              font.family: Colors.fontPrimary
              font.pixelSize: Colors.fontSizeLarge
              font.weight: Font.DemiBold
            }
            Text {
              text: root.monitors.length <= 1
                    ? "Один монитор подключён"
                    : "Куда выводить изображение"
                    color: Colors.textHint
              font.family: Colors.fontPrimary
              font.pixelSize: Colors.fontSizeTiny
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Colors.overlay
          }

          Repeater {
            model: root.items
            delegate: Item {
              required property var modelData
              required property int index
              property bool isFocused: hoverArea.containsMouse || index === root.selected
              property bool isDisabled: root.monitors.length <= 1
                                        && modelData.mode !== "internal-only"
              Layout.fillWidth: true
              height: 44
              opacity: isDisabled ? 0.35 : 1.0

              Rectangle {
                anchors.fill: parent
                color: parent.isFocused && !parent.isDisabled ? Colors.surface : "transparent"
                radius: Colors.radiusMd
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 14
                spacing: 12

                Icon {
                  name: modelData.icon
                  color: parent.parent.isFocused ? Colors.textPrim : Colors.textSecondary
                  size: 16
                }
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 0
                  Text {
                    Layout.fillWidth: true
                    text: modelData.label
                    color: parent.parent.parent.isFocused ? Colors.textPrim : Colors.textSecondary
                    font.family: Colors.fontSecondary
                    font.pixelSize: Colors.fontSizeBase
                    elide: Text.ElideRight
                  }
                  Text {
                    Layout.fillWidth: true
                    visible: modelData.hint.length > 0
                    text: modelData.hint
              color: Colors.textHint
                    font.family: Colors.fontSecondary
                    font.pixelSize: Colors.fontSizeTiny
                    elide: Text.ElideRight
                  }
                }
              }

              MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: !parent.isDisabled
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selected = parent.index
                onClicked: root.apply(modelData.mode)
              }
            }
          }
        }
      }
    }
  }
}
