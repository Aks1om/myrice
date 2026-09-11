import QtQuick
import QtQuick.Layouts
import "theme"

Rectangle {
  id: root
  default property alias content: layout.data
  property real hPadding: Metrics.px(10)

  color: Colors.bgDeep
  radius: Metrics.px(8)
  border.color: Qt.rgba(1, 1, 1, 0.22)
  border.width: 1

  implicitHeight: Metrics.px(30)
  implicitWidth: layout.implicitWidth + hPadding * 2

  RowLayout {
    id: layout
    anchors.fill: parent
    anchors.leftMargin: root.hPadding
    anchors.rightMargin: root.hPadding
    spacing: Metrics.px(6)
  }
}
