import QtQuick
import QtQuick.Layouts
import "theme"

Rectangle {
  id: root

  property var notification
  signal dismissed()

  implicitHeight: content.implicitHeight + Metrics.panelPadding * 2
  color: Colors.surface
  radius: Colors.radiusMd
  border.width: 1
  border.color: Colors.border

  RowLayout {
    id: content
    anchors {
      fill: parent
      margins: Metrics.panelPadding
    }
    spacing: Colors.spacingMd

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Colors.spacingXs

      Text {
        Layout.fillWidth: true
        text: root.notification?.appName || "Notification"
        color: Colors.textSecondary
        font.family: Colors.fontPrimary
        font.pixelSize: Colors.fontSizeSmall
        elide: Text.ElideRight
      }

      Text {
        Layout.fillWidth: true
        text: root.notification?.summary || ""
        color: Colors.textPrim
        font.family: Colors.fontPrimary
        font.pixelSize: Colors.fontSizeMedium
        font.weight: Font.Medium
        elide: Text.ElideRight
      }

      Text {
        Layout.fillWidth: true
        visible: text.length > 0
        text: root.notification?.body || ""
        color: Colors.textSecondary
        font.family: Colors.fontPrimary
        font.pixelSize: Colors.fontSizeBase
        maximumLineCount: 3
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
      }
    }

    Item {
      Layout.alignment: Qt.AlignTop
      Layout.preferredWidth: Metrics.iconSize
      Layout.preferredHeight: Metrics.iconSize

      Icon {
        anchors.fill: parent
        name: "x"
        color: Colors.textMuted
        size: Metrics.iconSize
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.dismissed()
      }
    }
  }

  onDismissed: root.notification?.dismiss()
}
