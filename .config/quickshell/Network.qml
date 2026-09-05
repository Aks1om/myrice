import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "theme"

Item {
  id: root
  implicitWidth: layout.implicitWidth
  implicitHeight: layout.implicitHeight

  property bool wifiEnabled: false
  property bool wifiConnected: false
  property bool ethernetConnected: false
  property string activeSsid: ""
  property int activeStrength: 0
  property var networks: []
  property var knownConnections: ({})
  property bool scanning: false

  readonly property string kind: ethernetConnected ? "eth"
                               : !wifiEnabled       ? "off"
                               : wifiConnected      ? "wifi"
                                                    : "wifi-off"
   readonly property string label: kind === "eth"     ? ""
                                : kind === "wifi"    ? activeStrength + "%"
                                : kind === "wifi-off"? "—"
                                                     : "off"

  function refreshAll() {
    statusProc.running = true
    radioProc.running = true
  }

  function rescan() {
    if (scanning) return
    scanning = true
    rescanProc.running = true
  }

  function setWifiEnabled(on) {
    radioToggleProc.command = ["nmcli", "radio", "wifi", on ? "on" : "off"]
    radioToggleProc.running = true
  }

  function connectOpen(ssid) {
    connectProc.command = ["nmcli", "device", "wifi", "connect", ssid]
    connectProc.running = true
  }

  function connectWithPassword(ssid, password) {
    connectProc.command = ["nmcli", "device", "wifi", "connect", ssid, "password", password]
    connectProc.running = true
  }

  function connectKnown(ssid) {
    connectProc.command = ["nmcli", "connection", "up", "id", ssid]
    connectProc.running = true
  }

  function forget(ssid) {
    forgetProc.command = ["nmcli", "connection", "delete", "id", ssid]
    forgetProc.running = true
  }

  function disconnectActive() {
    if (!activeSsid) return
    disconnectProc.command = ["nmcli", "connection", "down", activeSsid]
    disconnectProc.running = true
  }

  Process {
    id: monitor
    running: true
    command: ["nmcli", "monitor"]
    environment: ({ LANG: "C", LC_ALL: "C" })
    stdout: SplitParser { onRead: () => root.refreshAll() }
    onExited: Qt.callLater(() => { monitor.running = true })
  }

  Process {
    id: statusProc
    running: true
    command: ["nmcli", "-t", "-f", "TYPE,STATE", "device"]
    environment: ({ LANG: "C", LC_ALL: "C" })
    property string buffer: ""
    stdout: SplitParser { onRead: (line) => statusProc.buffer += line + "\n" }
    onStarted: buffer = ""
    onExited: {
      let eth = false, wifi = false
      for (const ln of statusProc.buffer.trim().split("\n")) {
        const [t, s] = ln.split(":")
        if (s !== "connected") continue
        if (t === "ethernet") eth = true
        else if (t === "wifi") wifi = true
      }
      root.ethernetConnected = eth
      root.wifiConnected = wifi
      savedProc.running = true
    }
  }

  Process {
    id: savedProc
    running: true
    command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
    environment: ({ LANG: "C", LC_ALL: "C" })
    property string buffer: ""
    onStarted: buffer = ""
    stdout: SplitParser { onRead: (line) => savedProc.buffer += line + "\n" }
    onExited: {
      const k = {}
      const PH = " COL "
      for (const raw of savedProc.buffer.trim().split("\n")) {
        if (!raw) continue
        const line = raw.replace(/\\:/g, PH)
        const parts = line.split(":")
        if (parts.length < 2) continue
        const name = (parts[0] || "").replace(new RegExp(PH, "g"), ":")
        const type = parts[parts.length - 1]
        if (type === "802-11-wireless") k[name] = true
      }
      root.knownConnections = k
      listProc.running = true
    }
  }

  Process {
    id: radioProc
    running: true
    command: ["nmcli", "radio", "wifi"]
    environment: ({ LANG: "C", LC_ALL: "C" })
    stdout: StdioCollector {
      onStreamFinished: root.wifiEnabled = text.trim() === "enabled"
    }
  }

  Process {
    id: radioToggleProc
    onExited: root.refreshAll()
  }

  Process {
    id: listProc
    command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SECURITY,SSID", "device", "wifi"]
    environment: ({ LANG: "C", LC_ALL: "C" })
    property string buffer: ""
    onStarted: buffer = ""
    stdout: SplitParser { onRead: (line) => listProc.buffer += line + "\n" }
    onExited: {
      const seen = new Map()
      let activeSsid = ""
      let activeStrength = 0
      const PH = " COL "
      for (const raw of listProc.buffer.trim().split("\n")) {
        if (!raw) continue
        const line = raw.replace(/\\:/g, PH)
        const parts = line.split(":")
        if (parts.length < 4) continue
        const inUse = parts[0] === "*"
        const strength = parseInt(parts[1] || "0", 10)
        const security = (parts[2] || "").replace(new RegExp(PH, "g"), ":")
        const ssid = (parts[3] || "").replace(new RegExp(PH, "g"), ":")
        if (!ssid) continue
        if (inUse) {
          activeSsid = ssid
          activeStrength = strength
        }
        const prev = seen.get(ssid)
        if (!prev || strength > prev.strength || inUse) {
          seen.set(ssid, { ssid, strength, security, inUse, known: !!root.knownConnections[ssid] })
        }
      }
      const arr = Array.from(seen.values()).sort((a, b) => {
        if (a.inUse !== b.inUse) return a.inUse ? -1 : 1
        return b.strength - a.strength
      })
      root.networks = arr
      root.activeSsid = activeSsid
      root.activeStrength = activeStrength
    }
  }

  Process {
    id: rescanProc
    command: ["nmcli", "device", "wifi", "rescan"]
    environment: ({ LANG: "C", LC_ALL: "C" })
    onExited: {
      listProc.running = true
      root.scanning = false
    }
  }

  Process {
    id: connectProc
    environment: ({ LANG: "C", LC_ALL: "C" })
    property string err: ""
    onStarted: err = ""
    stderr: SplitParser { onRead: (line) => connectProc.err += line + "\n" }
    onExited: {
      panel.lastError = (exitCode === 0) ? "" : connectProc.err.trim()
      panel.connecting = ""
      root.refreshAll()
    }
  }

  Process {
    id: disconnectProc
    environment: ({ LANG: "C", LC_ALL: "C" })
    onExited: root.refreshAll()
  }

  Process {
    id: forgetProc
    environment: ({ LANG: "C", LC_ALL: "C" })
    onExited: root.refreshAll()
  }

  Process { id: openEditor; command: ["nm-connection-editor"] }

  RowLayout {
    id: layout
    anchors.fill: parent
    spacing: Colors.spacingSm

    Icon {
      Layout.alignment: Qt.AlignVCenter
      variant: "bold"
       name: root.kind === "eth" ? "monitor"
          : root.kind === "wifi"
            ? (root.activeStrength >= 75 ? "wifi-high"
              : root.activeStrength >= 50 ? "wifi-medium"
              : root.activeStrength >= 25 ? "wifi-low"
                                          : "wifi-none")
            : root.kind === "wifi-off" ? "wifi-x"
            : "wifi-slash"
      color: (root.kind === "off" || root.kind === "wifi-off")
             ? Qt.rgba(1, 1, 1, 0.5) : Colors.textPrim
      size: 15
    }
    Text {
      visible: root.label.length > 0
      Layout.alignment: Qt.AlignVCenter
      text: root.label
      color: Colors.textPrim
      font.family: Colors.fontMono
      font.pixelSize: Colors.fontSizeBase
      font.weight: Font.Bold
    }
  }

  MouseArea {
    id: clickArea
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: (e) => {
      if (e.button === Qt.RightButton) {
        openEditor.running = true
      } else {
        if (panel.open) panel.open = false
        else {
          root.rescan()
          panel.open = true
        }
      }
    }
  }

  NetworkPanel {
    id: panel
    anchorItem: clickArea
    network: root
  }
}
