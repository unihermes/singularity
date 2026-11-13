// A quick-settings tile: a glyph, a name and its state in words, filled
// with the accent while on (`lit`). `split` gives it a chevron end of its
// own that opens the tile's details in place (moreClicked; 󰅀 while
// `expanded`); `goes` puts 󰅂 on a tile whose whole face opens a page.
// `confirmText` makes it two clicks (armed for 3s, alert-filled).

import QtQuick
import "../services"

Item {
    id: root

    property string icon: ""
    property string title: ""
    property string caption: ""
    property bool lit: false
    property bool split: false
    property bool expanded: false
    property bool goes: false
    property bool usable: true
    property string confirmText: ""
    readonly property bool armed: disarm.running

    signal clicked()
    signal moreClicked()

    readonly property string kind: Theme.controlStyle
    readonly property bool hot: usable && (face.containsMouse || more.containsMouse)
    readonly property color ink: armed ? Theme.base : lit ? Theme.textOnAccent
        : hot ? Theme.textStrong : Theme.text

    implicitHeight: Math.max(Theme.fieldHeight, words.implicitHeight) + Theme.spaceS * 2
    opacity: usable ? 1 : 0.5

    Rectangle {
        id: box
        readonly property color edge: root.armed ? Theme.alert
            : root.lit ? Theme.selectedStroke
            : root.hot ? Theme.strokeHover : Theme.stroke
        readonly property color frost: Theme.isLight ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(1, 1, 1, 0.06)
        anchors.fill: parent
        radius: Theme.radiusInner
        readonly property color faceFill: root.armed ? Theme.alert
            : root.lit ? Theme.accent
            : root.kind === "solid" ? (root.hot ? Theme.overlay : Theme.surface)
            : root.kind === "glass" ? (root.hot ? Theme.stroke : frost)
            : root.kind === "flat" ? Theme.overlay
            : Theme.controlFill(root.hot ? Theme.hoverFillSoft : "transparent")
        color: Theme.frameCustom && Theme.frameStyle === "notch" ? "transparent" : faceFill
        border.width: root.kind === "solid" ? 0
            : root.kind === "glass" ? Theme.borderWidth
            : root.kind === "flat" ? (root.hot && !root.armed && !root.lit ? Math.max(2, Theme.borderWidth * 2) : 0)
            : Theme.controlBorder(edge)
        border.color: root.kind === "glass" ? Theme.stroke
            : root.kind === "flat" ? Theme.subtext : Theme.controlStroke(edge)

        // a lit tile is a pressed button
        ControlEdge {
            visible: root.kind === "channel" || root.kind === "double" || Theme.frameCustom
            ground: Theme.frameStyle === "notch" ? box.faceFill : "transparent"
            stroke: box.edge; sunken: root.lit; radius: box.radius
            lit: false
        }
    }

    Text {
        id: glyph
        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceM
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconCell
        horizontalAlignment: Text.AlignHCenter
        text: root.icon
        color: root.ink
        font.family: Theme.fontIcon
        font.pixelSize: Theme.fontIconSize
    }

    Column {
        id: words
        anchors.left: glyph.right
        anchors.leftMargin: Theme.spaceS
        anchors.right: end.left
        anchors.rightMargin: Theme.spaceXs
        anchors.verticalCenter: parent.verticalCenter

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.armed ? root.confirmText : root.title
            color: root.ink
            font.family: Theme.fontText
            font.weight: Theme.weightStrong
            font.pixelSize: Theme.fontSmall
        }
        Text {
            visible: text !== ""
            width: parent.width
            elide: Text.ElideRight
            text: root.armed ? "" : root.caption
            color: root.lit ? root.ink : Theme.subtext
            opacity: root.lit ? 0.8 : 1
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontCaption
        }
    }

    // the chevron end: a part of its own when split, set off by a hairline
    Item {
        id: end
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.split || root.goes ? Theme.controlSize : Theme.spaceS

        Rectangle {
            visible: root.split
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.borderWidth
            height: parent.height - Theme.spaceM * 2
            color: root.lit ? root.ink : Theme.stroke
            opacity: root.lit ? 0.3 : 1
        }

        Text {
            visible: root.split || root.goes
            anchors.centerIn: parent
            text: root.expanded ? "󰅀" : "󰅂"
            color: root.lit ? root.ink : more.containsMouse || (root.goes && face.containsMouse) ? Theme.textStrong : Theme.subtext
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontIconSize
        }

        MouseArea {
            id: more
            anchors.fill: parent
            enabled: root.split && root.usable
            hoverEnabled: enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: root.moreClicked()
        }
    }

    MouseArea {
        id: face
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: root.split ? end.left : parent.right
        enabled: root.usable
        hoverEnabled: enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.confirmText !== "" && !disarm.running) { disarm.restart(); return }
            disarm.stop()
            root.clicked()
        }
    }

    Timer { id: disarm; interval: 3000 }
}
