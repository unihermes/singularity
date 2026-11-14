// One frosted surface around the body and its curved connection to the module.
import QtQuick
import QtQuick.Shapes
import "../services"
import "../services/ChannelPath.js" as ChannelPath

Shape {
    id: root
    required property var attachment

    preferredRendererType: Shape.CurveRenderer

    // The neck is part of the panel, so pressing it does not dismiss it.
    Item {
        x: root.attachment.neck.x0
        y: root.attachment.neck.y0
        width: root.attachment.neck.x1 - x
        height: root.attachment.neck.y1 - y
        Absorber {}
    }

    Shadow { radius: Theme.panelFrameRadius; opaque: Theme.panelOpacity >= 1 }

    ShapePath {
        fillColor: Theme.flyoutFill
        strokeColor: Theme.stroke
        strokeWidth: Theme.borderWidth
        joinStyle: ShapePath.RoundJoin
        PathSvg { path: ChannelPath.outline(root.attachment.rects, root.attachment.fillet, 0) }
    }
}
