import QtCore
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
    property bool frozen: false
    property string stage: "menu"
    property int selected: 0
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"
    readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"
    readonly property string frozenFramePath: cacheHome + "/frozen-screenshot/frame.png"
    readonly property var items: [{
        "label": "Area",
        "hint": "Выделить область",
        "mode": "area",
        "icon": "selection"
    }, {
        "label": "Window",
        "hint": "Текущее окно",
        "mode": "window",
        "icon": "app-window"
    }, {
        "label": "Screen",
        "hint": "Весь экран",
        "mode": "output",
        "icon": "monitor"
    }]

    function shoot(mode) {
        if (root.frozen) {
            if (mode === "area") {
                root.stage = "area";
                return ;
            }
            root.isOpen = false;
            shotProc.command = ["bash", root.configHome + "/hypr/scripts/frozen-screenshot.sh", mode];
            shotProc.running = true;
            return ;
        }
        root.isOpen = false;
        shotProc.command = ["bash", root.configHome + "/hypr/scripts/screenshot.sh", mode];
        shotProc.running = true;
    }

    function cropArea(x, y, width, height, imageWidth, imageHeight, displayWidth, displayHeight) {
        if (width < 4 || height < 4) {
            root.closeWithError("Select an area at least 4 pixels wide and high.");
            return ;
        }
        if (imageWidth <= 0 || imageHeight <= 0 || displayWidth <= 0 || displayHeight <= 0) {
            root.closeWithError("The frozen frame could not be loaded. Try again.");
            return ;
        }
        const cropX = Math.max(0, Math.round(x / displayWidth * imageWidth));
        const cropY = Math.max(0, Math.round(y / displayHeight * imageHeight));
        const cropWidth = Math.min(imageWidth - cropX, Math.round(width / displayWidth * imageWidth));
        const cropHeight = Math.min(imageHeight - cropY, Math.round(height / displayHeight * imageHeight));
        if (cropWidth <= 0 || cropHeight <= 0) {
            root.closeWithError("The selected area is outside the frozen frame. Try again.");
            return ;
        }
        root.isOpen = false;
        shotProc.exec(["bash", root.configHome + "/hypr/scripts/frozen-screenshot.sh", "area", String(cropX), String(cropY), String(cropWidth), String(cropHeight)]);
    }

    function closeWithError(message) {
        root.isOpen = false;
        errorProc.command = ["notify-send", "-u", "critical", "-a", "Screenshot", "Screenshot failed", message];
        errorProc.running = true;
    }

    IpcHandler {
        function open() {
            root.frozen = false;
            root.stage = "menu";
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

        target: "screenshot"
    }

    IpcHandler {
        function open() {
            root.frozen = true;
            root.stage = "menu";
            root.selected = 0;
            root.isOpen = true;
        }

        target: "frozenScreenshot"
    }

    Process {
        id: shotProc

        property string errorOutput: ""

        onStarted: errorOutput = ""
        stderr: StdioCollector {
            onStreamFinished: shotProc.errorOutput = text.trim()
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                return ;

            const detail = shotProc.errorOutput || "The screenshot command exited with code " + exitCode + ".";
            console.warn("Screenshot command failed:", exitCode, exitStatus, detail);
            root.closeWithError(detail);
        }
    }

    Process {
        id: errorProc

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn("Failed to send screenshot error notification:", exitCode, exitStatus);
        }
    }

    Loader {
        id: loader

        active: root.isOpen
        asynchronous: true

        sourceComponent: Ui.ModalOverlay {
            open: root.isOpen
            dismissOnClick: root.stage === "menu"
            onDismissed: root.isOpen = false
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            Image {
                id: frozenFrame

                anchors.fill: parent
                visible: root.frozen
                source: Qt.resolvedUrl(root.frozenFramePath)
                fillMode: Image.Stretch
                cache: false
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.stage === "area" ? root.stage = "menu" : root.isOpen = false
                Keys.onReturnPressed: root.shoot(root.items[root.selected].mode)
                Keys.onUpPressed: root.selected = Math.max(0, root.selected - 1)
                Keys.onDownPressed: root.selected = Math.min(root.items.length - 1, root.selected + 1)
                Keys.onTabPressed: root.selected = (root.selected + 1) % root.items.length
            }

            Ui.PanelSurface {
                visible: root.stage === "menu"
                anchors.centerIn: parent
                width: Metrics.menuWidth
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
                        title: "Screenshot"
                        subtitle: "Что сохранить"
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
                            hint: modelData.hint
                            iconName: modelData.icon
                            selected: index === root.selected
                            onHovered: root.selected = index
                            onActivated: root.shoot(modelData.mode)
                        }

                    }

                }

            }

            Item {
                id: areaSelector

                property real startX: 0
                property real startY: 0
                property real endX: 0
                property real endY: 0
                property real selectionX: Math.min(startX, endX)
                property real selectionY: Math.min(startY, endY)
                property real selectionWidth: Math.abs(endX - startX)
                property real selectionHeight: Math.abs(endY - startY)

                anchors.fill: parent
                visible: root.stage === "area"

                Rectangle {
                    x: 0
                    y: 0
                    width: parent.width
                    height: areaSelector.selectionY
                    color: "#99000000"
                }

                Rectangle {
                    x: 0
                    y: areaSelector.selectionY + areaSelector.selectionHeight
                    width: parent.width
                    height: parent.height - y
                    color: "#99000000"
                }

                Rectangle {
                    x: 0
                    y: areaSelector.selectionY
                    width: areaSelector.selectionX
                    height: areaSelector.selectionHeight
                    color: "#99000000"
                }

                Rectangle {
                    x: areaSelector.selectionX + areaSelector.selectionWidth
                    y: areaSelector.selectionY
                    width: parent.width - x
                    height: areaSelector.selectionHeight
                    color: "#99000000"
                }

                Rectangle {
                    x: areaSelector.selectionX
                    y: areaSelector.selectionY
                    width: areaSelector.selectionWidth
                    height: areaSelector.selectionHeight
                    color: "transparent"
                    border.width: 2
                    border.color: Colors.textPrim
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.CrossCursor
                    onPressed: (event) => {
                        areaSelector.startX = event.x;
                        areaSelector.startY = event.y;
                        areaSelector.endX = event.x;
                        areaSelector.endY = event.y;
                    }
                    onPositionChanged: (event) => {
                        if (pressed) {
                            areaSelector.endX = event.x;
                            areaSelector.endY = event.y;
                        }
                    }
                    onReleased: (event) => {
                        areaSelector.endX = event.x;
                        areaSelector.endY = event.y;
                        root.cropArea(areaSelector.selectionX, areaSelector.selectionY, areaSelector.selectionWidth, areaSelector.selectionHeight, frozenFrame.sourceSize.width, frozenFrame.sourceSize.height, areaSelector.width, areaSelector.height);
                    }
                }

            }

        }

    }

}
