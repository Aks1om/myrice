import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

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

  // Cached filtered list (recomputed on query change)
  property var results: []

  function recompute() {
    const all = DesktopEntries.applications.values
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
        color: "#000000"
        radius: 14
        border.width: 1
        border.color: "#3a3a3a"

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 12
          spacing: 10

          TextField {
            id: search
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            focus: true
            text: root.query
            placeholderText: "Search apps..."
            placeholderTextColor: "#5e5e5e"
            color: "#ffffff"
            font.family: "Inter"
            font.pixelSize: 14
            selectByMouse: true
            verticalAlignment: TextInput.AlignVCenter
            leftPadding: 14
            rightPadding: 14

            background: Rectangle {
              color: "#1c1c1c"
              radius: 10
              border.width: 1
              border.color: "#2a2a2a"
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
                color: parent.isFocused ? "#1c1c1c" : "transparent"
                radius: 8
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 14
                spacing: 10

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
                    color: parent.parent.parent.isFocused ? "#ffffff" : "#cfcfcf"
                    font.family: "Manrope"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                  }
                  Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: modelData.comment || ""
                    color: "#7a7a7a"
                    font.family: "Manrope"
                    font.pixelSize: 10
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
            color: "#5e5e5e"
            font.family: "Inter"
            font.pixelSize: 11
          }
        }
      }
    }
  }
}
