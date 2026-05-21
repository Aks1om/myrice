import QtQuick
import QtQuick.Layouts

Rectangle {
  id: root
  default property alias content: layout.data
  property real hPadding: 10

  color: "#0a0a0a"
  radius: 8
  border.color: Qt.rgba(1, 1, 1, 0.22)
  border.width: 1

  implicitHeight: 30
  implicitWidth: layout.implicitWidth + hPadding * 2

  RowLayout {
    id: layout
    anchors.fill: parent
    anchors.leftMargin: root.hPadding
    anchors.rightMargin: root.hPadding
    spacing: 6
  }
}
