import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "theme"
import "ui" as Ui

Scope {
  id: root

  property bool isOpen: false
  property bool isLoading: false
  property int selected: 0
  property var wallpapers: []
  readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper-apply.sh"

  function open() {
    root.selected = 0
    root.isLoading = true
    root.isOpen = true
    listProcess.running = true
  }

  function apply(index) {
    if (index < 0 || index >= root.wallpapers.length) return
    applyProcess.command = ["bash", root.script, "apply", root.wallpapers[index].path]
    applyProcess.running = true
    root.isOpen = false
  }

  IpcHandler {
    target: "wallpaper"
    function open(): void { root.open() }
    function close(): void { root.isOpen = false }
    function toggle(): void { if (root.isOpen) root.isOpen = false; else root.open() }
  }

  Process {
    id: listProcess
    command: ["bash", root.script, "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.wallpapers = JSON.parse(text)
          root.selected = 0
        } catch (error) {
          console.warn("Could not load wallpapers:", error)
          root.wallpapers = []
        }
        root.isLoading = false
      }
    }
    onExited: (exitCode) => {
      if (exitCode !== 0) root.isLoading = false
    }
  }

  Process { id: applyProcess }

  Loader {
    active: root.isOpen
    asynchronous: true

    sourceComponent: Ui.ModalOverlay {
      open: root.isOpen
      onDismissed: root.isOpen = false

      Ui.PanelSurface {
        anchors.centerIn: parent
        width: Math.min(1120, parent.width - 32)
        height: 300
        color: Colors.bgBase
        radius: Colors.radiusXl
        border.width: 1
        border.color: Colors.activeBorder

        Item {
          anchors.fill: parent
          anchors.margins: Metrics.menuPadding
          focus: true

          Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Left) {
              root.selected = Math.max(0, root.selected - 1)
              gallery.positionViewAtIndex(root.selected, ListView.Contain)
              event.accepted = true
            } else if (event.key === Qt.Key_Right) {
              root.selected = Math.min(root.wallpapers.length - 1, root.selected + 1)
              gallery.positionViewAtIndex(root.selected, ListView.Contain)
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.apply(root.selected)
              event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
              root.isOpen = false
              event.accepted = true
            }
          }

          ColumnLayout {
            anchors.fill: parent
            spacing: Metrics.menuPadding

            RowLayout {
              Layout.fillWidth: true
              Text {
                Layout.fillWidth: true
                text: "Wallpapers"
                color: Colors.textPrim
                font.family: Colors.fontPrimary
                font.pixelSize: Colors.fontSizeLarge
                font.weight: Font.Medium
              }
              Text {
                text: "← → select  ·  Enter apply  ·  Esc close"
                color: Colors.textMuted
                font.family: Colors.fontMono
                font.pixelSize: Colors.fontSizeSmall
              }
            }

            ListView {
              id: gallery
              Layout.fillWidth: true
              Layout.fillHeight: true
              orientation: ListView.Horizontal
              spacing: Metrics.menuPadding
              clip: true
              model: root.wallpapers
              boundsBehavior: Flickable.StopAtBounds

              delegate: Item {
                required property var modelData
                required property int index
                width: 210
                height: gallery.height

                Rectangle {
                  anchors.fill: parent
                  color: Colors.surface
                  radius: Colors.radiusLg
                  border.width: root.selected === index ? 2 : 1
                  border.color: root.selected === index ? Colors.activeBorder : Colors.border
                  clip: true

                  Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    visible: modelData.type === "image"
                    source: "file://" + modelData.path
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                  }

                  Rectangle {
                    anchors.fill: parent
                    visible: modelData.type === "video"
                    color: Colors.overlay
                    Icon {
                      anchors.centerIn: parent
                      name: "play"
                      color: Colors.textPrim
                      size: 36
                    }
                  }

                  Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 34
                    color: "#b0000000"
                    Text {
                      anchors.fill: parent
                      anchors.leftMargin: 8
                      anchors.rightMargin: 8
                      verticalAlignment: Text.AlignVCenter
                      text: modelData.type === "video" ? "VIDEO  " + modelData.name : modelData.name
                      color: Colors.textPrim
                      font.family: Colors.fontMono
                      font.pixelSize: Colors.fontSizeTiny
                      elide: Text.ElideMiddle
                    }
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  onEntered: root.selected = index
                  onClicked: root.selected = index
                  onDoubleClicked: root.apply(index)
                }
              }

              Text {
                anchors.centerIn: parent
                visible: root.isLoading || root.wallpapers.length === 0
                text: root.isLoading ? "Loading wallpapers..." : "Add images or videos to ~/wallpaper"
                color: Colors.textMuted
                font.family: Colors.fontPrimary
                font.pixelSize: Colors.fontSizeBase
              }
            }
          }
        }
      }
    }
  }
}
