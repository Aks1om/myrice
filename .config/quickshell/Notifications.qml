import QtQuick
import QtQuick.Layouts
import "theme"

Item {
  id: root
  implicitWidth: layout.implicitWidth
  implicitHeight: layout.implicitHeight

  property var center
  readonly property int count: center ? center.count : 0

  RowLayout {
    id: layout
    anchors.fill: parent
    spacing: Colors.spacingSm

    Icon {
      Layout.alignment: Qt.AlignVCenter
      name: root.count > 0 ? "bell-ringing" : "bell"
      color: root.count > 0 ? Colors.textPrim : Colors.textMuted
      size: 16
    }
    Text {
      Layout.alignment: Qt.AlignVCenter
      visible: root.count > 0
      text: root.count
      color: Colors.textPrim
      font.family: Colors.fontPrimary
      font.pixelSize: Colors.fontSizeSmall
      font.weight: Font.Medium
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.PointingHandCursor
    onClicked: root.center?.toggle()
  }
}
