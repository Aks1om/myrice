import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Loader {
  id: loader
  property var anchorItem
  property var network          // ref to Network root
  property bool open: false
  property string connecting: ""
  property string lastError: ""
  property string expandedSsid: ""

  active: open
  asynchronous: true

  onOpenChanged: if (!open) { expandedSsid = ""; lastError = "" }

  Process { id: openEditor; command: ["nm-connection-editor"] }

  sourceComponent: PopupWindow {
    id: pop
    visible: true
    color: "transparent"
    implicitWidth: 320
    implicitHeight: container.implicitHeight + 20

    anchor {
      window: loader.anchorItem.QsWindow.window
      item: loader.anchorItem
      edges: Edges.Bottom
      gravity: Edges.Bottom
      margins.top: 8
    }

    HyprlandFocusGrab {
      active: loader.open
      windows: [pop]
      onCleared: loader.open = false
    }

    MouseArea {
      anchors.fill: parent
      onClicked: loader.open = false
    }

    Rectangle {
      id: container
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 10
      color: "#000000"
      radius: 14
      border.width: 1
      border.color: "#3a3a3a"
      implicitHeight: col.implicitHeight + 20

      MouseArea { anchors.fill: parent; onClicked: {} }

      ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        spacing: 8

        // Header: Wi-Fi toggle + Refresh
        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Icon {
            name: loader.network.wifiEnabled ? "wifi-high" : "wifi-slash"
            color: "#ffffff"
            size: 14
          }
          Text {
            Layout.fillWidth: true
            text: "Wi-Fi"
            color: "#ffffff"
            font.family: "Manrope"
            font.pixelSize: 13
            font.weight: Font.DemiBold
          }

          Rectangle {
            Layout.preferredWidth: 26
            Layout.preferredHeight: 22
            radius: 6
            color: refreshArea.containsMouse ? "#2e2e2e" : "transparent"
            visible: loader.network.wifiEnabled
            Icon {
              anchors.centerIn: parent
              name: "arrows-clockwise"
              color: loader.network.scanning ? "#909090" : "#ffffff"
              size: 13
              RotationAnimator on rotation {
                from: 0; to: 360; duration: 800; loops: Animation.Infinite
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
            radius: 10
            color: loader.network.wifiEnabled ? "#ffffff" : "#333333"
            Rectangle {
              width: 16; height: 16; radius: 8
              color: loader.network.wifiEnabled ? "#0f0f0f" : "#909090"
              x: loader.network.wifiEnabled ? parent.width - width - 2 : 2
              anchors.verticalCenter: parent.verticalCenter
              Behavior on x { NumberAnimation { duration: 120 } }
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                loader.expandedSsid = ""
                loader.network.setWifiEnabled(!loader.network.wifiEnabled)
              }
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 1
          color: "#252525"
        }

        // Networks list
        ListView {
          id: list
          Layout.fillWidth: true
          Layout.preferredHeight: Math.min(contentHeight, 320)
          visible: loader.network.wifiEnabled
          clip: true
          spacing: 2
          model: loader.network.networks
          interactive: true

          // Smoothly animate y-position of rows shifting when neighbour expands.
          displaced: Transition { NumberAnimation { properties: "y"; duration: 140; easing.type: Easing.OutCubic } }

          delegate: Item {
            id: del
            width: list.width

            readonly property var net: modelData
            readonly property bool isActive: net && net.inUse
            readonly property bool isSecured: net && net.security && net.security.length > 0
            readonly property bool isConnecting: loader.connecting === (net ? net.ssid : "")
            readonly property bool expanded: loader.expandedSsid === (net ? net.ssid : "") && (isActive || isSecured)

            readonly property int rowHeight: 44
            readonly property int expandedHeight: 38
            readonly property int gap: 4

            height: expanded ? rowHeight + gap + expandedHeight : rowHeight
            Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            // Top row (constant 44px). Hover/click confined here, so click on
            // password row below does not retrigger row logic.
            Item {
              id: rowPart
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              height: del.rowHeight

              Rectangle {
                anchors.fill: parent
                color: rowArea.containsMouse || del.expanded ? "#1c1c1c" : "transparent"
                radius: 6
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 18
                spacing: 8

                Icon {
                  name: del.net.strength >= 75 ? "wifi-high"
                      : del.net.strength >= 50 ? "wifi-medium"
                      : del.net.strength >= 25 ? "wifi-low"
                                               : "wifi-none"
                  color: del.isActive ? "#ffffff" : "#cfcfcf"
                  size: 14
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 0
                  Text {
                    Layout.fillWidth: true
                    text: del.net.ssid
                    color: "#ffffff"
                    font.family: "Manrope"
                    font.pixelSize: 12
                    font.weight: del.isActive ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                  }
                  Text {
                    visible: del.isActive || del.isConnecting
                    text: del.isConnecting ? "Подключение…" : "Подключено"
                    color: "#909090"
                    font.family: "Manrope"
                    font.pixelSize: 10
                  }
                }

                Icon {
                  visible: del.isSecured
                  name: "lock-simple"
                  color: "#909090"
                  size: 11
                }
                Text {
                  text: del.net.strength + "%"
                  color: "#909090"
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 10
                }
              }

              MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  loader.lastError = ""
                  // Open network: just connect, no expansion
                  if (!del.isActive && !del.isSecured) {
                    loader.expandedSsid = ""
                    loader.connecting = del.net.ssid
                    loader.network.connectOpen(del.net.ssid)
                    return
                  }
                  // Active or secured: toggle expanded row
                  loader.expandedSsid = del.expanded ? "" : del.net.ssid
                }
              }
            }

            // Expanded row — sits BELOW rowPart inside the delegate so the
            // delegate's height grows and pushes neighbours down via ListView.displaced.
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
                color: "#1c1c1c"
                radius: 6

                // Active network → Disconnect button
                Loader {
                  active: del.isActive
                  visible: active
                  anchors.fill: parent
                  sourceComponent: RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                      Layout.fillWidth: true
                      text: "Текущее подключение"
                      color: "#909090"
                      font.family: "Manrope"
                      font.pixelSize: 11
                      elide: Text.ElideRight
                    }
                    Rectangle {
                      Layout.preferredWidth: 84
                      Layout.preferredHeight: 24
                      radius: 4
                      color: discArea.containsMouse ? "#e57373" : "#3a1f1f"
                      border.width: 1
                      border.color: "#e57373"
                      Text {
                        anchors.centerIn: parent
                        text: "Отключить"
                        color: discArea.containsMouse ? "#0f0f0f" : "#e57373"
                        font.family: "Manrope"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                      }
                      MouseArea {
                        id: discArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          loader.expandedSsid = ""
                          loader.network.disconnectActive()
                        }
                      }
                    }
                  }
                }

                // Secured (not active) → password input + Connect
                Loader {
                  active: !del.isActive && del.isSecured
                  visible: active
                  anchors.fill: parent
                  sourceComponent: RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    TextField {
                      id: pwField
                      Layout.fillWidth: true
                      Layout.preferredHeight: 26
                      echoMode: TextInput.Password
                      placeholderText: "Пароль"
                      color: "#ffffff"
                      font.family: "Manrope"
                      font.pixelSize: 12
                      background: Rectangle {
                        color: "#0f0f0f"; radius: 4
                        border.width: 1; border.color: "#333333"
                      }
                      onAccepted: doConnect()
                      Component.onCompleted: forceActiveFocus()

                      function doConnect() {
                        if (!pwField.text) return
                        loader.connecting = del.net.ssid
                        loader.network.connectWithPassword(del.net.ssid, pwField.text)
                        loader.expandedSsid = ""
                        pwField.text = ""
                      }
                    }

                    Rectangle {
                      Layout.preferredWidth: 64
                      Layout.preferredHeight: 24
                      radius: 4
                      color: connectArea.containsMouse ? "#ffffff" : "#cfcfcf"
                      Text {
                        anchors.centerIn: parent
                        text: "Connect"
                        color: "#0f0f0f"
                        font.family: "Manrope"
                        font.pixelSize: 11
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
          }
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        }

        Text {
          visible: loader.network.wifiEnabled && loader.network.networks.length === 0
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          text: loader.network.scanning ? "Сканирование…" : "Сети не найдены"
          color: "#909090"
          font.family: "Manrope"
          font.pixelSize: 11
        }

        Text {
          visible: loader.lastError.length > 0
          Layout.fillWidth: true
          text: loader.lastError
          color: "#e57373"
          font.family: "Manrope"
          font.pixelSize: 10
          wrapMode: Text.Wrap
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 1
          color: "#252525"
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 26
          radius: 6
          color: editorArea.containsMouse ? "#1c1c1c" : "transparent"
          Text {
            anchors.centerIn: parent
            text: "Открыть настройки сети"
            color: "#909090"
            font.family: "Manrope"
            font.pixelSize: 11
          }
          MouseArea {
            id: editorArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              openEditor.running = true
              loader.open = false
            }
          }
        }
      }
    }
  }
}
