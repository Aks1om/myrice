import QtQuick
import QtQuick.Controls
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
    property int scalePct: 100
    property int scaleIndex: 1
    property int selectedPct: 100
    property var validScales: [80, 100, 107, 120, 133, 150, 160, 200, 213, 240]
    readonly property string configHome: Quickshell.env("HOME") + "/.config"

    function indexForScale(pct) {
        let bestIndex = 0;
        let bestDistance = Math.abs(root.validScales[0] - pct);
        for (let i = 1; i < root.validScales.length; i++) {
            const distance = Math.abs(root.validScales[i] - pct);
            if (distance < bestDistance) {
                bestDistance = distance;
                bestIndex = i;
            }
        }
        return bestIndex;
    }

    function apply(pct) {
        if (applyScale.running)
            return;

        const v = (pct / 100).toFixed(4);
        applyScale.command = ["bash", root.configHome + "/hypr/scripts/scale.sh", "set", v];
        applyScale.running = true;
    }

    IpcHandler {
        function open() {
            listScales.running = true;
            readScale.running = true;
            root.isOpen = true;
        }

        function close() {
            root.isOpen = false;
        }

        function set(percent: int): void {
            root.apply(percent);
        }

        function toggle() {
            if (!root.isOpen) {
                listScales.running = true;
                readScale.running = true;
            }

            root.isOpen = !root.isOpen;
        }

        target: "scale"
    }

    Process {
        id: readScale

        command: ["bash", "-c", "hyprctl -j monitors | jq -r '.[] | select(.focused==true) | .scale' | awk '{printf \"%d\", $1*100+0.5}'"]

        stdout: StdioCollector {
            onStreamFinished: {
                const value = parseInt(text.trim(), 10);
                if (!isNaN(value)) {
                    root.scalePct = value;
                    root.scaleIndex = root.indexForScale(value);
                    root.selectedPct = root.validScales[root.scaleIndex];
                }
            }
        }
    }

    Process {
        id: listScales

        command: ["bash", root.configHome + "/hypr/scripts/scale.sh", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                const values = text.trim().split(/\s+/).map(Number).filter(value => !isNaN(value));
                if (values.length > 0) {
                    root.validScales = values;
                    root.scaleIndex = root.indexForScale(root.scalePct);
                    root.selectedPct = root.validScales[root.scaleIndex];
                }
            }
        }
    }

    Process {
        id: applyScale
        onExited: (exitCode, exitStatus) => readScale.running = true
    }

    Loader {
        id: loader

        active: root.isOpen
        asynchronous: true

        sourceComponent: Ui.ModalOverlay {
            id: panel

            open: root.isOpen
            onDismissed: root.isOpen = false
            color: "#00000080"

            Item {
                id: keyHandler

                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.isOpen = false
                Keys.onReturnPressed: root.isOpen = false
            }

            Ui.PanelSurface {
                anchors.centerIn: parent
                width: Metrics.scalePanelWidth
                implicitHeight: col.implicitHeight + Metrics.menuPadding * 2 + Metrics.px(8)

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                    }
                }

                ColumnLayout {
                    id: col

                    spacing: Colors.spacingXl

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: Metrics.scalePanelPadding
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            text: "UI Scale"
                            color: Colors.textPrim
                            font.family: Colors.fontPrimary
                            font.pixelSize: Colors.fontSizeBase
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: root.selectedPct + "%"
                            color: Colors.textPrim
                            font.family: Colors.fontMono
                            font.pixelSize: Colors.fontSizeBase
                            font.weight: Font.DemiBold
                        }

                    }

                    Slider {
                        id: slider

                        Layout.fillWidth: true
                        Layout.preferredHeight: Metrics.px(24)
                        enabled: !applyScale.running
                        from: 0
                        to: Math.max(0, root.validScales.length - 1)
                        stepSize: 1
                        snapMode: Slider.SnapAlways
                        value: root.scaleIndex
                        onMoved: {
                            root.scaleIndex = Math.round(value);
                            root.selectedPct = root.validScales[root.scaleIndex];
                        }
                        onPressedChanged: {
                            if (!pressed)
                                root.apply(root.selectedPct);
                        }

                        background: Rectangle {
                            x: slider.leftPadding
                            y: slider.topPadding + slider.availableHeight / 2 - height / 2
                            width: slider.availableWidth
                            height: Metrics.px(4)
                            radius: Metrics.px(2)
                            color: Colors.overlay

                            Rectangle {
                                width: slider.visualPosition * parent.width
                                height: parent.height
                                color: Colors.textPrim
                                radius: Metrics.px(2)
                            }

                        }

                        handle: Rectangle {
                            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                            y: slider.topPadding + slider.availableHeight / 2 - height / 2
                            width: Metrics.px(16)
                            height: Metrics.px(16)
                            radius: Colors.radiusMd
                            color: Colors.textPrim
                        }

                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: applyScale.running ? "Applying..." : "Only pixel-perfect scales for this monitor"
                        color: Qt.rgba(1, 1, 1, 0.5)
                        font.family: Colors.fontPrimary
                        font.pixelSize: Colors.fontSizeTiny
                    }

                }

            }

        }

    }

}
