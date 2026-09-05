// GENERATED FILE — DO NOT EDIT.
// Source: .config/quickshell/theme/tokens.json
pragma Singleton
import QtQuick

QtObject {
  // Static design density, intentionally independent of monitor scale.
  readonly property real density: 1
  function px(value) { return Math.round(value * density) }

  // Semantic dimensions
  readonly property int panelWidth: px(320)
  readonly property int panelPadding: px(10)
  readonly property int popupInset: px(10)
  readonly property int popupAnchorOffset: px(-10)
  readonly property int menuWidth: px(380)
  readonly property int powerMenuWidth: px(320)
  readonly property int menuPadding: px(12)
  readonly property int rowHeight: px(44)
  readonly property int compactRowHeight: px(32)
  readonly property int controlHeight: px(28)
  readonly property int dividerHeight: px(1)
  readonly property int listMaxHeight: px(320)
  readonly property int iconSize: px(16)
  readonly property int launcherWidth: px(560)
  readonly property int launcherHeight: px(480)
  readonly property int keybindsWidth: px(680)
  readonly property int keybindsHeight: px(540)
  readonly property int keybindRowHeight: px(38)
  readonly property int scalePanelWidth: px(380)
  readonly property int scalePanelPadding: px(16)
  readonly property int trayMenuWidth: px(220)
  readonly property int trayPopupPadding: px(16)
  readonly property int trayItemSize: px(22)
  readonly property int trayEmptyWidth: px(100)
  readonly property int trayEmptyHeight: px(36)
  readonly property int trayHeaderIconSize: px(20)
}
