import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Bluetooth
import "theme"

Loader {
  id: loader
  property var anchorItem
  property bool open: false

  active: open
  asynchronous: true

  readonly property string dongleAddress: "8C:68:8B:C0:69:C1"
  readonly property string builtinAddress: "28:D0:43:9A:48:F8"
  property string adapterAddress: ""
  property string adapterHci: ""
  property bool adapterIsDongle: false

  Process { id: btctl }
  Process { id: btPowerOn }

  function _ctlScript(cmd) {
    const sel = adapterAddress ? "select " + adapterAddress + "\\n" : ""
    return "printf '" + sel + cmd + "\\n' | bluetoothctl"
  }
  function btCmd(args) {
    btctl.command = ["sh", "-c", _ctlScript(args.join(" "))]
    btctl.running = true
  }

  function powerOff() {
    let script = _ctlScript("power off")
    if (adapterIsDongle) {
      script += " && printf 'select " + builtinAddress + "\\npower off\\n' | bluetoothctl"
    }
    btctl.command = ["sh", "-c", script]
    btctl.running = true
  }

  function powerOn() {
    const hciIdx = adapterHci || ""
    let rfkill
    if (hciIdx) {
      rfkill = "sudo -n /usr/bin/rfkill unblock " +
        "$(grep -rl '" + hciIdx + "' /sys/class/rfkill/*/name 2>/dev/null | grep -oP '(?<=rfkill)\\d+' | head -1)"
    } else {
      rfkill = "sudo -n /usr/bin/rfkill unblock bluetooth"
    }
    let script = rfkill + " && " + _ctlScript("power on")
    if (adapterIsDongle) {
      script += " && printf 'select " + builtinAddress + "\\npower off\\n' | bluetoothctl"
    }
    btPowerOn.command = ["sh", "-c", script]
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
      margins.bottom: -10
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
      pop._adaptersTick; pop._macTick
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
    readonly property string adapterHci: {
      if (!adapter || !adapter.dbusPath) return ""
      const m = adapter.dbusPath.match(/\/(hci\d+)$/)
      return m ? m[1] : ""
    }

    onAdapterMacChanged: loader.adapterAddress = adapterMac
    onAdapterHciChanged: loader.adapterHci = adapterHci
    onIsDongleChanged: loader.adapterIsDongle = isDongle

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
      anchors.margins: Colors.marginLg
      color: Colors.bgBase
      radius: Colors.radiusXl
      border.width: 1
      border.color: Colors.border
      implicitHeight: col.implicitHeight + 20

      MouseArea { anchors.fill: parent; onClicked: {} }

      ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Colors.marginLg
        spacing: Colors.spacingMd

        RowLayout {
          Layout.fillWidth: true
          spacing: Colors.spacingMd

          Icon {
            name: pop.enabled
                  ? (pop.adapter?.devices?.values?.some(d => d.connected) ? "bluetooth-connected" : "bluetooth")
                  : "bluetooth-slash"
            color: pop.enabled ? Colors.textPrim : Qt.rgba(1, 1, 1, 0.5)
            size: 9
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
              Layout.fillWidth: true
              text: pop.enabled ? "Bluetooth"
                                : "Bluetooth (off)"
              color: Colors.textPrim
              font.family: Colors.fontSecondary
              font.pixelSize: Colors.fontSizeBase
              font.weight: Font.DemiBold
            }
            Text {
              visible: pop.adapter
              Layout.fillWidth: true
              text: pop.isDongle ? "USB dongle" : "Built-in"
              color: pop.isDongle ? "#7dd3fc" : "#fbbf24"
              font.family: Colors.fontSecondary
              font.pixelSize: 9
            }
          }

          Rectangle {
            Layout.preferredWidth: 26
            Layout.preferredHeight: 22
            radius: Colors.radiusSm
            color: scanArea.containsMouse ? Colors.surface : "transparent"
            border.color: Colors.border
            border.width: 1
            enabled: pop.enabled

            Icon {
              anchors.centerIn: parent
              name: "arrows-clockwise"
              variant: pop.discovering ? "fill" : "regular"
              color: pop.enabled ? Colors.textPrim : Colors.textMuted
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

          Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 22
            radius: 11
            color: pop.enabled ? Colors.textPrim : Colors.border

            Rectangle {
              width: 14; height: 14; radius: 7
              y: 4
              x: pop.enabled ? parent.width - width - 4 : 4
              color: pop.enabled ? Colors.bgDeep : Colors.textMuted
              Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (pop.enabled) {
                  loader.powerOff()
                } else {
                  loader.powerOn()
                }
              }
            }
          }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Colors.overlay }

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
              color: rowArea.containsMouse ? Colors.surface : "transparent"
              radius: Colors.radiusSm
            }

            MouseArea {
              id: rowArea
              anchors.fill: parent
              anchors.rightMargin: 36
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onDoubleClicked: {
                if (!delegateRoot.dev?.address) return
                loader.btCmd([delegateRoot.isConnected ? "disconnect" : "connect", delegateRoot.dev.address])
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Colors.spacingMd
              anchors.rightMargin: 4
              spacing: Colors.spacingMd

              Icon {
                name: delegateRoot.isConnected ? "bluetooth-connected" : "bluetooth"
                color: delegateRoot.isConnected ? Colors.textPrim : Colors.textSecondary
                size: 9
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                  Layout.fillWidth: true
                  text: delegateRoot.dev?.name || delegateRoot.dev?.address || ""
                  color: Colors.textPrim
                  font.family: Colors.fontSecondary
                  font.pixelSize: Colors.fontSizeBase
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
                  color: Colors.textMuted
                  font.family: Colors.fontSecondary
                  font.pixelSize: Colors.fontSizeTiny
                }
              }

              Text {
                visible: delegateRoot.dev?.batteryAvailable ?? false
                text: Math.round((delegateRoot.dev?.battery ?? 0) * 100) + "%"
                color: Colors.textMuted
                font.family: Colors.fontMono
                font.pixelSize: Colors.fontSizeTiny
              }

              Rectangle {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: Colors.radiusSm
                color: forgetArea.containsMouse ? Colors.dangerBg : "transparent"
                border.width: forgetArea.containsMouse ? 1 : 0
                border.color: forgetArea.containsMouse ? Colors.danger : "transparent"
                opacity: rowArea.containsMouse || forgetArea.containsMouse ? 1 : 0.35
                Behavior on opacity { NumberAnimation { duration: 120 } }

                Text {
                  anchors.centerIn: parent
                  text: "✕"
                  color: forgetArea.containsMouse ? Colors.danger : Colors.textMuted
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

        Text {
          visible: pop.enabled && pop.devices.length === 0
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          text: pop.discovering ? "Поиск устройств…" : "Устройств нет"
          color: Colors.textMuted
          font.family: Colors.fontSecondary
          font.pixelSize: Colors.fontSizeSmall
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Colors.spacingSm

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            radius: Colors.radiusMd
            color: airpodsArea.containsMouse ? Colors.surface : "transparent"
            border.width: 1
            border.color: Colors.border

            Text {
              anchors.centerIn: parent
              text: "AirPods"
              color: Colors.textSecondary
              font.family: Colors.fontSecondary
              font.pixelSize: Colors.fontSizeSmall
            }

            MouseArea {
              id: airpodsArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                loader.open = false
                Quickshell.execDetached(["sh", "-c",
                  "pgrep -x librepods >/dev/null && hyprctl dispatch focuswindow class:librepods || setsid librepods >/dev/null 2>&1 < /dev/null &"])
              }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            radius: Colors.radiusMd
            color: managerArea.containsMouse ? Colors.surface : "transparent"
            border.width: 1
            border.color: Colors.border

            Text {
              anchors.centerIn: parent
              text: "Blueman"
              color: Colors.textSecondary
              font.family: Colors.fontSecondary
              font.pixelSize: Colors.fontSizeSmall
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
