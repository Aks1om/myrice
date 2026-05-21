import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

Item {
  id: root
  implicitWidth: layout.implicitWidth
  implicitHeight: layout.implicitHeight

  // Known dongle MAC — Quickshell.BluetoothAdapter has no `address` property,
  // so we map dbusPath -> MAC via busctl and identify dongle by MAC.
  readonly property string dongleAddress: "8C:68:8B:C0:69:C1"

  // dbusPath -> MAC (filled by macFetcher)
  property var pathToMac: ({})
  property int _adaptersTick: 0
  property int _macTick: 0

  // Subscribe to adapter list changes; trigger MAC refresh
  Connections {
    target: Bluetooth.adapters
    function onValuesChanged() { root._adaptersTick++; macFetcher.running = true }
    function onObjectInsertedPost() { root._adaptersTick++; macFetcher.running = true }
    function onObjectRemovedPost() { root._adaptersTick++ }
  }

  // Re-fetch MACs periodically as a safety net (in case adapter appears
  // between events).
  Timer {
    interval: 2000; running: true; repeat: false
    onTriggered: macFetcher.running = true
  }

  Process {
    id: macFetcher
    command: ["busctl", "--system", "call", "org.bluez", "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects"]
    stdout: StdioCollector {
      onStreamFinished: {
        const txt = String(this.text || "")
        const blocks = txt.split(/(?="\/org\/bluez\/)/)
        const map = {}
        const adapterRe = /^"?\/org\/bluez\/(hci\d+)"?\s+\d+/
        const macRe = /"Address"\s+s\s+"((?:[0-9A-F]{2}:){5}[0-9A-F]{2})"/
        for (const b of blocks) {
          const p = b.match(adapterRe); if (!p) continue
          const a = b.match(macRe); if (!a) continue
          map["/org/bluez/" + p[1]] = a[1].toUpperCase()
        }
        root.pathToMac = map
        root._macTick++
      }
    }
  }

  function _isDongleAdapter(a) {
    if (!a) return false
    return root.pathToMac[a.dbusPath] === root.dongleAddress
  }

  // Prefer dongle when present, fall back to bluez default
  readonly property var adapter: {
    root._adaptersTick; root._macTick  // deps
    const am = Bluetooth.adapters
    if (am) {
      const list = am.values
      for (let i = 0; i < list.length; i++) {
        if (root._isDongleAdapter(list[i])) return list[i]
      }
    }
    return Bluetooth.defaultAdapter
  }
  readonly property bool enabled: adapter ? adapter.enabled : false
  readonly property var connectedDevice: {
    if (!adapter || !adapter.devices) return null
    const dl = adapter.devices.values
    for (let i = 0; i < dl.length; i++) if (dl[i].connected) return dl[i]
    return null
  }
  readonly property bool isDongle: root._isDongleAdapter(adapter)

  RowLayout {
    id: layout
    anchors.fill: parent
    spacing: 4

    Icon {
      Layout.alignment: Qt.AlignVCenter
      name: !root.enabled ? "bluetooth-slash"
          : root.connectedDevice ? "bluetooth-connected"
                                 : "bluetooth"
      color: !root.enabled ? Qt.rgba(1, 1, 1, 0.5) : "#ffffff"
      size: 16
    }

    // Adapter source badge: USB (dongle) or BT (built-in)
    Text {
      Layout.alignment: Qt.AlignVCenter
      visible: root.adapter !== null && root.adapter !== undefined
      text: root.isDongle ? "USB" : "BT"
      color: !root.enabled ? Qt.rgba(1, 1, 1, 0.4)
           : root.isDongle ? "#7dd3fc" : "#fbbf24"
      font.family: "Manrope"
      font.pixelSize: 8
      font.weight: Font.Bold
    }
  }

  MouseArea {
    id: clickArea
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: { if (panel.open) panel.open = false; else panel.open = true }
  }

  BluetoothPanel {
    id: panel
    anchorItem: clickArea
  }
}
