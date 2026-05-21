import QtQuick
import QtQuick.Layouts

Rectangle {
  id: root
  property var screen
  radius: 0
  color: "#000000"
  border.width: 0

  Clock { id: clock }

  // Center separator — pinned to the monitor's exact horizontal center
  Rectangle {
    id: centerSep
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    width: 1
    height: 14
    color: Qt.rgba(1, 1, 1, 0.18)
    z: 2
  }

  // Date — sits to the LEFT of the separator
  Text {
    anchors.right: centerSep.left
    anchors.rightMargin: 10
    anchors.verticalCenter: parent.verticalCenter
    text: clock.date
    color: "#ffffff"
    font.family: "Inter"
    font.pixelSize: 13
    font.weight: Font.Medium
    z: 2
  }

  // Time — sits to the RIGHT of the separator
  Text {
    anchors.left: centerSep.right
    anchors.leftMargin: 10
    anchors.verticalCenter: parent.verticalCenter
    text: clock.time
    color: "#ffffff"
    font.family: "Inter"
    font.pixelSize: 13
    font.weight: Font.Medium
    z: 2
  }

  // Left section
  RowLayout {
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: 14
    spacing: 14

    Workspaces { screen: root.screen }
    SpecialWorkspace { screen: root.screen }
    Rectangle {
      visible: title.text.length > 0
      Layout.preferredWidth: 1
      Layout.preferredHeight: 14
      color: Qt.rgba(1, 1, 1, 0.12)
    }
    WindowTitle {
      id: title
      screen: root.screen
      visible: text.length > 0
      Layout.maximumWidth: 280
    }
    Rectangle {
      visible: mediaLeft.visible
      Layout.preferredWidth: 1
      Layout.preferredHeight: 14
      color: Qt.rgba(1, 1, 1, 0.12)
    }
    MediaPlayer { id: mediaLeft }
  }

  // Right section
  RowLayout {
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.rightMargin: 14
    spacing: 14

    Network {}
    Bluetooth {}
    Notifications {}
    PowerMode {}
    Volume {}
    Language {}
    Battery {}
  }
}
