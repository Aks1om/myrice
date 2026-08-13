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

    sourceComponent: Ui.ModalOverlay {
      open: root.isOpen
      onDismissed: root.isOpen = false

      Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.isOpen = false
        Keys.onReturnPressed: root.apply(root.items[root.selected].mode)
        Keys.onUpPressed:    root.selected = Math.max(0, root.selected - 1)
        Keys.onDownPressed:  root.selected = Math.min(root.items.length - 1, root.selected + 1)
        Keys.onTabPressed:   root.selected = (root.selected + 1) % root.items.length
      }

      Ui.PanelSurface {
        anchors.centerIn: parent
        width: Metrics.menuWidth
        implicitHeight: col.implicitHeight + Metrics.menuPadding * 2

        MouseArea { anchors.fill: parent; onClicked: {} }

        Ui.PanelColumn {
          id: col
          anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Metrics.menuPadding
          }

          Ui.SectionTitle {
            title: "Display"
            subtitle: root.monitors.length <= 1
                      ? "Один монитор подключён"
                      : "Куда выводить изображение"
            Layout.leftMargin: 4
            Layout.topMargin: 2
            Layout.bottomMargin: 2
          }

          Ui.Divider {}

          Repeater {
            model: root.items
            delegate: Ui.MenuRow {
              required property var modelData
              required property int index
              property bool isDisabled: root.monitors.length <= 1
                                        && modelData.mode !== "internal-only"
              opacity: isDisabled ? 0.35 : 1.0
              enabled: !isDisabled
              label: modelData.label
              hint: modelData.hint
              iconName: modelData.icon
              selected: index === root.selected
              onHovered: root.selected = index
              onActivated: root.apply(modelData.mode)
            }
          }
        }
      }
    }
  }
}
