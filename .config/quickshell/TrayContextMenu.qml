import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.DBusMenu
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "theme"
import "ui" as Ui

Item {
    id: root

    property Item panelAnchorItem
    property SystemTrayItem trayItem
    property SystemTrayItem pendingTrayItem
    property Item pendingPanelAnchorItem
    property var pendingMenu: null
    property var pendingInitialChildren: null
    property bool preparingPendingMenu: false
    property bool open: false
    property var menuStack: []
    readonly property var currentMenu: menuStack.length > 0 ? menuStack[menuStack.length - 1] : null
    property var activeOpener: firstOpener
    property var stagingOpener: secondOpener
    property var activeMenu: null

    function toggle(item, panelAnchor) {
        if (open && trayItem === item) {
            close();
            return ;
        }
        if (pendingTrayItem === item) {
            clearPendingMenu();
            return ;
        }
        openFor(item, panelAnchor);
    }

    function openFor(item, panelAnchor) {
        pendingTrayItem = item;
        pendingPanelAnchorItem = panelAnchor;
        preloadPendingMenu();
    }

    function preloadPendingMenu() {
        if (!pendingTrayItem || !pendingTrayItem.hasMenu || !pendingTrayItem.menu)
            return ;

        if (pendingMenu === pendingTrayItem.menu)
            return ;

        pendingMenu = pendingTrayItem.menu;
        pendingInitialChildren = stagingOpener.children;
        preparingPendingMenu = true;
        stagingOpener.menu = pendingMenu;
        preparingPendingMenu = false;
        commitPendingMenu();
    }

    function commitPendingMenu() {
        if (preparingPendingMenu || !pendingTrayItem || !pendingMenu || stagingOpener.menu !== pendingMenu || stagingOpener.children === pendingInitialChildren)
            return ;

        const nextActiveOpener = stagingOpener;
        stagingOpener = activeOpener;
        activeOpener = nextActiveOpener;
        trayItem = pendingTrayItem;
        panelAnchorItem = pendingPanelAnchorItem;
        activeMenu = pendingMenu;
        menuStack = [activeMenu];
        open = true;
        clearPendingMenu();
    }

    function clearPendingMenu() {
        pendingTrayItem = null;
        pendingPanelAnchorItem = null;
        pendingMenu = null;
        pendingInitialChildren = null;
        preparingPendingMenu = false;
        stagingOpener.menu = null;
    }

    function closeSubmenus() {
        menuStack = [];
    }

    function close() {
        open = false;
        closeSubmenus();
        clearPendingMenu();
    }

    function openSubmenu(item) {
        if (!item.hasChildren)
            return ;

        menuStack = menuStack.concat([item]);
    }

    function closeSubmenu() {
        if (menuStack.length <= 1) {
            close();
            return ;
        }
        menuStack = menuStack.slice(0, -1);
    }

    Connections {
        function onReady() {
            root.preloadPendingMenu();
        }

        function onHasMenuChanged() {
            root.preloadPendingMenu();
        }

        target: root.pendingTrayItem
    }

    Connections {
        function onChildrenChanged() {
            root.commitPendingMenu();
        }

        target: root.stagingOpener
    }

    QsMenuOpener {
        id: firstOpener
    }

    QsMenuOpener {
        id: secondOpener
    }

    Loader {
        active: root.open

        sourceComponent: PopupWindow {
            visible: true
            color: "transparent"
            grabFocus: true
            implicitWidth: Metrics.trayMenuWidth
            implicitHeight: menu.implicitHeight + Colors.marginLg * 2
            onVisibleChanged: {
                if (!visible)
                    root.close();

            }

            anchor {
                window: root.panelAnchorItem.QsWindow.window
                item: root.panelAnchorItem
                edges: Edges.Bottom
                gravity: Edges.Bottom
                margins.bottom: -Colors.marginSm
                adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipY
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.closeSubmenu()
            }

            Ui.PanelSurface {
                anchors.fill: parent
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                    }
                }

                Ui.PanelColumn {
                    id: menu

                    spacing: Colors.spacingSm

                    anchors {
                        fill: parent
                        margins: Colors.marginLg
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: Colors.spacingXs
                        spacing: Colors.spacingMd

                        IconImage {
                            Layout.preferredWidth: Metrics.trayHeaderIconSize
                            Layout.preferredHeight: Metrics.trayHeaderIconSize
                            source: root.trayItem.icon
                            smooth: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.currentMenu && root.currentMenu !== root.trayItem.menu ? root.currentMenu.text : (root.trayItem ? root.trayItem.tooltipTitle || root.trayItem.title || root.trayItem.id : "")
                            color: Colors.textPrim
                            font.family: Colors.fontSecondary
                            font.pixelSize: Colors.fontSizeBase
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: root.menuStack.length > 1
                            text: "‹"
                            color: Colors.textSecondary
                            font.family: Colors.fontSecondary
                            font.pixelSize: Colors.fontSizeLarge

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.closeSubmenu()
                            }

                        }

                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Metrics.dividerHeight
                        color: Colors.border
                    }

                    Repeater {
                        id: menuItems

                        model: root.currentMenu === root.activeMenu ? root.activeOpener.children : submenuOpener.children

                        delegate: Item {
                            required property DBusMenuItem modelData

                            Layout.fillWidth: true
                            Layout.preferredHeight: modelData.isSeparator ? Metrics.dividerHeight : Metrics.compactRowHeight

                            Rectangle {
                                anchors.fill: parent
                                color: actionArea.containsMouse && modelData.enabled && !modelData.isSeparator ? Colors.surface : "transparent"
                                radius: Colors.radiusSm
                            }

                            Rectangle {
                                visible: modelData.isSeparator
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: Metrics.dividerHeight
                                color: Colors.overlay
                            }

                            RowLayout {
                                visible: !modelData.isSeparator
                                anchors.fill: parent
                                anchors.leftMargin: Colors.spacingMd
                                anchors.rightMargin: Colors.spacingMd
                                spacing: Colors.spacingSm

                                IconImage {
                                    Layout.preferredWidth: Metrics.iconSize
                                    Layout.preferredHeight: Metrics.iconSize
                                    visible: modelData.icon.length > 0
                                    source: modelData.icon
                                    smooth: true
                                }

                                Text {
                                    Layout.preferredWidth: modelData.buttonType === QsMenuButtonType.None ? 0 : 14
                                    text: modelData.buttonType === QsMenuButtonType.RadioButton ? (modelData.checkState === Qt.Checked ? "●" : "○") : (modelData.buttonType === QsMenuButtonType.CheckBox ? (modelData.checkState === Qt.Checked ? "✓" : "") : "")
                                    color: modelData.enabled ? Colors.textPrim : Colors.textMuted
                                    font.family: Colors.fontSecondary
                                    font.pixelSize: Colors.fontSizeBase
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.text
                                    color: modelData.enabled ? Colors.textSecondary : Colors.textMuted
                                    font.family: Colors.fontSecondary
                                    font.pixelSize: Colors.fontSizeBase
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: modelData.hasChildren
                                    text: "›"
                                    color: modelData.enabled ? Colors.textSecondary : Colors.textMuted
                                    font.family: Colors.fontSecondary
                                    font.pixelSize: Colors.fontSizeLarge
                                }

                            }

                            MouseArea {
                                id: actionArea

                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: modelData.enabled && !modelData.isSeparator
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (modelData.hasChildren) {
                                        root.openSubmenu(modelData);
                                    } else {
                                        modelData.triggered();
                                        root.close();
                                    }
                                }
                            }

                        }

                    }

                }

            }

        }

    }

    QsMenuOpener {
        id: submenuOpener

        menu: root.currentMenu && root.currentMenu !== root.activeMenu ? root.currentMenu : null
    }

}
