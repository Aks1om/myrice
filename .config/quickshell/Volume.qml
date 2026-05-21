import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Pipewire

Item {
  id: root
  implicitWidth: layout.implicitWidth
  implicitHeight: layout.implicitHeight

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property real vol: sink?.audio?.volume ?? 0
  readonly property bool muted: sink?.audio?.muted ?? false

  PwObjectTracker { objects: sink ? [sink] : [] }

  RowLayout {
    id: layout
    anchors.fill: parent
    spacing: 6

    Icon {
      Layout.alignment: Qt.AlignVCenter
      name: root.muted ? "speaker-slash"
          : root.vol >= 0.7 ? "speaker-high"
          : root.vol >= 0.3 ? "speaker-low"
                            : "speaker-none"
      color: root.muted ? Qt.rgba(1, 1, 1, 0.5) : "#ffffff"
      size: 16
    }
  }

  MouseArea {
    id: clickArea
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    onWheel: (e) => {
      if (!root.sink?.audio) return;
      const step = 0.05;
      root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + (e.angleDelta.y > 0 ? step : -step)));
    }
    onClicked: (m) => {
      if (m.button === Qt.MiddleButton && root.sink?.audio) {
        root.sink.audio.muted = !root.sink.audio.muted;
      } else {
        if (panel.open) panel.open = false
        else panel.open = true
      }
    }
  }

  VolumePanel {
    id: panel
    anchorItem: clickArea
  }
}
