// Shared geometry for the rail, ruled, notched and bevelled frames.
import QtQuick
import QtQuick.Shapes
import "../services"

Shape {
    id: root
    anchors.fill: parent
    property string kind: Theme.frameStyle
    property color ground: "transparent"
    property color stroke: Theme.stroke
    property bool section: false
    property bool control: false
    property bool sunken: false
    readonly property real bw: Theme.borderWidth
    readonly property real cut: Math.min(Theme.notchSize, width / 4, height / 3)
    property LinearGradient shading: LinearGradient {
        x1: 0; y1: 0; x2: 0; y2: root.height
        GradientStop { position: 0; color: Theme.shadeTop(root.ground) }
        GradientStop { position: 1; color: Theme.shadeBottom(root.ground) }
    }
    readonly property string outline: {
        var b = bw / 2, w = Math.max(b, width - b), h = Math.max(b, height - b), c = cut
        if (kind === "notch") return "M " + b + " " + b + " H " + (w - c) + " L " + w + " " + (b + c)
            + " V " + h + " H " + (b + c) + " L " + b + " " + (h - c) + " Z"
        return "M " + b + " " + b + " H " + w + " V " + h + " H " + b + " Z"
    }

    ShapePath {
        fillColor: root.ground
        fillGradient: Theme.gradient && root.ground.a > 0 ? root.shading : null
        strokeColor: root.kind === "notch" || (root.kind === "bevel" && Qt.colorEqual(root.stroke, Theme.strokeFocus))
            || (root.kind === "ruled" && !root.section && !root.control)
            ? root.stroke : "transparent"
        strokeWidth: root.bw
        joinStyle: ShapePath.MiterJoin
        PathSvg { path: root.outline }
    }
    ShapePath {
        fillColor: "transparent"
        strokeColor: root.kind === "rail" ? (root.control || root.section ? root.stroke : Theme.accent)
            : root.kind === "ruled" ? root.stroke
            : root.kind === "bevel" ? (root.sunken ? Theme.bevelDark : Theme.bevelLight) : "transparent"
        strokeWidth: root.kind === "rail" && !root.control && !root.section ? root.bw * 2 : root.bw
        PathSvg {
            path: {
                var b = root.bw, w = Math.max(b, root.width - b), h = Math.max(b, root.height - b)
                if (root.kind === "rail") return root.control ? "M " + b + " " + h + " H " + w : "M " + b + " " + b + " V " + h
                if (root.kind === "ruled") return "M " + b + " " + (root.control ? h : b) + " H " + w
                return "M " + b + " " + h + " V " + b + " H " + w
            }
        }
    }
    ShapePath {
        fillColor: "transparent"
        strokeColor: root.kind === "bevel" ? (root.sunken ? Theme.bevelLight : Theme.bevelDark) : "transparent"
        strokeWidth: root.bw
        PathSvg { path: "M " + root.bw + " " + (root.height - root.bw) + " H " + (root.width - root.bw) + " V " + root.bw }
    }
}
