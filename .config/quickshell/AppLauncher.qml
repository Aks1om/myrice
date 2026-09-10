import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import "theme"
import "ui" as Ui

Scope {
  id: root
  property bool isOpen: false
  property string query: ""
  property int selected: 0
  property bool keyboardSelecting: false
  property int keyboardGeneration: 0

  IpcHandler {
    target: "launcher"
    function open(): void   { root.query = ""; root.selected = 0; root.keyboardGeneration++; root.keyboardSelecting = true; root.isOpen = true }
    function close(): void  { root.isOpen = false }
    function toggle(): void { if (!root.isOpen) { root.query = ""; root.selected = 0; root.keyboardGeneration++; root.keyboardSelecting = true } root.isOpen = !root.isOpen }
  }

  property var results: []
  property string pendingAppId: ""
  property string pendingAppStartupClass: ""
  property string pendingAppName: ""
  property var pendingApp: null
  readonly property string userBin: Quickshell.env("HOME") + "/.local/bin"

  Process {
    id: launchProcess
    command: [root.userBin + "/launch-or-focus", root.pendingAppId, root.pendingAppStartupClass, root.pendingAppName]
    running: false

    onExited: (exitCode, exitStatus) => {
      const app = root.pendingApp
      root.pendingApp = null
      if (exitCode !== 0 && app && typeof app.execute === "function") app.execute()
    }
  }

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
    root.selected = Math.max(0, Math.min(root.selected, root.results.length - 1))
  }

  onQueryChanged: recompute()
  Component.onCompleted: recompute()

  Connections {
    target: DesktopEntries
    function onApplicationsChanged() { root.recompute() }
  }

  function launch(idx) {
    if (idx < 0 || idx >= root.results.length) return
    const app = root.results[idx]
    if (!app) return

    root.isOpen = false
    root.pendingApp = app
    root.pendingAppId = app.id || app.name || ""
    root.pendingAppStartupClass = app.startupClass || ""
    root.pendingAppName = app.name || ""
    launchProcess.running = true
  }

  Loader {
    id: loader
    active: root.isOpen
    asynchronous: true

    sourceComponent: Ui.ModalOverlay {
      open: root.isOpen
      onDismissed: root.isOpen = false

      Ui.PanelSurface {
        anchors.centerIn: parent
        width: Metrics.launcherWidth
        height: Metrics.launcherHeight
        color: Colors.bgBase
        radius: Colors.radiusXl
        border.width: 1
        border.color: Colors.activeBorder

        MouseArea { anchors.fill: parent; onClicked: {} }

        Ui.PanelColumn {
          anchors.fill: parent
          anchors.margins: Metrics.menuPadding
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

            onTextChanged: { root.query = text; root.selected = 0; root.keyboardGeneration++; root.keyboardSelecting = true }

            Keys.onPressed: (e) => {
              if (e.key === Qt.Key_Down) {
                root.keyboardGeneration++
                root.keyboardSelecting = true
                root.selected = Math.min(root.results.length - 1, root.selected + 1)
                e.accepted = true
              } else if (e.key === Qt.Key_Up) {
                root.keyboardGeneration++
                root.keyboardSelecting = true
                root.selected = Math.max(0, root.selected - 1)
                e.accepted = true
              } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                root.launch(0)
                e.accepted = true
              } else if (e.key === Qt.Key_Escape) {
                root.isOpen = false
                e.accepted = true
              } else if (e.key === Qt.Key_Tab) {
                root.keyboardGeneration++
                root.keyboardSelecting = true
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

            WheelHandler {
              onWheel: (event) => {
                const maxY = Math.max(0, list.contentHeight - list.height)
                list.contentY = Math.max(0, Math.min(maxY, list.contentY - event.angleDelta.y / 2))
                event.accepted = true
              }
            }

            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Item {
              required property var modelData
              required property int index
              width: list.width
              height: Metrics.rowHeight

              property bool isFocused: root.keyboardSelecting ? index === root.selected : hoverArea.containsMouse || index === root.selected
              property int seenKeyboardGeneration: -1
              property real lastMouseX: 0
              property real lastMouseY: 0

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

                Item {
                  Layout.preferredWidth: 24
                  Layout.preferredHeight: 24
                  property url iconSource: Quickshell.iconPath(modelData.icon, "")

                  IconImage {
                    anchors.fill: parent
                    visible: parent.iconSource.toString().length > 0
                    source: parent.iconSource
                    smooth: true
                  }

                  Rectangle {
                    anchors.fill: parent
                    visible: !parent.iconSource.toString().length
                    color: Colors.overlay
                    radius: Colors.radiusSm
                    border.width: 1
                    border.color: Colors.border

                    Rectangle {
                      anchors.centerIn: parent
                      width: 12
                      height: 10
                      color: "transparent"
                      radius: Colors.marginXs
                      border.width: 1
                      border.color: Colors.textMuted

                      Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 2
                        color: Colors.textMuted
                        radius: parent.radius
                      }
                    }
                  }
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
                }
              }

              MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                  if (root.keyboardSelecting) {
                    if (seenKeyboardGeneration !== root.keyboardGeneration) {
                      seenKeyboardGeneration = root.keyboardGeneration
                      lastMouseX = mouseX
                      lastMouseY = mouseY
                      return
                    }
                  }
                  root.keyboardSelecting = false
                  root.selected = parent.index
                }
                onPositionChanged: {
                  if (!root.keyboardSelecting) return
                  if (seenKeyboardGeneration !== root.keyboardGeneration) {
                    seenKeyboardGeneration = root.keyboardGeneration
                    lastMouseX = mouseX
                    lastMouseY = mouseY
                    return
                  }
                  if (Math.abs(mouseX - lastMouseX) > 1 || Math.abs(mouseY - lastMouseY) > 1) {
                    root.keyboardSelecting = false
                    root.selected = parent.index
                  }
                  lastMouseX = mouseX
                  lastMouseY = mouseY
                }
                onClicked: { root.keyboardSelecting = false; root.launch(parent.index) }
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
