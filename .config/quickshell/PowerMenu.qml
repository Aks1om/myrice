import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "theme"
import "ui" as Ui

Scope {
    id: root

    property bool isOpen: false
    property int selected: 0
    readonly property var items: [{
        "label": "Lock",
        "action": "lock",
        "icon": "lock"
    }, {
        "label": "Logout",
        "action": "logout",
        "icon": "sign-out"
    }, {
        "label": "Reboot",
        "action": "reboot",
        "icon": "arrow-clockwise"
    }, {
        "label": "Shutdown",
        "action": "shutdown",
        "icon": "power"
    }]

    function runCmd(parts) {
        root.isOpen = false;
        cmdProc.command = parts;
        cmdProc.running = true;
    }

    function activate(idx) {
        const it = items[idx];
        switch (it.action) {
        case "lock":
            runCmd(["hyprlock"]);
            break;
        case "logout":
            runCmd(["hyprctl", "dispatch", "exit"]);
            break;
        case "reboot":
            runCmd(["systemctl", "reboot"]);
            break;
        case "shutdown":
            runCmd(["systemctl", "poweroff"]);
            break;
        }
    }

    IpcHandler {
        function open() {
            root.selected = 0;
            root.isOpen = true;
        }

        function close() {
            root.isOpen = false;
        }

        function toggle() {
            if (!root.isOpen)
                root.selected = 0;

            root.isOpen = !root.isOpen;
        }

        target: "power"
    }

    Process {
        id: cmdProc
    }

    Loader {
        id: loader

        active: root.isOpen
        asynchronous: true

        sourceComponent: Ui.ModalOverlay {
            open: root.isOpen
            onDismissed: root.isOpen = false

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.isOpen = false
                Keys.onReturnPressed: root.activate(root.selected)
                Keys.onUpPressed: root.selected = Math.max(0, root.selected - 1)
                Keys.onDownPressed: root.selected = Math.min(root.items.length - 1, root.selected + 1)
                Keys.onTabPressed: root.selected = (root.selected + 1) % root.items.length
            }

            Ui.PanelSurface {
                anchors.centerIn: parent
                width: Metrics.powerMenuWidth
                implicitHeight: col.implicitHeight + Metrics.menuPadding * 2

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                    }
                }

                Ui.PanelColumn {
                    id: col

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: Metrics.menuPadding
                    }

                    Ui.SectionTitle {
                        title: "Power"
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        Layout.topMargin: 2
                        Layout.bottomMargin: 2
                    }

                    Ui.Divider {
                    }

                    Repeater {
                        model: root.items

                        delegate: Ui.MenuRow {
                            required property var modelData
                            required property int index

                            label: modelData.label
                            iconName: modelData.icon
                            selected: index === root.selected
                            onHovered: root.selected = index
                            onActivated: root.activate(index)
                        }

                    }

                }

            }

        }

    }

}
