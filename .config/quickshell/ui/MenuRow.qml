import ".." as Shell
import "../theme" as Theme
import QtQuick
import QtQuick.Layouts

Item {
    property string label: ""
    property string hint: ""
    property string iconName: ""
    property bool selected: false
    property bool enabled: true

    signal activated()
    signal hovered()

    Layout.fillWidth: true
    implicitHeight: Theme.Metrics.rowHeight

    Rectangle {
        anchors.fill: parent
        color: rowArea.containsMouse || parent.selected ? Theme.Colors.surface : "transparent"
        radius: Theme.Colors.radiusMd
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.Metrics.menuPadding
        anchors.rightMargin: Theme.Metrics.menuPadding
        spacing: Theme.Metrics.menuPadding

        Shell.Icon {
            name: parent.parent.iconName
            color: parent.parent.selected ? Theme.Colors.textPrim : Theme.Colors.textSecondary
            size: Theme.Metrics.iconSize
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: parent.parent.parent.label
                color: parent.parent.parent.selected ? Theme.Colors.textPrim : Theme.Colors.textSecondary
                font.family: Theme.Colors.fontSecondary
                font.pixelSize: Theme.Colors.fontSizeBase
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: parent.parent.parent.hint
                color: Theme.Colors.textHint
                font.family: Theme.Colors.fontSecondary
                font.pixelSize: Theme.Colors.fontSizeTiny
                elide: Text.ElideRight
            }

        }

    }

    MouseArea {
        id: rowArea

        anchors.fill: parent
        enabled: parent.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: parent.hovered()
        onClicked: parent.activated()
    }

}
