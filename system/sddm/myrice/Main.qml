import QtQuick 2.15
import SddmComponents 2.0

Rectangle {
    id: root

    color: "#0a0a0c"
    property string statusText: ""
    property color statusColor: "#dcdcdc"
    property int sessionIndex: sessionModel.lastIndex
    property date currentTime: new Date()

    function login() {
        if (username.text.length === 0 || password.text.length === 0)
            return

        statusText = "Checking..."
        statusColor = "#dcdcdc"
        sddm.login(username.text, password.text, sessionIndex)
    }

    Connections {
        target: sddm

        function onLoginFailed() {
            password.text = ""
            statusText = "Incorrect password"
            statusColor = "#ff8aa2"
            password.forceActiveFocus()
        }

        function onInformationMessage(message) {
            statusText = message
            statusColor = "#ff8aa2"
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = new Date()
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.76, 1040)
        height: 1
        color: "#ffffff"
        opacity: 0.12
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.16
        spacing: 2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#ffffff"
            font.family: "Noto Sans"
            font.pixelSize: Math.min(root.width * 0.105, 120)
            font.weight: Font.Medium
            text: Qt.formatTime(root.currentTime, "hh:mm")
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#dcdcdc"
            opacity: 0.85
            font.family: "Noto Sans"
            font.pixelSize: 20
            text: Qt.formatDate(root.currentTime, "dddd, d MMMM")
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: parent.height * 0.18
        width: Math.min(parent.width * 0.42, 420)
        spacing: 12

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#ffffff"
            font.family: "Noto Sans"
            font.pixelSize: 20
            font.weight: Font.Medium
            text: username.text.length > 0 ? username.text : "Sign in"
        }

        Rectangle {
            width: parent.width
            height: 48
            radius: 24
            color: "#1a1a20"
            border.width: username.activeFocus ? 1 : 0
            border.color: "#ffffff"
            opacity: username.activeFocus ? 0.95 : 0.78

            TextInput {
                id: username
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                color: "#ffffff"
                font.family: "Noto Sans"
                font.pixelSize: 16
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true
                text: userModel.lastUser
                onAccepted: password.forceActiveFocus()
            }
        }

        Rectangle {
            width: parent.width
            height: 48
            radius: 24
            color: "#1a1a20"
            border.width: password.activeFocus ? 1 : 0
            border.color: "#ffffff"
            opacity: password.activeFocus ? 0.95 : 0.78

            TextInput {
                id: password
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                color: "#ffffff"
                font.family: "Noto Sans"
                font.pixelSize: 16
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true
                echoMode: TextInput.Password
                focus: true
                onAccepted: root.login()
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                visible: password.text.length === 0 && !password.activeFocus
                color: "#dcdcdc"
                opacity: 0.55
                font.family: "Noto Sans"
                font.pixelSize: 16
                text: "Enter password"
            }
        }

        Text {
            width: parent.width
            height: 22
            horizontalAlignment: Text.AlignHCenter
            color: root.statusColor
            font.family: "Noto Sans"
            font.pixelSize: 13
            text: root.statusText
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        spacing: 28

        Text {
            color: "#dcdcdc"
            opacity: 0.72
            font.family: "Noto Sans"
            font.pixelSize: 14
            text: "Hyprland"
        }

        Text {
            color: "#dcdcdc"
            opacity: 0.72
            font.family: "Noto Sans"
            font.pixelSize: 14
            text: "Restart"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: sddm.reboot()
            }
        }

        Text {
            color: "#dcdcdc"
            opacity: 0.72
            font.family: "Noto Sans"
            font.pixelSize: 14
            text: "Power off"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: sddm.powerOff()
            }
        }
    }
}
