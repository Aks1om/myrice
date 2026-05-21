import QtQuick
import Quickshell.Io

Item {
  id: root
  implicitWidth: 16
  implicitHeight: 16

  property string mode: "balanced"

  Process {
    id: get
    command: ["bash", "/home/aks1om/.config/hypr/scripts/power-mode.sh", "get"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const j = JSON.parse(text);
          root.mode = j.class || "balanced";
        } catch (_) {}
      }
    }
  }
  Process {
    id: toggle
    command: ["bash", "/home/aks1om/.config/hypr/scripts/power-mode.sh", "toggle"]
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: get.running = true
  }

  Icon {
    anchors.fill: parent
    name: root.mode === "performance" ? "lightning"
        : root.mode === "powersave" ? "leaf"
                                    : "gauge"
    color: root.mode === "performance" ? "#ffffff"
         : root.mode === "powersave" ? "#86efac"
                                     : Qt.rgba(1, 1, 1, 0.55)
    size: 16
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: { toggle.running = true; get.running = true; }
  }
}
