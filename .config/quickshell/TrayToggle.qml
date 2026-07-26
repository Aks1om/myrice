import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "theme"

Item {
  id: root
  implicitWidth: layout.implicitWidth
  implicitHeight: layout.implicitHeight

  readonly property var filteredItems: {
    const exclude = ["nm-applet", "blueman", "network", "bluetooth"];
    const items = SystemTray.items.values || [];
    return items.filter(item => {
      const id = (item.id || "").toLowerCase();
      const title = (item.title || "").toLowerCase();
      return !exclude.some(e => id.includes(e) || title.includes(e));
    });
  }

  property bool open: false
  visible: true

  RowLayout {
    id: layout
    anchors.fill: parent
    spacing: Colors.spacingXs

    Icon {
      Layout.alignment: Qt.AlignVCenter
      name: root.open ? "caret-up" : "caret-down"
      color: Colors.textPrim
      size: 16
    }
  }

  MouseArea {
    id: clickArea
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.open = !root.open
  }

  Loader {
    active: root.open
    sourceComponent: PopupWindow {
      id: popup
      visible: true
      color: "transparent"
      grabFocus: true

      readonly property int pad: 16
      implicitWidth: trayRow.visible ? trayRow.implicitWidth + pad * 2 : 100
      implicitHeight: trayRow.visible ? 22 + pad * 2 : 36

      anchor {
        window: clickArea.QsWindow.window
        item: clickArea
        edges: Edges.Bottom
        gravity: Edges.Bottom
        margins.bottom: -10
      }

      onVisibleChanged: {
        if (!visible) root.open = false
      }

      Rectangle {
        anchors.fill: parent
        anchors.margins: Colors.marginSm
        color: Colors.bgBase
        radius: Colors.radiusLg
        border.color: Colors.border
        border.width: 1

        MouseArea { anchors.fill: parent; onClicked: {} }

        Text {
          anchors.centerIn: parent
          visible: root.filteredItems.length === 0
          text: "Нет приложений"
          color: Colors.textMuted
          font.family: Colors.fontSecondary
          font.pixelSize: Colors.fontSizeSmall
        }

        Row {
          id: trayRow
          anchors.centerIn: parent
          spacing: Colors.spacingSm
          visible: root.filteredItems.length > 0

          Repeater {
            model: root.filteredItems
            delegate: Item {
              required property var modelData
              width: 22
              height: 22

              Rectangle {
                anchors.fill: parent
                radius: Colors.radiusSm
                color: itemArea.containsMouse ? Colors.surface : "transparent"
              }

              IconImage {
                anchors.fill: parent
                anchors.margins: Colors.marginXs
                source: modelData.icon
                smooth: true
              }

              MouseArea {
                id: itemArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (m) => {
                  if (m.button === Qt.LeftButton)
                    modelData.activate();
                  else if (modelData.hasMenu)
                    modelData.display(popup, 0, popup.height);
                }
              }
            }
          }
        }
      }
    }
  }
}
