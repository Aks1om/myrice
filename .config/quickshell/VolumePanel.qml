import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

Loader {
  id: loader
  property var anchorItem
  property bool open: false

  active: open
  asynchronous: true

  Process { id: setDefault }
  function makeDefault(name) {
    setDefault.command = ["wpctl", "set-default", name]
    setDefault.running = true
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
      margins.top: 8
    }

    HyprlandFocusGrab {
      active: loader.open
      windows: [pop]
      onCleared: loader.open = false
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    PwObjectTracker { objects: [pop.sink, pop.source].filter(o => o) }

    Rectangle {
      id: container
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 10
      color: "#000000"
      radius: 14
      border.width: 1
      border.color: "#3a3a3a"
      implicitHeight: col.implicitHeight + 20

      MouseArea { anchors.fill: parent; onClicked: {} }

      ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        spacing: 8

        // --- Output: master row ---
        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Icon {
            name: pop.sink?.audio?.muted ? "speaker-slash"
                : (pop.sink?.audio?.volume ?? 0) >= 0.7 ? "speaker-high"
                : (pop.sink?.audio?.volume ?? 0) >= 0.3 ? "speaker-low"
                                                       : "speaker-none"
            color: pop.sink?.audio?.muted ? Qt.rgba(1, 1, 1, 0.5) : "#ffffff"
            size: 14
          }

          Text {
            Layout.fillWidth: true
            text: pop.sink?.description || pop.sink?.name || "No output"
            color: "#ffffff"
            font.family: "Manrope"
            font.pixelSize: 12
            elide: Text.ElideRight
          }

          Text {
            text: pop.sink?.audio?.muted ? "mute"
                                         : Math.round((pop.sink?.audio?.volume ?? 0) * 100) + "%"
            color: "#cfcfcf"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
          }
        }

        // Volume slider
        Slider {
          id: volSlider
          Layout.fillWidth: true
          Layout.preferredHeight: 20
          from: 0
          to: 1
          stepSize: 0.01
          enabled: !!pop.sink?.audio
          value: pop.sink?.audio?.volume ?? 0

          onMoved: { if (pop.sink?.audio) pop.sink.audio.volume = value }

          background: Rectangle {
            x: volSlider.leftPadding
            y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
            width: volSlider.availableWidth
            height: 4
            radius: 2
            color: "#2a2a2a"
            Rectangle {
              width: volSlider.visualPosition * parent.width
              height: parent.height
              color: pop.sink?.audio?.muted ? "#5a5a5a" : "#ffffff"
              radius: 2
            }
          }

          handle: Rectangle {
            x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
            y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
            width: 14
            height: 14
            radius: 7
            color: pop.sink?.audio?.muted ? "#5a5a5a" : "#ffffff"
          }
        }

        // Mute toggle full-width
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 28
          radius: 8
          color: muteArea.containsMouse ? "#1c1c1c" : "transparent"
          border.width: 1
          border.color: "#3a3a3a"

          Text {
            anchors.centerIn: parent
            text: pop.sink?.audio?.muted ? "Unmute" : "Mute"
            color: "#cfcfcf"
            font.family: "Manrope"
            font.pixelSize: 11
          }

          MouseArea {
            id: muteArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { if (pop.sink?.audio) pop.sink.audio.muted = !pop.sink.audio.muted }
          }
        }

        // separator
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 1
          color: "#252525"
        }

        // --- Output devices ---
        Text {
          text: "Output device"
          color: "#909090"
          font.family: "Manrope"
          font.pixelSize: 10
        }

        Repeater {
          model: Pipewire.nodes.values.filter(n =>
            n.isSink && n.audio && !n.isStream)
          delegate: Item {
            required property var modelData
            Layout.fillWidth: true
            height: 32
            property bool isActive: pop.sink && modelData.id === pop.sink.id

            Rectangle {
              anchors.fill: parent
              color: rowArea.containsMouse ? "#1c1c1c" : "transparent"
              radius: 6
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              spacing: 8

              Text {
                Layout.fillWidth: true
                text: modelData.description || modelData.name || ""
                color: parent.parent.isActive ? "#ffffff" : "#cfcfcf"
                font.family: "Manrope"
                font.pixelSize: 11
                font.weight: parent.parent.isActive ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
              }
              Text {
                visible: parent.parent.isActive
                text: "✓"
                color: "#ffffff"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
              }
            }

            MouseArea {
              id: rowArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: loader.makeDefault(modelData.name)
            }
          }
        }

        // --- Input (mic) if available ---
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 1
          color: "#252525"
          visible: pop.source !== null && pop.source !== undefined
        }

        RowLayout {
          Layout.fillWidth: true
          visible: pop.source !== null && pop.source !== undefined
          spacing: 8

          Icon {
            name: pop.source?.audio?.muted ? "microphone-slash" : "microphone"
            color: pop.source?.audio?.muted ? Qt.rgba(1, 1, 1, 0.5) : "#ffffff"
            size: 14
          }
          Text {
            Layout.fillWidth: true
            text: pop.source?.description || pop.source?.name || ""
            color: "#cfcfcf"
            font.family: "Manrope"
            font.pixelSize: 11
            elide: Text.ElideRight
          }
          Text {
            text: pop.source?.audio?.muted ? "mute"
                                           : Math.round((pop.source?.audio?.volume ?? 0) * 100) + "%"
            color: "#909090"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
          }
        }

        Slider {
          id: micSlider
          Layout.fillWidth: true
          Layout.preferredHeight: 18
          visible: pop.source !== null && pop.source !== undefined
          from: 0
          to: 1
          stepSize: 0.01
          enabled: !!pop.source?.audio
          value: pop.source?.audio?.volume ?? 0

          onMoved: { if (pop.source?.audio) pop.source.audio.volume = value }

          background: Rectangle {
            x: micSlider.leftPadding
            y: micSlider.topPadding + micSlider.availableHeight / 2 - height / 2
            width: micSlider.availableWidth
            height: 3
            radius: 2
            color: "#2a2a2a"
            Rectangle {
              width: micSlider.visualPosition * parent.width
              height: parent.height
              color: pop.source?.audio?.muted ? "#5a5a5a" : "#cfcfcf"
              radius: 2
            }
          }

          handle: Rectangle {
            x: micSlider.leftPadding + micSlider.visualPosition * (micSlider.availableWidth - width)
            y: micSlider.topPadding + micSlider.availableHeight / 2 - height / 2
            width: 12
            height: 12
            radius: 6
            color: pop.source?.audio?.muted ? "#5a5a5a" : "#cfcfcf"
          }
        }
      }
    }
  }
}
