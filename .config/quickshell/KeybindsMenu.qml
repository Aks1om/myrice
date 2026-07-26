import "theme"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

Scope {
  id: root
  property bool isOpen: false
  property string query: ""
  property int selected: 0

  readonly property var allBinds: [
    // Apps
    { cat: "Приложения", keys: "SUPER + T",         desc: "Терминал (Ghostty)" },
    { cat: "Приложения", keys: "SUPER + E",         desc: "Файлы (Nemo)" },
    { cat: "Приложения", keys: "SUPER + SPACE",     desc: "Поиск приложений" },
    { cat: "Приложения", keys: "SUPER + V",         desc: "Буфер обмена (clipse)" },
    { cat: "Приложения", keys: "SUPER + SHIFT + W", desc: "NetworkManager editor" },

    // Window mgmt
    { cat: "Окна",       keys: "SUPER + Q",         desc: "Закрыть окно" },
    { cat: "Окна",       keys: "SUPER + TAB",       desc: "Следующее окно" },
    { cat: "Окна",       keys: "SUPER + SHIFT + TAB", desc: "Предыдущее окно" },
    { cat: "Окна",       keys: "SUPER + G",         desc: "Toggle floating" },
    { cat: "Окна",       keys: "SUPER + F",         desc: "Fullscreen" },
    { cat: "Окна",       keys: "SUPER + B",         desc: "Сменить split (V/H)" },
    { cat: "Окна",       keys: "SUPER + SHIFT + T", desc: "Tile окно из floating" },
    { cat: "Окна",       keys: "SUPER + SHIFT + V", desc: "Все окна WS во floating" },
    { cat: "Окна",       keys: "SUPER + LMB drag", desc: "Двигать окно" },
    { cat: "Окна",       keys: "SUPER + RMB drag", desc: "Ресайз окна" },

    // System popups
    { cat: "Меню",       keys: "SUPER + ESC",       desc: "Power-меню (Lock/Reboot/Shutdown)" },
    { cat: "Меню",       keys: "SUPER + P",         desc: "Display-меню (как Win + P)" },
    { cat: "Меню",       keys: "SUPER + F12",       desc: "Скриншот-меню" },
    { cat: "Меню",       keys: "PRINT",             desc: "Скриншот-меню" },
    { cat: "Меню",       keys: "SUPER + SHIFT + F12", desc: "Скриншот: весь экран сразу" },
    { cat: "Меню",       keys: "SHIFT + PRINT",     desc: "Скриншот: весь экран сразу" },
    { cat: "Меню",       keys: "SUPER + CTRL + S",  desc: "UI Scale (слайдер)" },
    { cat: "Меню",       keys: "SUPER + CTRL + =",  desc: "Scale +5%" },
    { cat: "Меню",       keys: "SUPER + CTRL + −",  desc: "Scale −5%" },
    { cat: "Меню",       keys: "SUPER + CTRL + 0",  desc: "Scale reset (100%)" },
    { cat: "Меню",       keys: "SUPER + SHIFT + R", desc: "Переключение русского Ctrl-режима (латинские Ctrl-сочетания в русской раскладке)" },
    { cat: "Меню",       keys: "SUPER + F1",        desc: "Эта подсказка" },

    // Workspaces
    { cat: "Workspaces", keys: "SUPER + 1…0",       desc: "Перейти на workspace 1–10" },
    { cat: "Workspaces", keys: "SUPER + SHIFT + 1…0", desc: "Перенести окно на workspace" },
    { cat: "Workspaces", keys: "SUPER + Wheel",     desc: "Скролл по workspaces" },
    { cat: "Workspaces", keys: "SUPER + S",         desc: "Toggle special workspace" },
    { cat: "Workspaces", keys: "SUPER + SHIFT + S", desc: "Окно в/из special workspace" },

    // Notifications
    { cat: "Уведомления", keys: "SUPER + N",         desc: "Открыть/закрыть swaync" },
    { cat: "Уведомления", keys: "SUPER + SHIFT + N", desc: "Toggle Do Not Disturb" },

    // Media keys
    { cat: "Медиа",      keys: "XF86 Volume ±",     desc: "Громкость ±5%" },
    { cat: "Медиа",      keys: "XF86 Mute",         desc: "Mute / Unmute" },
    { cat: "Медиа",      keys: "XF86 Brightness ±", desc: "Яркость ±5%" },

    // Misc
    { cat: "Прочее",     keys: "SUPER + ALT + S",   desc: "Toggle sudo-nopasswd" },
    { cat: "Прочее",     keys: "SUPER + SHIFT + Q", desc: "Выйти из Hyprland" },
    { cat: "Прочее",     keys: "SUPER + SHIFT + ESC", desc: "Диспетчер задач (btop)" }
  ]

  property var results: []

  function recompute() {
    const q = root.query.toLowerCase().trim()
    if (!q) {
      root.results = root.allBinds.slice()
    } else {
      root.results = root.allBinds.filter(b =>
        b.keys.toLowerCase().includes(q)
        || b.desc.toLowerCase().includes(q)
        || b.cat.toLowerCase().includes(q)
      )
    }
    if (root.selected >= root.results.length) root.selected = 0
  }

  onQueryChanged: recompute()
  Component.onCompleted: recompute()

  IpcHandler {
    target: "keybinds"
    function open(): void   { root.query = ""; root.selected = 0; root.isOpen = true }
    function close(): void  { root.isOpen = false }
    function toggle(): void { if (!root.isOpen) { root.query = ""; root.selected = 0 } root.isOpen = !root.isOpen }
  }

  Loader {
    id: loader
    active: root.isOpen
    asynchronous: true

    sourceComponent: PanelWindow {
      screen: Hyprland.focusedMonitor?.screen ?? Quickshell.screens[0]
      visible: true
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      anchors {
        top: true
        left: true
        right: true
        bottom: true
      }

      MouseArea {
        anchors.fill: parent
        onClicked: root.isOpen = false
      }

      Rectangle {
        anchors.centerIn: parent
        width: 680
        height: 540
        color: Colors.bgBase
        radius: Colors.radiusXl
        border.width: 1
        border.color: Colors.border

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Colors.marginXl
          spacing: Colors.spacingLg

          TextField {
            id: search
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            focus: true
            text: root.query
            placeholderText: "Поиск хоткеев…"
            placeholderTextColor: Colors.textPlaceholder
            color: Colors.textPrim
            font.family: Colors.fontPrimary
            font.pixelSize: Colors.fontSizeLarge
            selectByMouse: true
            verticalAlignment: TextInput.AlignVCenter
            leftPadding: 14
            rightPadding: 14

            background: Rectangle {
              color: Colors.surface
              radius: 10
              border.width: 1
              border.color: Colors.border
            }

            onTextChanged: root.query = text

            Keys.onPressed: (e) => {
              if (e.key === Qt.Key_Down) {
                root.selected = Math.min(root.results.length - 1, root.selected + 1)
                e.accepted = true
              } else if (e.key === Qt.Key_Up) {
                root.selected = Math.max(0, root.selected - 1)
                e.accepted = true
              } else if (e.key === Qt.Key_Escape) {
                root.isOpen = false
                e.accepted = true
              } else if (e.key === Qt.Key_Tab) {
                root.selected = (root.selected + 1) % Math.max(1, root.results.length)
                e.accepted = true
              }
            }
          }

          ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.results
            currentIndex: root.selected
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds

            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Item {
              required property var modelData
              required property int index
              width: list.width
              height: 38

              property bool isFocused: hoverArea.containsMouse || index === root.selected

              Rectangle {
                anchors.fill: parent
                anchors.rightMargin: 4
                color: parent.isFocused ? Colors.surface : "transparent"
                radius: Colors.radiusMd
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 14
                spacing: 12

                // Hotkey (mono, fixed width)
                Text {
                  Layout.preferredWidth: 220
                  text: modelData.keys
                  color: parent.parent.isFocused ? Colors.textPrim : Colors.textSecondary
                  font.family: Colors.fontMono
                  font.pixelSize: Colors.fontSizeSmall
                  elide: Text.ElideRight
                }

                // Description
                Text {
                  Layout.fillWidth: true
                  text: modelData.desc
                  color: parent.parent.isFocused ? Colors.textPrim : Colors.textMuted
                  font.family: Colors.fontSecondary
                  font.pixelSize: Colors.fontSizeBase
                  elide: Text.ElideRight
                }

                // Category badge
                Text {
                  text: modelData.cat
                  color: Colors.textHint
                  font.family: Colors.fontPrimary
                  font.pixelSize: Colors.fontSizeTiny
                }
              }

              MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                onEntered: root.selected = parent.index
              }
            }
          }

          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            visible: root.results.length === 0
            text: "Ничего не найдено"
            color: Colors.textPlaceholder
            font.family: Colors.fontPrimary
            font.pixelSize: Colors.fontSizeSmall
          }
        }
      }
    }
  }
}
