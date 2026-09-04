import "../theme" as Theme
import QtQuick
import Quickshell
import Quickshell.Hyprland

PopupWindow {
    id: root
    property var anchorItem
    property bool open: false
    default property alias content: contentRoot.data

    color: "transparent"
    visible: true
    implicitWidth: Theme.Metrics.panelWidth
    implicitHeight: contentRoot.childrenRect.height + Theme.Metrics.popupInset * 2

    anchor {
        window: anchorItem ? anchorItem.QsWindow.window : null
        item: anchorItem
        edges: Edges.Bottom
        gravity: Edges.Bottom
        margins.bottom: Theme.Metrics.popupAnchorOffset
    }

    HyprlandFocusGrab {
        active: root.open
        windows: [root]
        onCleared: root.open = false
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.open = false
    }

    Item {
        id: contentRoot

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.Metrics.popupInset
    }

}
