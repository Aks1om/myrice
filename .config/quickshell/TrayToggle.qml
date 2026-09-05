import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "theme"
import "ui" as Ui

Item {
    id: root

    property bool open: false
    readonly property var filteredItems: {
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

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    RowLayout {
        id: layout

        anchors.fill: parent
        spacing: Colors.spacingXs

        Icon {
            Layout.alignment: Qt.AlignVCenter
            name: root.open ? "caret-up" : "caret-down"
            color: Colors.textPrim
            size: Metrics.iconSize
        }

    }

    MouseArea {
        id: clickArea

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.open = !root.open
    }

    TrayContextMenu {
        id: contextMenu
    }

    Loader {
        active: root.open

        sourceComponent: PopupWindow {
            id: popup

            readonly property int pad: Metrics.trayPopupPadding

             visible: true
             color: "transparent"
             implicitWidth: trayRow.visible ? trayRow.implicitWidth + pad * 2 : Metrics.trayEmptyWidth
            implicitHeight: trayRow.visible ? Metrics.trayItemSize + pad * 2 : Metrics.trayEmptyHeight
            onVisibleChanged: {
                if (!visible)
                    root.open = false;

            }

             anchor {
                window: clickArea.QsWindow.window
                item: clickArea
                edges: Edges.Bottom
                gravity: Edges.Bottom
                 margins.bottom: -10
             }

             HyprlandFocusGrab {
                 active: root.open
                 windows: contextMenu.popupWindow ? [popup, contextMenu.popupWindow] : [popup]
                 onCleared: {
                     contextMenu.close();
                     root.open = false;
                 }
             }

             Ui.PanelSurface {
                anchors.fill: parent
                anchors.margins: Colors.marginSm
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                    }
                }

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
                            required property SystemTrayItem modelData

                            width: Metrics.trayItemSize
                            height: Metrics.trayItemSize

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
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton) {
                                        if (modelData.onlyMenu && modelData.hasMenu)
                                            contextMenu.openFor(modelData, popup.contentItem);
                                        else
                                            modelData.activate();
                                    } else {
                                        contextMenu.toggle(modelData, popup.contentItem);
                                    }
                                }
                            }

                        }

                    }

                }

            }

        }

    }

}
