import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "theme"
import "ui" as Ui

Loader {
    id: loader

    property var anchorItem
    property var network
    property bool open: false
    property string connecting: ""
    property string lastError: ""
    property string expandedSsid: ""

    active: open
    asynchronous: true
    onOpenChanged: {
        if (!open) {
            expandedSsid = "";
            lastError = "";
        }
    }

    Process {
        id: openEditor

        command: ["nm-connection-editor"]
    }

    sourceComponent: Ui.AnchoredPopup {
        id: pop

        visible: true
        anchorItem: loader.anchorItem
        open: loader.open

        Ui.PanelSurface {
            id: container

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Metrics.popupInset
            implicitHeight: col.implicitHeight + Metrics.panelPadding * 2

            MouseArea {
                anchors.fill: parent
                onClicked: {
                }
            }

            Ui.PanelColumn {
                id: col

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Metrics.panelPadding

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Colors.spacingMd

                    Icon {
                        variant: "regular"
                        name: loader.network.ethernetConnected ? "monitor" : loader.network.wifiEnabled ? "wifi-high" : "wifi-slash"
                        color: Colors.textPrim
                        size: 9
                    }

                    Text {
                        Layout.fillWidth: true
                        text: loader.network.ethernetConnected ? "Ethernet" : "Wi-Fi"
                        color: Colors.textPrim
                        font.family: Colors.fontSecondary
                        font.pixelSize: Colors.fontSizeMedium
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 22
                        radius: Colors.radiusSm
                        color: refreshArea.containsMouse ? Colors.hover : "transparent"
                        visible: !loader.network.ethernetConnected && loader.network.wifiEnabled

                        Icon {
                            anchors.centerIn: parent
                            name: "arrows-clockwise"
                            color: loader.network.scanning ? Colors.textMuted : Colors.textPrim
                            size: 13

                            RotationAnimator on rotation {
                                from: 0
                                to: 360
                                duration: 800
                                loops: Animation.Infinite
                                running: loader.network.scanning
                            }

                        }

                        MouseArea {
                            id: refreshArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: loader.network.rescan()
                        }

                    }

                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 20
                        visible: !loader.network.ethernetConnected
                        radius: 10
                        color: loader.network.wifiEnabled ? Colors.textPrim : Colors.border

                        Rectangle {
                            width: 16
                            height: 16
                            radius: 8
                            color: loader.network.wifiEnabled ? Colors.bgDeep : Colors.textMuted
                            x: loader.network.wifiEnabled ? parent.width - width - 2 : 2
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on x {
                                NumberAnimation {
                                    duration: 120
                                }

                            }

                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                loader.expandedSsid = "";
                                loader.network.setWifiEnabled(!loader.network.wifiEnabled);
                            }
                        }

                    }

                }

                Ui.Divider {
                }

                Text {
                    visible: loader.network.ethernetConnected
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: "Подключено по Ethernet"
                    color: Colors.textMuted
                    font.family: Colors.fontSecondary
                    font.pixelSize: Colors.fontSizeSmall
                }

                ListView {
                    id: list

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, 320)
                     visible: !loader.network.ethernetConnected && loader.network.wifiEnabled
                    clip: true
                    spacing: 2
                    model: loader.network.networks
                    interactive: true

                    displaced: Transition {
                        NumberAnimation {
                            properties: "y"
                            duration: 140
                            easing.type: Easing.OutCubic
                        }

                    }

                    delegate: Item {
                        id: del

                        readonly property var net: modelData
                        readonly property bool isActive: net && net.inUse
                        readonly property bool isSecured: net && net.security && net.security.length > 0
                        readonly property bool isKnown: net && net.known === true
                        readonly property bool isConnecting: loader.connecting === (net ? net.ssid : "")
                        readonly property bool needsPassword: isSecured && !isKnown && !isActive
                        readonly property bool expanded: loader.expandedSsid === (net ? net.ssid : "") && (isActive || needsPassword)
                        readonly property int rowHeight: Metrics.rowHeight
                        readonly property int expandedHeight: 38
                        readonly property int gap: 4

                        width: list.width
                        height: expanded ? rowHeight + gap + expandedHeight : rowHeight

                        Item {
                            id: rowPart

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: del.rowHeight

                            Rectangle {
                                anchors.fill: parent
                                color: rowArea.containsMouse || del.expanded ? Colors.surface : "transparent"
                                radius: Colors.radiusSm
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Colors.spacingMd
                                anchors.rightMargin: 18
                                spacing: Colors.spacingMd

                                Icon {
                                    name: del.net.strength >= 75 ? "wifi-high" : del.net.strength >= 50 ? "wifi-medium" : del.net.strength >= 25 ? "wifi-low" : "wifi-none"
                                    color: del.isActive ? Colors.textPrim : Colors.textSecondary
                                    size: 9
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Text {
                                        Layout.fillWidth: true
                                        text: del.net.ssid
                                        color: Colors.textPrim
                                        font.family: Colors.fontSecondary
                                        font.pixelSize: Colors.fontSizeBase
                                        font.weight: del.isActive ? Font.DemiBold : Font.Normal
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        visible: del.isActive || del.isConnecting
                                        text: del.isConnecting ? "Подключение…" : "Подключено"
                                        color: Colors.textMuted
                                        font.family: Colors.fontSecondary
                                        font.pixelSize: Colors.fontSizeTiny
                                    }

                                }

                                Icon {
                                    visible: del.isSecured
                                    name: "lock-simple"
                                    color: Colors.textMuted
                                    size: 11
                                }

                                Text {
                                    text: del.net.strength + "%"
                                    color: Colors.textMuted
                                    font.family: Colors.fontMono
                                    font.pixelSize: Colors.fontSizeTiny
                                }

                            }

                            MouseArea {
                                id: rowArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    loader.lastError = "";
                                    if (del.isActive) {
                                        loader.expandedSsid = del.expanded ? "" : del.net.ssid;
                                        return ;
                                    }
                                    if (del.isKnown) {
                                        loader.expandedSsid = "";
                                        loader.connecting = del.net.ssid;
                                        loader.network.connectKnown(del.net.ssid);
                                        return ;
                                    }
                                    if (!del.isSecured) {
                                        loader.expandedSsid = "";
                                        loader.connecting = del.net.ssid;
                                        loader.network.connectOpen(del.net.ssid);
                                        return ;
                                    }
                                    loader.expandedSsid = del.expanded ? "" : del.net.ssid;
                                }
                            }

                        }

                        Loader {
                            id: expansion

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: rowPart.bottom
                            anchors.topMargin: del.gap
                            height: del.expandedHeight
                            active: del.expanded
                            visible: active

                            sourceComponent: Rectangle {
                                color: Colors.surface
                                radius: Colors.radiusSm

                                Loader {
                                    active: del.isActive
                                    visible: active
                                    anchors.fill: parent

                                    sourceComponent: RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Colors.marginLg
                                        anchors.rightMargin: Colors.spacingMd
                                        spacing: Colors.spacingMd

                                        Text {
                                            Layout.fillWidth: true
                                            text: "Подключено"
                                            color: Colors.textMuted
                                            font.family: Colors.fontSecondary
                                            font.pixelSize: Colors.fontSizeSmall
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 64
                                            Layout.preferredHeight: 24
                                            radius: 4
                                            color: forgetArea.containsMouse ? Colors.hover : "transparent"
                                            border.width: 1
                                            border.color: Colors.border

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Забыть"
                                                color: Colors.textSecondary
                                                font.family: Colors.fontSecondary
                                                font.pixelSize: Colors.fontSizeSmall
                                                font.weight: Font.DemiBold
                                            }

                                            MouseArea {
                                                id: forgetArea

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    loader.expandedSsid = "";
                                                    loader.network.forget(del.net.ssid);
                                                }
                                            }

                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 84
                                            Layout.preferredHeight: 24
                                            radius: 4
                                            color: discArea.containsMouse ? Colors.danger : Colors.dangerBg
                                            border.width: 1
                                            border.color: Colors.danger

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Отключить"
                                                color: discArea.containsMouse ? Colors.bgDeep : Colors.danger
                                                font.family: Colors.fontSecondary
                                                font.pixelSize: Colors.fontSizeSmall
                                                font.weight: Font.DemiBold
                                            }

                                            MouseArea {
                                                id: discArea

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    loader.expandedSsid = "";
                                                    loader.network.disconnectActive();
                                                }
                                            }

                                        }

                                    }

                                }

                                Loader {
                                    active: del.needsPassword
                                    visible: active
                                    anchors.fill: parent

                                    sourceComponent: RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Colors.spacingMd
                                        anchors.rightMargin: Colors.spacingMd
                                        spacing: Colors.spacingSm

                                        TextField {
                                            id: pwField

                                            function doConnect() {
                                                if (!pwField.text)
                                                    return ;

                                                loader.connecting = del.net.ssid;
                                                loader.network.connectWithPassword(del.net.ssid, pwField.text);
                                                loader.expandedSsid = "";
                                                pwField.text = "";
                                            }

                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 26
                                            echoMode: TextInput.Password
                                            placeholderText: "Пароль"
                                            color: Colors.textPrim
                                            font.family: Colors.fontSecondary
                                            font.pixelSize: Colors.fontSizeBase
                                            onAccepted: doConnect()
                                            Component.onCompleted: forceActiveFocus()

                                            background: Rectangle {
                                                color: Colors.bgDeep
                                                radius: 4
                                                border.width: 1
                                                border.color: Colors.border
                                            }

                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 64
                                            Layout.preferredHeight: 24
                                            radius: 4
                                            color: connectArea.containsMouse ? Colors.textPrim : Colors.textSecondary

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Connect"
                                                color: Colors.bgDeep
                                                font.family: Colors.fontSecondary
                                                font.pixelSize: Colors.fontSizeSmall
                                                font.weight: Font.DemiBold
                                            }

                                            MouseArea {
                                                id: connectArea

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: pwField.doConnect()
                                            }

                                        }

                                    }

                                }

                            }

                        }

                        Behavior on height {
                            NumberAnimation {
                                duration: 140
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                }

                Text {
                    visible: !loader.network.ethernetConnected && loader.network.wifiEnabled && loader.network.networks.length === 0
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: loader.network.scanning ? "Сканирование…" : "Сети не найдены"
                    color: Colors.textMuted
                    font.family: Colors.fontSecondary
                    font.pixelSize: Colors.fontSizeSmall
                }

                Text {
                    visible: loader.lastError.length > 0
                    Layout.fillWidth: true
                    text: loader.lastError
                    color: Colors.danger
                    font.family: Colors.fontSecondary
                    font.pixelSize: Colors.fontSizeTiny
                    wrapMode: Text.Wrap
                }

                Ui.Divider {
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    radius: Colors.radiusSm
                    color: editorArea.containsMouse ? Colors.surface : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "Открыть настройки сети"
                        color: Colors.textMuted
                        font.family: Colors.fontSecondary
                        font.pixelSize: Colors.fontSizeSmall
                    }

                    MouseArea {
                        id: editorArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            openEditor.running = true;
                            loader.open = false;
                        }
                    }

                }

            }

        }

    }

}
