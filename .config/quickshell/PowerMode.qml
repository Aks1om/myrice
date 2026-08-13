import QtQuick
import Quickshell.Io
import "theme"

Item {
  id: root
  implicitWidth: 16
  implicitHeight: 16

  property string mode: "normal"

  Process {
    id: get
    command: ["bash", "/home/aks1om/.config/hypr/scripts/power-mode.sh", "get"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const j = JSON.parse(text);
          root.mode = j.class === "battery" ? "battery" : "normal";
        } catch (_) {}
      }
    }
  }
  Process {
    id: toggle
    command: ["bash", "/home/aks1om/.config/hypr/scripts/power-mode.sh", "toggle"]
    onExited: get.running = true
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: get.running = true
  }

  Icon {
    anchors.fill: parent
    name: root.mode === "battery" ? "leaf" : "gauge"
    color: root.mode === "battery" ? "#86efac" : Qt.rgba(1, 1, 1, 0.55)
    size: 16
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: { toggle.running = true }
  }
}
