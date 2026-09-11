import QtQuick
import QtCore
import Quickshell.Io
import "theme"

Item {
  id: root
  visible: hasBattery
  implicitWidth: Metrics.iconSize
  implicitHeight: Metrics.iconSize

  property string mode: "normal"
  property bool hasBattery: false
  readonly property string configHome: StandardPaths.writableLocation(StandardPaths.ConfigLocation)

  Process {
    id: detectBattery
    command: ["bash", "-c", "compgen -G '/sys/class/power_supply/BAT*' >/dev/null"]
    running: true
    onExited: (exitCode, exitStatus) => root.hasBattery = exitCode === 0
  }

  Process {
    id: get
    command: ["bash", root.configHome + "/hypr/scripts/power-mode.sh", "get"]
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
    command: ["bash", root.configHome + "/hypr/scripts/power-mode.sh", "toggle"]
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
    visible: root.hasBattery
    name: root.mode === "battery" ? "leaf" : "gauge"
    color: root.mode === "battery" ? "#86efac" : Qt.rgba(1, 1, 1, 0.55)
    size: Metrics.iconSize
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.hasBattery
    visible: root.hasBattery
    cursorShape: Qt.PointingHandCursor
    onClicked: { toggle.running = true }
  }
}
