import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "theme"

Item {
  id: root
  implicitWidth: layout.implicitWidth + Metrics.px(12)
  implicitHeight: Metrics.px(28)

  property var center
  readonly property int count: center ? center.count : 0
  readonly property bool doNotDisturb: center ? center.doNotDisturb : false

  ToolTip.visible: mouse.containsMouse
  ToolTip.delay: 600
  ToolTip.text: root.doNotDisturb
    ? "Не беспокоить · ПКМ: включить уведомления"
    : "Уведомления · ПКМ: не беспокоить"

  RowLayout {
    id: layout
    anchors.centerIn: parent
    spacing: Colors.spacingSm

    Icon {
      Layout.alignment: Qt.AlignVCenter
      name: root.doNotDisturb ? "bell-slash" : root.count > 0 ? "bell-ringing" : "bell"
      color: root.doNotDisturb ? Colors.accent : root.count > 0 ? Colors.textPrim : Colors.textMuted
      size: Metrics.iconSize
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
    id: mouse
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: event => {
      if (event.button === Qt.RightButton)
        root.center?.toggleDoNotDisturb()
      else
        root.center?.toggle()
    }
  }
}
