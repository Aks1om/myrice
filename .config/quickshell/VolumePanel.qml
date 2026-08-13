import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import "theme"
import "ui" as Ui

Loader {
  id: loader
  property var anchorItem
  property bool open: false

  active: open
  asynchronous: true

  Process { id: setDefault }
  function makeDefault(id) {
    setDefault.command = ["wpctl", "set-default", String(id)]
    setDefault.running = true
  }

  sourceComponent: Ui.AnchoredPopup {
    id: pop
    visible: true
    anchorItem: loader.anchorItem
    open: loader.open

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    PwObjectTracker { objects: [pop.sink, pop.source].filter(o => o) }

    Ui.PanelSurface {
      id: container
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Metrics.popupInset
      implicitHeight: col.implicitHeight + Metrics.panelPadding * 2

      MouseArea { anchors.fill: parent; onClicked: {} }

      Ui.PanelColumn {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Metrics.panelPadding

        RowLayout {
          Layout.fillWidth: true
          spacing: Colors.spacingMd

          Icon {
            name: pop.sink?.audio?.muted ? "speaker-slash"
                : (pop.sink?.audio?.volume ?? 0) >= 0.7 ? "speaker-high"
                : (pop.sink?.audio?.volume ?? 0) >= 0.3 ? "speaker-low"
                                                       : "speaker-none"
            color: pop.sink?.audio?.muted ? Qt.rgba(1, 1, 1, 0.5) : Colors.textPrim
            size: 9
          }

          Text {
            Layout.fillWidth: true
            text: pop.sink?.description || pop.sink?.name || "No output"
            color: Colors.textPrim
            font.family: Colors.fontSecondary
            font.pixelSize: Colors.fontSizeBase
            elide: Text.ElideRight
          }

          Text {
            text: pop.sink?.audio?.muted ? "mute"
                                         : Math.round((pop.sink?.audio?.volume ?? 0) * 100) + "%"
            color: Colors.textSecondary
            font.family: Colors.fontMono
            font.pixelSize: Colors.fontSizeSmall
          }
        }

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
            color: Colors.overlay
            Rectangle {
              width: volSlider.visualPosition * parent.width
              height: parent.height
              color: pop.sink?.audio?.muted ? Colors.textMuted : Colors.textPrim
              radius: 2
            }
          }

          handle: Rectangle {
            x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
            y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
            width: 14
            height: 14
            radius: 7
            color: pop.sink?.audio?.muted ? "#5a5a5a" : Colors.textPrim
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 28
          radius: Colors.radiusMd
          color: muteArea.containsMouse ? Colors.surface : "transparent"
          border.width: 1
          border.color: Colors.border

          Text {
            anchors.centerIn: parent
            text: pop.sink?.audio?.muted ? "Unmute" : "Mute"
            color: Colors.textSecondary
            font.family: Colors.fontSecondary
            font.pixelSize: Colors.fontSizeSmall
          }

          MouseArea {
            id: muteArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { if (pop.sink?.audio) pop.sink.audio.muted = !pop.sink.audio.muted }
          }
        }

        Ui.Divider {}

        Text {
          text: "Output device"
          color: Colors.textMuted
          font.family: Colors.fontSecondary
          font.pixelSize: Colors.fontSizeTiny
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
              color: rowArea.containsMouse ? Colors.surface : "transparent"
              radius: Colors.radiusSm
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Colors.marginMd
              anchors.rightMargin: Colors.marginMd
              spacing: Colors.spacingMd

              Text {
                Layout.fillWidth: true
                text: modelData.description || modelData.name || ""
                color: parent.parent.isActive ? Colors.textPrim : Colors.textSecondary
                font.family: Colors.fontSecondary
                font.pixelSize: Colors.fontSizeSmall
                font.weight: parent.parent.isActive ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
              }
              Text {
                visible: parent.parent.isActive
                text: "✓"
                color: Colors.textPrim
                font.family: Colors.fontMono
                font.pixelSize: Colors.fontSizeTiny
              }
            }

            MouseArea {
              id: rowArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: loader.makeDefault(modelData.id)
            }
          }
        }

        Ui.Divider {
          visible: pop.source !== null && pop.source !== undefined
        }

        RowLayout {
          Layout.fillWidth: true
          visible: pop.source !== null && pop.source !== undefined
          spacing: Colors.spacingMd

          Icon {
            name: pop.source?.audio?.muted ? "microphone-slash" : "microphone"
            color: pop.source?.audio?.muted ? Qt.rgba(1, 1, 1, 0.5) : Colors.textPrim
            size: 9
          }
          Text {
            Layout.fillWidth: true
            text: pop.source?.description || pop.source?.name || ""
            color: Colors.textSecondary
            font.family: Colors.fontSecondary
            font.pixelSize: Colors.fontSizeSmall
            elide: Text.ElideRight
          }
          Text {
            text: pop.source?.audio?.muted ? "mute"
                                           : Math.round((pop.source?.audio?.volume ?? 0) * 100) + "%"
            color: Colors.textMuted
            font.family: Colors.fontMono
            font.pixelSize: Colors.fontSizeTiny
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
            color: Colors.overlay
            Rectangle {
              width: micSlider.visualPosition * parent.width
              height: parent.height
              color: pop.source?.audio?.muted ? Colors.textMuted : Colors.textSecondary
              radius: 2
            }
          }

          handle: Rectangle {
            x: micSlider.leftPadding + micSlider.visualPosition * (micSlider.availableWidth - width)
            y: micSlider.topPadding + micSlider.availableHeight / 2 - height / 2
            width: 12
            height: 12
            radius: 6
            color: pop.source?.audio?.muted ? Colors.textMuted : Colors.textSecondary
          }
        }
      }
    }
  }
}
