import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

Item {
  id: root
  implicitWidth: layout.implicitWidth
  implicitHeight: layout.implicitHeight
  visible: !!player

  readonly property var players: Mpris.players?.values ?? []
  readonly property var player: players.find(p => p.playbackState === MprisPlaybackState.Playing)
                                ?? players.find(p => p.canControl)
                                ?? players[0]

  RowLayout {
    id: layout
    anchors.fill: parent
    spacing: 6

    Icon {
      Layout.alignment: Qt.AlignVCenter
      name: root.player?.playbackState === MprisPlaybackState.Playing ? "pause" : "play"
      color: "#ffffff"
      size: 14
    }
    Text {
      Layout.alignment: Qt.AlignVCenter
      Layout.maximumWidth: 240
      text: {
        if (!root.player) return "";
        const t = root.player.trackTitle ?? "";
        const a = root.player.trackArtist ?? "";
        return a ? `${a} — ${t}` : t;
      }
      elide: Text.ElideRight
      color: "#ffffff"
      font.family: "Inter"
      font.pixelSize: 12
      font.weight: Font.Bold
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor
    onClicked: (m) => {
      if (!root.player) return;
      if (m.button === Qt.LeftButton) root.player.togglePlaying();
      else if (m.button === Qt.RightButton) root.player.next();
      else if (m.button === Qt.MiddleButton) root.player.previous();
    }
  }
}
