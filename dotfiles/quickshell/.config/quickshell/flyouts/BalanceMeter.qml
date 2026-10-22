// Singularity - Quickshell
// ~/.config/quickshell/flyouts/BalanceMeter.qml
//
// A Meter's track whose fill runs from the middle out to one side: the
// ChatMix dial, Game on the left and Chat on the right. Upright, Game is
// at the top.

import QtQuick
import "../services"

Rectangle {
    id: root

    // -1 (all one side: left, or the top upright) .. 1 (all the other); clamped
    property real balance: 0
    property bool vertical: false
    property color fillColor: Theme.meterFill

    readonly property real amount: Math.max(-1, Math.min(1, balance))
    readonly property real length: vertical ? height : width
    readonly property real thickness: vertical ? width : height

    implicitHeight: Theme.meterHeight
    radius: Math.min(thickness / 2, Theme.radius)
    color: Theme.meterTrack
    border.width: Theme.borderWidth
    border.color: Theme.meterStroke

    // the middle, so an even mix still shows where it sits
    Rectangle {
        x: root.vertical ? 0 : Math.round(root.width / 2 - width / 2)
        y: root.vertical ? Math.round(root.height / 2 - height / 2) : 0
        width: root.vertical ? root.width : Math.max(1, Theme.borderWidth)
        height: root.vertical ? Math.max(1, Theme.borderWidth) : root.height
        color: Theme.meterStroke
    }

    Rectangle {
        // never shorter than it is thick, so a nudge still reads
        property real span: root.amount === 0 ? 0
            : Math.max(root.thickness, root.length / 2 * Math.abs(root.amount))
        readonly property real start: root.amount < 0 ? root.length / 2 - span : root.length / 2
        x: root.vertical ? 0 : start
        y: root.vertical ? start : 0
        width: root.vertical ? root.width : span
        height: root.vertical ? span : root.height
        radius: root.radius
        color: root.fillColor

        Behavior on span { NumberAnimation { duration: Theme.durSlow; easing.type: Theme.ease } }
    }
}
