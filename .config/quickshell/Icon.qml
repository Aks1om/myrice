import QtQuick
import QtQuick.Effects

Item {
  id: root
  property string name: ""
  property string variant: "regular"  // "thin" | "light" | "regular" | "bold" | "fill"
  property color color: "#ffffff"
  property int size: 16

  implicitWidth: size
  implicitHeight: size

  Image {
    id: img
    anchors.fill: parent
    source: root.name
      ? `${Qt.resolvedUrl("icons/phosphor/assets/" + root.variant)}/${root.name}${root.variant === "regular" ? "" : "-" + root.variant}.svg`
      : ""
    sourceSize.width: root.size * 2
    sourceSize.height: root.size * 2
    fillMode: Image.PreserveAspectFit
    smooth: true
    asynchronous: true
    mipmap: true

    layer.enabled: true
    layer.effect: MultiEffect {
      colorization: 1.0
      colorizationColor: root.color
      brightness: 1.0
    }
  }
}
