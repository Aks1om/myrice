import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
  id: root
  implicitWidth: layout.implicitWidth
  implicitHeight: layout.implicitHeight

  property int count: 0
  property bool dnd: false

  Process {
    id: countProbe
    command: ["swaync-client", "-c"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const n = parseInt(text.trim(), 10);
        if (!isNaN(n)) root.count = n;
      }
    }
  }
  Process {
    id: dndProbe
    command: ["swaync-client", "-D"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: { root.dnd = text.trim() === "true"; }
    }
  }
  Process { id: toggleUi; command: ["swaync-client", "-t", "-sw"] }
  Process { id: toggleDnd; command: ["swaync-client", "-d", "-sw"] }

  Timer {
    interval: 3000
    running: true
    repeat: true
    onTriggered: { countProbe.running = true; dndProbe.running = true; }
  }

  RowLayout {
    id: layout
    anchors.fill: parent
    spacing: 6

    Icon {
      Layout.alignment: Qt.AlignVCenter
      name: root.dnd ? "bell-slash"
          : root.count > 0 ? "bell-ringing"
                           : "bell"
      color: root.dnd ? "#c4b5fd"
           : root.count > 0 ? "#ffffff"
                            : Qt.rgba(1, 1, 1, 0.55)
      size: 16
    }
    Text {
      Layout.alignment: Qt.AlignVCenter
      visible: root.count > 0 && !root.dnd
      text: root.count
      color: "#ffffff"
      font.family: "Inter"
      font.pixelSize: 11
      font.weight: Font.Medium
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: (m) => {
      if (m.button === Qt.LeftButton) toggleUi.running = true;
      else { toggleDnd.running = true; dndProbe.running = true; }
    }
  }
}
