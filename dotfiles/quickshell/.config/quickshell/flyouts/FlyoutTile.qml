// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutTile.qml
//
// A tile in a flyout's grid: a glyph, a value or name, and a caption under
// it, framed as a control. `lit` (a toggle that's on, a sensor in use)
// lights its edge and glyph; a tile with `clickable` takes the pointer.
// Laid out in a Grid by the flyout; `big` sets the value at title size;
// children go under the caption.

import QtQuick
import "../services"

Item {
    id: root

    property string glyph: ""
    property string title: ""
    property string caption: ""
    property bool lit: false
    property bool big: false
    property bool centred: false
    property bool clickable: false
    property bool dimmed: false

    // more under the caption (a meter)
    default property alias extra: col.data

    signal clicked()

    readonly property string kind: Theme.style
    readonly property bool hot: clickable && mouse.containsMouse

    implicitHeight: col.implicitHeight + Theme.spaceL * 2

    Rectangle {
        id: box
        readonly property color edge: root.lit ? Theme.strokeFocus
            : root.hot ? Theme.strokeHover : Theme.stroke
        readonly property color frost: Theme.isLight ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(1, 1, 1, 0.06)
        anchors.fill: parent
        radius: Theme.radiusInner
        color: root.kind === "solid" ? (root.lit ? Qt.tint(Theme.surface, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25))
                : root.hot ? Theme.overlay : Theme.surface)
            : root.kind === "glass" ? (root.hot ? Theme.stroke : frost)
            : root.kind === "flat" ? (root.hot ? Theme.overlay : Theme.surface)
            : Theme.controlFill(root.hot ? Theme.hoverFillSoft : "transparent")
        border.width: root.kind === "solid" ? 0
            : root.kind === "flat" ? (root.lit ? Math.max(2, Theme.borderWidth * 2) : 0)
            : Theme.controlBorder(edge)
        border.color: root.kind === "glass" ? (root.lit ? Theme.accent : Theme.stroke)
            : root.kind === "flat" ? Theme.accent : Theme.controlStroke(edge)

        ControlEdge {
            visible: root.kind === "channel" || root.kind === "double"
            stroke: box.edge; radius: box.radius
            lit: root.lit
        }
    }

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Theme.spaceL
        spacing: Theme.spaceXs

        Text {
            visible: root.glyph !== ""
            width: parent.width
            horizontalAlignment: root.centred ? Text.AlignHCenter : Text.AlignLeft
            text: root.glyph
            color: root.lit ? Theme.accent : root.dimmed ? Theme.subtext : Theme.text
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontIconSize
        }
        Text {
            visible: root.title !== ""
            width: parent.width
            horizontalAlignment: root.centred ? Text.AlignHCenter : Text.AlignLeft
            elide: Text.ElideRight
            text: root.title
            color: root.dimmed ? Theme.subtext : Theme.textStrong
            font.family: Theme.fontText
            font.weight: root.big ? Theme.weightStrong : Theme.weightBody
            font.pixelSize: root.big ? Theme.fontTitle : Theme.fontBody
        }
        Text {
            visible: root.caption !== ""
            width: parent.width
            horizontalAlignment: root.centred ? Text.AlignHCenter : Text.AlignLeft
            elide: Text.ElideRight
            text: root.caption
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: root.clickable
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
