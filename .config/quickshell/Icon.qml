import QtQuick
import QtQuick.Effects
import "theme"

Item {
  id: root
  property string name: ""
  property string sourcePath: ""
  property string variant: "regular"  // "thin" | "light" | "regular" | "bold" | "fill"
  property color color: Colors.textPrim
  property int size: Metrics.iconSize

  implicitWidth: size
  implicitHeight: size

  Image {
    id: img
    anchors.fill: parent
    source: root.sourcePath
      ? Qt.resolvedUrl(root.sourcePath)
      : root.name
      ? `${Qt.resolvedUrl("icons/phosphor/assets/" + root.variant)}/${root.name}${root.variant === "regular" ? "" : "-" + root.variant}.svg`
      : ""
    sourceSize.width: root.size
    sourceSize.height: root.size
    fillMode: Image.PreserveAspectFit
    smooth: true
    asynchronous: true
    mipmap: false

    layer.enabled: true
    layer.effect: MultiEffect {
      colorization: 1.0
      colorizationColor: root.color
      brightness: 1.0
    }
  }
}
