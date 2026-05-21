import QtQuick
import Quickshell.Hyprland
import Quickshell.Io

Item {
  id: root
  implicitWidth: txt.implicitWidth
  implicitHeight: txt.implicitHeight

  property string layoutName: ""

  // Initial fetch
  Process {
    id: probe
    running: true
    command: ["bash", "-c", "hyprctl -j devices | python3 -c \"import json,sys; d=json.load(sys.stdin); k=next((x for x in d.get('keyboards',[]) if x.get('main')), None); print(k.get('active_keymap','') if k else '')\""]
    stdout: StdioCollector {
      onStreamFinished: { root.layoutName = text.trim().toLowerCase(); }
    }
  }

  // Real-time event stream from Hyprland socket2
  Process {
    id: events
    running: true
    command: ["python3", "-u", "-c", `
import socket, os, sys
p = f"{os.environ['XDG_RUNTIME_DIR']}/hypr/{os.environ['HYPRLAND_INSTANCE_SIGNATURE']}/.socket2.sock"
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(p)
f = s.makefile('r')
for line in f:
    sys.stdout.write(line)
    sys.stdout.flush()
`]
    stdout: SplitParser {
      onRead: (line) => {
        const i = line.indexOf(">>");
        if (i < 0) return;
        const name = line.slice(0, i);
        const data = line.slice(i + 2);
        if (name === "activelayout") {
          const parts = data.split(",");
          if (parts.length >= 2) root.layoutName = parts[parts.length - 1].toLowerCase();
        }
      }
    }
  }

  Text {
    id: txt
    anchors.centerIn: parent
    text: root.layoutName.startsWith("rus") ? "ru"
        : root.layoutName.startsWith("eng") ? "en"
        : root.layoutName.slice(0, 2)
    color: "#ffffff"
    font.family: "Inter"
    font.pixelSize: 12
    font.weight: Font.Medium
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Hyprland.dispatch("exec bash /home/aks1om/.config/hypr/scripts/toggle-layout.sh")
  }
}
