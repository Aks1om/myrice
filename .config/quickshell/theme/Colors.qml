pragma Singleton
import QtQuick

QtObject {
  // Colors
  readonly property color bgDeep:    "#050505"
  readonly property color bgBase:    "#000000"
  readonly property color surface:   "#0f0f0f"
  readonly property color overlay:   "#1a1a1a"
  readonly property color hover:     "#1e1e1e"
  readonly property color border:    "#2a2a2a"
  readonly property color textPrim:  "#ffffff"
  readonly property color textMuted: "#707070"
  readonly property color textSecondary: "#b0b0b0"
  readonly property color textHint:  "#606060"
  readonly property color textPlaceholder: "#505050"
  readonly property color danger:    "#e57373"
  readonly property color dangerBg:  "#2a1215"
  readonly property color accent:    "#c4b5fd"
  readonly property color accentDim: "#8b5cf6"

  // Fonts
  readonly property string fontPrimary:   "Inter"
  readonly property string fontSecondary: "Manrope"
  readonly property string fontMono:      "JetBrainsMono Nerd Font"

  // Font sizes
  readonly property int fontSizeTiny:   10
  readonly property int fontSizeSmall:  11
  readonly property int fontSizeBase:   12
  readonly property int fontSizeMedium: 13
  readonly property int fontSizeLarge:  14

  // Spacing
  readonly property int spacingXs:  4
  readonly property int spacingSm:  6
  readonly property int spacingMd:  8
  readonly property int spacingLg:  10
  readonly property int spacingXl:  14

  // Radius
  readonly property int radiusSm:   6
  readonly property int radiusMd:   8
  readonly property int radiusLg:   10
  readonly property int radiusXl:   14

  // Margins
  readonly property int marginSm:   4
  readonly property int marginMd:   8
  readonly property int marginLg:   10
  readonly property int marginXl:   12
}
