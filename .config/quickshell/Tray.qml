import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "theme"

RowLayout {
    id: root

    property int maxVisibleItems: 5
    property int page: 0
    readonly property var trayItems: {
        const exclude = ["nm-applet", "blueman", "network", "bluetooth"];
        const items = SystemTray.items.values || [];
        return items.filter((item) => {
            const id = (item.id || "").toLowerCase();
            const title = (item.title || "").toLowerCase();
            return !exclude.some((entry) => {
                return id.includes(entry) || title.includes(entry);
            });
        });
    }
    readonly property int pageCount: Math.max(1, Math.ceil(trayItems.length / maxVisibleItems))
    readonly property var visibleItems: trayItems.slice(page * maxVisibleItems, (page + 1) * maxVisibleItems)

    spacing: Colors.spacingXs

    TrayContextMenu {
        id: contextMenu
    }

    Repeater {
        model: root.visibleItems

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
                    if (m.button === Qt.LeftButton) {
                        if (modelData.onlyMenu && modelData.hasMenu)
                            contextMenu.openFor(modelData, parent);
                        else
                            modelData.activate();
                    } else {
                        contextMenu.toggle(modelData, parent);
                    }
                }
            }

        }

    }

    TrayToggle {
        visible: root.pageCount > 1
        open: root.page > 0
        onClicked: root.page = (root.page + 1) % root.pageCount
    }

}
