import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "theme"

Item {
  id: root
  property var screen
  readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
  readonly property int activeId: monitor?.activeWorkspace?.id ?? 1

  implicitWidth: row.implicitWidth
  implicitHeight: Metrics.iconSize

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: Colors.spacingXs

    Repeater {
      model: 10
      Item {
        id: cell
        readonly property int wsId: index + 1
        readonly property var ws: Hyprland.workspaces.values.find(w => w.id === wsId)
        readonly property bool active: root.activeId === wsId
        readonly property bool occupied: ws !== undefined

        Layout.preferredWidth: dot.width
        Layout.preferredHeight: Metrics.iconSize

        Rectangle {
          id: dot
          anchors.verticalCenter: parent.verticalCenter
          width: cell.active ? Metrics.iconSize + Colors.spacingXs / 2 : Colors.spacingSm
          height: Colors.spacingSm
          radius: height / 2
          color: cell.active ? "#ffffff"
               : cell.occupied ? Qt.rgba(1, 1, 1, 0.45)
               : Qt.rgba(1, 1, 1, 0.18)

          Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
          Behavior on color { ColorAnimation { duration: 180 } }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: Hyprland.dispatch(`workspace ${cell.wsId}`)
        }
      }
    }
  }
}
