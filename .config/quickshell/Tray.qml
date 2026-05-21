import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "theme"

RowLayout {
  id: root
  spacing: 8

  Repeater {
    model: SystemTray.items

    delegate: Item {
      required property SystemTrayItem modelData
      Layout.preferredWidth: 18
      Layout.preferredHeight: 18

      IconImage {
        anchors.fill: parent
        source: modelData.icon
        smooth: true
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (m) => {
          if (m.button === Qt.LeftButton)
            modelData.activate();
          else if (modelData.hasMenu)
            modelData.display(parent, 0, parent.height);
        }
      }

    }
  }
}
