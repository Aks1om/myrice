import QtQuick
import QtQuick.Layouts
import "theme"

Rectangle {
  id: root
  property var screen
  radius: 0
  color: "#000000"
  border.width: 0

  Clock { id: clock }

  Rectangle {
    id: centerSep
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    width: 1
    height: 14
    color: Qt.rgba(1, 1, 1, 0.18)
    z: 2
  }

  Text {
    anchors.right: centerSep.left
    anchors.rightMargin: Colors.spacingLg
    anchors.verticalCenter: parent.verticalCenter
    text: clock.date
    color: Colors.textPrim
    font.family: Colors.fontPrimary
    font.pixelSize: Colors.fontSizeMedium
    font.weight: Font.Medium
    z: 2
  }

  Text {
    anchors.left: centerSep.right
    anchors.leftMargin: Colors.spacingLg
    anchors.verticalCenter: parent.verticalCenter
    text: clock.time
    color: Colors.textPrim
    font.family: Colors.fontPrimary
    font.pixelSize: Colors.fontSizeMedium
    font.weight: Font.Medium
    z: 2
  }

  RowLayout {
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Colors.spacingXl
    spacing: Colors.spacingXl

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

  RowLayout {
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.rightMargin: Colors.spacingXl
    spacing: Colors.spacingXl

    TrayToggle {}
    Network {}
    Bluetooth {}
    Notifications {}
    PowerMode {}
    Volume {}
    Language {}
    Battery {}
  }
}
