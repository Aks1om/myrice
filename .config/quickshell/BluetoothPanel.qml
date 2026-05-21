import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Bluetooth

Loader {
  id: loader
  property var anchorItem
  property bool open: false

  active: open
  asynchronous: true

  // Prefer dongle MAC if present (only adapter that works with AirPods 4 ANC)
  readonly property string dongleAddress: "8C:68:8B:C0:69:C1"
  // Adapter MAC to scope commands to. Updated by the popup before any btCmd/powerOn call.
  property string adapterAddress: ""

  Process { id: btctl }
  Process { id: btPowerOn }

  // Build a bluetoothctl shell script that first selects the desired controller,
  // then runs the requested command(s). Empty adapterAddress falls back to default.
  function _ctlScript(cmd) {
    const sel = adapterAddress ? "select " + adapterAddress + "\\n" : ""
    return "printf '" + sel + cmd + "\\n' | bluetoothctl"
  }
  function btCmd(args) {
    btctl.command = ["sh", "-c", _ctlScript(args.join(" "))]
    btctl.running = true
  }
  function powerOn() {
    btPowerOn.command = ["sh", "-c",
      "sudo -n /usr/bin/rfkill unblock bluetooth && " + _ctlScript("power on")]
    btPowerOn.running = true
  }

  sourceComponent: PopupWindow {
    id: pop
    visible: true
    color: "transparent"
    implicitWidth: 320
    implicitHeight: container.implicitHeight + 20

    anchor {
      window: loader.anchorItem.QsWindow.window
      item: loader.anchorItem
      edges: Edges.Bottom
      gravity: Edges.Bottom
      margins.top: 8
    }

    HyprlandFocusGrab {
      active: loader.open
      windows: [pop]
      onCleared: loader.open = false
    }

    property int _adaptersTick: 0
    property int _macTick: 0
    property var pathToMac: ({})

    Connections {
      target: Bluetooth.adapters
      function onValuesChanged() { pop._adaptersTick++; popMacFetcher.running = true }
      function onObjectInsertedPost() { pop._adaptersTick++; popMacFetcher.running = true }
      function onObjectRemovedPost() { pop._adaptersTick++ }
    }

    Process {
      id: popMacFetcher
      command: ["busctl", "--system", "call", "org.bluez", "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects"]
      stdout: StdioCollector {
        onStreamFinished: {
          const txt = this.text || ""
          const blocks = txt.split(/(?="\/org\/bluez\/)/)
          const map = {}
          const adapterRe = /^"?\/org\/bluez\/(hci\d+)"?\s+\d+/
          const macRe = /"Address"\s+s\s+"((?:[0-9A-F]{2}:){5}[0-9A-F]{2})"/
          for (const b of blocks) {
            const p = b.match(adapterRe); if (!p) continue
            const a = b.match(macRe); if (!a) continue
            map["/org/bluez/" + p[1]] = a[1].toUpperCase()
          }
          pop.pathToMac = map
          pop._macTick++
        }
      }
    }
    Component.onCompleted: popMacFetcher.running = true

    readonly property var adapter: {
      pop._adaptersTick; pop._macTick  // deps
      const am = Bluetooth.adapters
      if (am) {
        const list = am.values
        for (let i = 0; i < list.length; i++) {
          if (list[i] && pop.pathToMac[list[i].dbusPath] === loader.dongleAddress) {
            return list[i]
          }
        }
      }
      return Bluetooth.defaultAdapter
    }
    readonly property bool enabled: adapter ? adapter.enabled : false
    readonly property bool discovering: adapter ? adapter.discovering : false
    readonly property bool isDongle: adapter && pop.pathToMac[adapter.dbusPath] === loader.dongleAddress
    readonly property string adapterMac: adapter ? (pop.pathToMac[adapter.dbusPath] || "") : ""

    onAdapterMacChanged: loader.adapterAddress = adapterMac

    readonly property var devices: {
      if (!adapter || !adapter.devices) return []
      const arr = adapter.devices.values.slice()
      arr.sort((a, b) => {
        if (a.connected !== b.connected) return a.connected ? -1 : 1
        if (a.paired !== b.paired) return a.paired ? -1 : 1
        return (a.name || a.address || "").localeCompare(b.name || b.address || "")
      })
      return arr
    }

    Rectangle {
      id: container
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 10
      color: "#000000"
      radius: 14
      border.width: 1
      border.color: "#3a3a3a"
      implicitHeight: col.implicitHeight + 20

      MouseArea { anchors.fill: parent; onClicked: {} }

      ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        spacing: 8

        // Header: enable toggle + scan + open blueman
        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Icon {
            name: pop.enabled
                  ? (pop.adapter?.devices?.values?.some(d => d.connected) ? "bluetooth-connected" : "bluetooth")
                  : "bluetooth-slash"
            color: pop.enabled ? "#ffffff" : Qt.rgba(1, 1, 1, 0.5)
            size: 14
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
              Layout.fillWidth: true
              text: pop.enabled ? "Bluetooth"
                                : "Bluetooth (off)"
              color: "#ffffff"
              font.family: "Manrope"
              font.pixelSize: 12
              font.weight: Font.DemiBold
            }
            Text {
              visible: pop.adapter
              Layout.fillWidth: true
              text: pop.isDongle ? "USB dongle" : "Built-in"
              color: pop.isDongle ? "#7dd3fc" : "#fbbf24"
              font.family: "Manrope"
              font.pixelSize: 9
            }
          }

          // Scan button
          Rectangle {
            Layout.preferredWidth: 26
            Layout.preferredHeight: 22
            radius: 6
            color: scanArea.containsMouse ? "#1c1c1c" : "transparent"
            border.color: "#3a3a3a"
            border.width: 1
            enabled: pop.enabled

            Icon {
              anchors.centerIn: parent
              name: "arrows-clockwise"
              variant: pop.discovering ? "fill" : "regular"
              color: pop.enabled ? "#ffffff" : "#5a5a5a"
              size: 11
            }

            MouseArea {
              id: scanArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: pop.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: loader.btCmd(["scan", pop.discovering ? "off" : "on"])
            }
          }

          // Enable toggle
          Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 22
            radius: 11
            color: pop.enabled ? "#ffffff" : "#333333"

            Rectangle {
              width: 14; height: 14; radius: 7
              y: 4
              x: pop.enabled ? parent.width - width - 4 : 4
              color: pop.enabled ? "#0f0f0f" : "#909090"
              Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (pop.enabled) {
                  loader.btCmd(["power", "off"])
                } else {
                  loader.powerOn()
                }
              }
            }
          }
        }

        // separator
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#252525" }

        // Devices list
        ListView {
          id: devList
          Layout.fillWidth: true
          Layout.preferredHeight: Math.min(contentHeight, 280)
          visible: pop.enabled
          clip: true
          spacing: 2
          interactive: true
          model: pop.devices

          delegate: Item {
            id: delegateRoot
            required property var modelData
            width: devList.width - 18
            height: 44

            readonly property var dev: modelData
            readonly property bool isConnected: dev?.connected ?? false
            readonly property bool isConnecting: dev?.state === BluetoothDeviceState.Connecting
            readonly property bool isDisconnecting: dev?.state === BluetoothDeviceState.Disconnecting

            Rectangle {
              anchors.fill: parent
              color: rowArea.containsMouse ? "#1c1c1c" : "transparent"
              radius: 6
            }

            // Row click area — double click toggles connect; single click does nothing
            MouseArea {
              id: rowArea
              anchors.fill: parent
              anchors.rightMargin: 36   // leave room for the forget button
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onDoubleClicked: {
                if (!delegateRoot.dev?.address) return
                loader.btCmd([delegateRoot.isConnected ? "disconnect" : "connect", delegateRoot.dev.address])
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 4
              spacing: 8

              Icon {
                name: delegateRoot.isConnected ? "bluetooth-connected" : "bluetooth"
                color: delegateRoot.isConnected ? "#ffffff" : "#cfcfcf"
                size: 14
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                  Layout.fillWidth: true
                  text: delegateRoot.dev?.name || delegateRoot.dev?.address || ""
                  color: "#ffffff"
                  font.family: "Manrope"
                  font.pixelSize: 12
                  font.weight: delegateRoot.isConnected ? Font.DemiBold : Font.Normal
                  elide: Text.ElideRight
                }
                Text {
                  visible: text.length > 0
                  text: {
                    if (delegateRoot.isConnecting) return "Подключение…"
                    if (delegateRoot.isDisconnecting) return "Отключение…"
                    if (delegateRoot.isConnected) return "Подключено · двойной клик отключить"
                    if (delegateRoot.dev?.paired) return "Сопряжено · двойной клик подключить"
                    return "Двойной клик подключить"
                  }
                  color: "#909090"
                  font.family: "Manrope"
                  font.pixelSize: 10
                }
              }

              // battery (if available)
              Text {
                visible: delegateRoot.dev?.batteryAvailable ?? false
                text: Math.round((delegateRoot.dev?.battery ?? 0) * 100) + "%"
                color: "#909090"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
              }

              // Forget (remove from bluez) button — visible on hover or always for paired devices
              Rectangle {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: 6
                color: forgetArea.containsMouse ? "#3a1c1c" : "transparent"
                border.width: forgetArea.containsMouse ? 1 : 0
                border.color: "#5a2c2c"
                opacity: rowArea.containsMouse || forgetArea.containsMouse ? 1 : 0.35
                Behavior on opacity { NumberAnimation { duration: 120 } }

                Text {
                  anchors.centerIn: parent
                  text: "✕"
                  color: forgetArea.containsMouse ? "#ff8080" : "#808080"
                  font.pixelSize: 12
                  font.bold: true
                }

                MouseArea {
                  id: forgetArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (!delegateRoot.dev?.address) return
                    loader.btCmd(["remove", delegateRoot.dev.address])
                  }
                }
              }
            }
          }
        }

        // Empty state
        Text {
          visible: pop.enabled && pop.devices.length === 0
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          text: pop.discovering ? "Поиск устройств…" : "Устройств нет"
          color: "#909090"
          font.family: "Manrope"
          font.pixelSize: 11
        }

        // Footer: LibrePods + blueman-manager
        RowLayout {
          Layout.fillWidth: true
          spacing: 6

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            radius: 8
            color: airpodsArea.containsMouse ? "#1c1c1c" : "transparent"
            border.width: 1
            border.color: "#3a3a3a"

            Text {
              anchors.centerIn: parent
              text: "AirPods"
              color: "#cfcfcf"
              font.family: "Manrope"
              font.pixelSize: 11
            }

            MouseArea {
              id: airpodsArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                loader.open = false
                // If librepods is already running, focus it; otherwise launch.
                // hyprctl focuses any window whose class matches; pkill -0 just tests existence.
                Quickshell.execDetached(["sh", "-c",
                  "pgrep -x librepods >/dev/null && hyprctl dispatch focuswindow class:librepods || setsid librepods >/dev/null 2>&1 < /dev/null &"])
              }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            radius: 8
            color: managerArea.containsMouse ? "#1c1c1c" : "transparent"
            border.width: 1
            border.color: "#3a3a3a"

            Text {
              anchors.centerIn: parent
              text: "Blueman"
              color: "#cfcfcf"
              font.family: "Manrope"
              font.pixelSize: 11
            }

            MouseArea {
              id: managerArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: { loader.open = false; Quickshell.execDetached(["blueman-manager"]) }
            }
          }
        }
      }
    }
  }
}
