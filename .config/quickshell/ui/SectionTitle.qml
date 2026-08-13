import "../theme" as Theme
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    property string title: ""
    property string subtitle: ""

    Layout.fillWidth: true
    spacing: 0

    Text {
        Layout.fillWidth: true
        text: parent.title
        color: Theme.Colors.textPrim
        font.family: Theme.Colors.fontPrimary
        font.pixelSize: Theme.Colors.fontSizeLarge
        font.weight: Font.DemiBold
    }

    Text {
        Layout.fillWidth: true
        visible: text.length > 0
        text: parent.subtitle
        color: Theme.Colors.textHint
        font.family: Theme.Colors.fontPrimary
        font.pixelSize: Theme.Colors.fontSizeTiny
        elide: Text.ElideRight
    }

}
