// One frosted surface: the flyout body, square against the bar's edge and
// rounded on the far side, with the outline stroked everywhere but along the bar.
import QtQuick
import QtQuick.Shapes
import "../services"
import "../services/GlassFlyout.js" as GlassFlyout

Shape {
    id: root
    required property var attachment
    property bool atBottom: false

    preferredRendererType: Shape.CurveRenderer
    // a bottom bar mirrors the whole shape upward
    transform: Scale { yScale: root.atBottom ? -1 : 1; origin.y: root.attachment.height / 2 }

    Shadow { radius: Theme.panelFrameRadius; opaque: Theme.panelOpacity >= 1 }

    ShapePath {
        fillColor: Theme.flyoutFill
        strokeWidth: -1
        PathSvg { path: GlassFlyout.path(root.attachment, true) }
    }
    ShapePath {
        fillColor: "transparent"
        strokeColor: Theme.stroke
        strokeWidth: Theme.borderWidth
        joinStyle: ShapePath.RoundJoin
        PathSvg { path: GlassFlyout.path(root.attachment, false) }
    }
}
