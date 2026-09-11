import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.UPower
import "theme"

Item {
  id: root
  implicitWidth: layout.implicitWidth
  implicitHeight: Metrics.iconSize
  visible: dev?.isLaptopBattery ?? false

  readonly property var dev: UPower.displayDevice
  readonly property real pct: (dev?.percentage ?? 0) * 100
  readonly property bool charging: dev?.state === UPowerDeviceState.Charging
                                || dev?.state === UPowerDeviceState.PendingCharge
  readonly property bool low: !charging && pct < 15

  Process { id: taskManager; command: ["ghostty", "-e", "btop"] }

  RowLayout {
    id: layout
    anchors.centerIn: parent
    spacing: Colors.spacingSm

    Item {
      Layout.alignment: Qt.AlignVCenter
      implicitWidth: 20
      implicitHeight: 10

      readonly property color mainColor: root.low ? "#ff8aa2" : Colors.textPrim

      Rectangle {
        id: body
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 2
        height: parent.height
        radius: 2
        color: "transparent"
        border.color: parent.mainColor
        border.width: 1

        Rectangle {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.margins: 2
          width: Math.max(0, (parent.width - 4) * (root.pct / 100))
          radius: 1
          color: parent.parent.mainColor
          Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }

        Icon {
          anchors.centerIn: parent
          visible: root.charging
          name: "lightning"
          variant: "fill"
          color: root.pct >= 50 ? "#000000" : parent.parent.mainColor
          size: 8
        }
      }

      Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: parent.height * 0.5
        radius: 1
        color: parent.mainColor
      }
    }
    Text {
      Layout.alignment: Qt.AlignVCenter
      text: Math.round(root.pct) + "%"
      color: Colors.textPrim
      font.family: Colors.fontPrimary
      font.pixelSize: Colors.fontSizeBase
      font.weight: Font.Medium
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: taskManager.running = true
  }
}
