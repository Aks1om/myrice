import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "theme"

Scope {
  id: root
  property bool isOpen: false
  property string query: ""
  property int selected: 0

  IpcHandler {
    target: "launcher"
    function open(): void   { root.query = ""; root.selected = 0; root.isOpen = true }
    function close(): void  { root.isOpen = false }
    function toggle(): void { if (!root.isOpen) { root.query = ""; root.selected = 0 } root.isOpen = !root.isOpen }
  }

  property var results: []

  function recompute() {
    const all = DesktopEntries.applications?.values ?? []
    const q = root.query.toLowerCase().trim()
    let arr

    if (!q) {
      arr = all.filter(a => !a.noDisplay)
               .slice()
               .sort((a, b) => (a.name || "").localeCompare(b.name || ""))
    } else {
      const matches = []
      for (const a of all) {
        if (a.noDisplay) continue
        const name = (a.name || "").toLowerCase()
        const generic = (a.genericName || "").toLowerCase()
        const comment = (a.comment || "").toLowerCase()
        const id = (a.id || "").toLowerCase()
        let score = -1
        if (name.startsWith(q)) score = 100
        else if (name.includes(q)) score = 80
        else if (id.includes(q)) score = 60
        else if (generic.includes(q)) score = 40
        else if (comment.includes(q)) score = 20
        if (score >= 0) matches.push({ app: a, score, name })
      }
      matches.sort((x, y) => {
        if (y.score !== x.score) return y.score - x.score
        return x.name.localeCompare(y.name)
      })
      arr = matches.map(m => m.app)
    }

    root.results = arr.slice(0, 100)
    if (root.selected >= root.results.length) root.selected = 0
  }

  onQueryChanged: recompute()
  Component.onCompleted: recompute()

  function launch(idx) {
    if (idx < 0 || idx >= root.results.length) return
    const app = root.results[idx]
    root.isOpen = false
    if (app && typeof app.execute === "function") app.execute()
  }

  Loader {
    id: loader
    active: root.isOpen
    asynchronous: true

    sourceComponent: PanelWindow {
      screen: Hyprland.focusedMonitor?.screen ?? Quickshell.screens[0]
      visible: true
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      anchors {
        top: true
        left: true
        right: true
        bottom: true
      }

      MouseArea {
        anchors.fill: parent
        onClicked: root.isOpen = false
      }

      Rectangle {
        anchors.centerIn: parent
        width: 620
        height: 480
        color: Colors.bgBase
        radius: Colors.radiusXl
        border.width: 1
        border.color: Colors.border

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Colors.marginXl
          spacing: Colors.spacingLg

          TextField {
            id: search
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            focus: true
            text: root.query
            placeholderText: "Search apps..."
            placeholderTextColor: Colors.textPlaceholder
            color: Colors.textPrim
            font.family: Colors.fontPrimary
            font.pixelSize: Colors.fontSizeLarge
            selectByMouse: true
            verticalAlignment: TextInput.AlignVCenter
            leftPadding: Colors.marginXl
            rightPadding: Colors.marginXl

            background: Rectangle {
              color: Colors.surface
              radius: Colors.radiusLg
              border.width: 1
              border.color: Colors.border
            }

            onTextChanged: root.query = text

            Keys.onPressed: (e) => {
              if (e.key === Qt.Key_Down) {
                root.selected = Math.min(root.results.length - 1, root.selected + 1)
                e.accepted = true
              } else if (e.key === Qt.Key_Up) {
                root.selected = Math.max(0, root.selected - 1)
                e.accepted = true
              } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                root.launch(root.selected)
                e.accepted = true
              } else if (e.key === Qt.Key_Escape) {
                root.isOpen = false
                e.accepted = true
              } else if (e.key === Qt.Key_Tab) {
                root.selected = (root.selected + 1) % Math.max(1, root.results.length)
                e.accepted = true
              }
            }
          }

          ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.results
            currentIndex: root.selected
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds

            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Item {
              required property var modelData
              required property int index
              width: list.width
              height: 44

              property bool isFocused: hoverArea.containsMouse || index === root.selected

              Rectangle {
                anchors.fill: parent
                anchors.rightMargin: 4
                color: parent.isFocused ? Colors.surface : "transparent"
                radius: Colors.radiusMd
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Colors.spacingLg
                anchors.rightMargin: Colors.spacingXl
                spacing: Colors.spacingLg

                Image {
                  Layout.preferredWidth: 24
                  Layout.preferredHeight: 24
                  source: modelData.icon
                         ? "image://icon/" + modelData.icon
                         : "image://icon/application-x-executable"
                  sourceSize.width: 48
                  sourceSize.height: 48
                  fillMode: Image.PreserveAspectFit
                  smooth: true
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 0
                  Text {
                    Layout.fillWidth: true
                    text: modelData.name || modelData.id
                    color: parent.parent.parent.isFocused ? Colors.textPrim : Colors.textSecondary
                    font.family: Colors.fontSecondary
                    font.pixelSize: Colors.fontSizeBase
                    elide: Text.ElideRight
                  }
                  Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: modelData.comment || ""
                    color: Colors.textHint
                    font.family: Colors.fontSecondary
                    font.pixelSize: Colors.fontSizeTiny
                    elide: Text.ElideRight
                  }
                }
              }

              MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selected = parent.index
                onClicked: root.launch(parent.index)
              }
            }
          }

          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            visible: root.results.length === 0
            text: root.query ? "No matches" : "No applications found"
            color: Colors.textPlaceholder
            font.family: Colors.fontPrimary
            font.pixelSize: Colors.fontSizeSmall
          }
        }
      }
    }
  }
}
