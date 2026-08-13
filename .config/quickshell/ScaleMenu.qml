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
    readonly property var presetSnaps: [80, 100, 125, 150, 175, 200, 225, 250]

    function snapToPreset(v) {
        let best = root.presetSnaps[0];
        let bd = Math.abs(v - best);
        for (const p of root.presetSnaps) {
            const d = Math.abs(v - p);
            if (d < bd) {
                bd = d;
                best = p;
            }
        }
        return best;
    }

    function apply(pct) {
        const v = (pct / 100).toFixed(4);
        applyScale.command = ["bash", "/home/aks1om/.config/hypr/scripts/scale.sh", "set", v];
        applyScale.running = true;
    }

    IpcHandler {
        function open() {
            readScale.running = true;
            root.isOpen = true;
        }

        function close() {
            root.isOpen = false;
        }

        function toggle() {
            if (!root.isOpen)
                readScale.running = true;

            root.isOpen = !root.isOpen;
        }

        target: "scale"
    }

    Process {
        id: readScale

        command: ["bash", "-c", "hyprctl -j monitors | jq -r '.[] | select(.focused==true) | .scale' | awk '{printf \"%d\", $1*100+0.5}'"]

        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim(), 10);
                if (!isNaN(v))
                    root.scalePct = v;

            }
        }

    }

    Process {
        id: applyScale
    }

    Loader {
        id: loader

        active: root.isOpen
        asynchronous: true

        sourceComponent: Ui.ModalOverlay {
            id: panel

            // single keyboard handler — owns focus + tracks modifiers
            property int activeMods: 0
            property string snapMode: {
                if (activeMods & Qt.ControlModifier)
                    return "presets";

                if (activeMods & Qt.ShiftModifier)
                    return "five";

                return "free";
            }

            open: root.isOpen
            onDismissed: root.isOpen = false
            color: "#00000080"

            Item {
                id: keyHandler

                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.isOpen = false
                Keys.onReturnPressed: root.isOpen = false
                Keys.onPressed: (e) => {
                    return panel.activeMods = e.modifiers;
                }
                Keys.onReleased: (e) => {
                    return panel.activeMods = e.modifiers;
                }
            }

            Ui.PanelSurface {
                anchors.centerIn: parent
                width: Metrics.scalePanelWidth
                implicitHeight: col.implicitHeight + Metrics.menuPadding * 2 + 8

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
                            text: root.scalePct + "%"
                            color: Colors.textPrim
                            font.family: Colors.fontMono
                            font.pixelSize: Colors.fontSizeBase
                            font.weight: Font.DemiBold
                        }

                    }

                    Slider {
                        id: slider

                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        from: 80
                        to: 250
                        stepSize: 1
                        value: root.scalePct
                        onMoved: {
                            let v = Math.round(value);
                            if (panel.snapMode === "presets")
                                v = root.snapToPreset(v);
                            else if (panel.snapMode === "five")
                                v = Math.round(v / 5) * 5;
                            value = v;
                            root.scalePct = v;
                        }
                        onPressedChanged: {
                            if (!pressed)
                                root.apply(root.scalePct);

                        }

                        background: Rectangle {
                            x: slider.leftPadding
                            y: slider.topPadding + slider.availableHeight / 2 - height / 2
                            width: slider.availableWidth
                            height: 4
                            radius: 2
                            color: Colors.overlay

                            Rectangle {
                                width: slider.visualPosition * parent.width
                                height: parent.height
                                color: Colors.textPrim
                                radius: 2
                            }

                        }

                        handle: Rectangle {
                            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                            y: slider.topPadding + slider.availableHeight / 2 - height / 2
                            width: 16
                            height: 16
                            radius: Colors.radiusMd
                            color: Colors.textPrim
                        }

                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: panel.snapMode === "presets" ? "Snap: presets" : panel.snapMode === "five" ? "Snap: 5%" : "Hold Shift = snap 5%   ·   Ctrl = snap presets"
                        color: Qt.rgba(1, 1, 1, 0.5)
                        font.family: Colors.fontPrimary
                        font.pixelSize: Colors.fontSizeTiny
                    }

                }

            }

        }

    }

}
