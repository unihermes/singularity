// Singularity - Quickshell
// ~/.config/quickshell/windows/system/HealthRow.qml
//
// One check on the Health page: a status dot, what was checked, what was
// found under it, and -- when there is one -- the button that fixes it.
//
// The dot carries the status on its own rather than colouring the label:
// every other row in this window uses label colour for emphasis, and a red
// label here would read as "this row is important" instead of "this is the
// broken one". A grayscale palette has no red to lean on anyway, so the dot
// is filled for a problem and hollow for a pass, which survives both.

import QtQuick
import "../../services"
import "../../flyouts"

Item {
    id: root

    // "ok" | "warn" | "bad"
    property string status: "ok"
    property string label: ""
    property string detail: ""
    property string repairLabel: ""
    property bool busy: false
    property bool repairEnabled: true

    signal repaired()

    readonly property bool problem: status !== "ok"
    readonly property color tone: status === "bad" ? Theme.alert
        : status === "warn" ? Theme.text
        : Theme.good

    width: parent ? parent.width : 0
    height: Theme.row(40)

    Rectangle {
        id: dot
        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceS
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.fs(8)
        height: width
        radius: width / 2
        color: root.problem ? root.tone : "transparent"
        border.width: Theme.borderWidth
        border.color: root.tone
    }

    Column {
        anchors.left: dot.right
        anchors.leftMargin: Theme.spaceXl
        anchors.right: fix.visible ? fix.left : parent.right
        anchors.rightMargin: Theme.spaceL
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: root.label
            elide: Text.ElideRight
            color: root.problem ? Theme.textStrong : Theme.text
            font.family: Theme.fontText
            font.pixelSize: Theme.fontBody
        }

        Text {
            width: parent.width
            visible: root.detail !== ""
            text: root.busy ? "working…" : root.detail
            elide: Text.ElideRight
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontSmall
        }
    }

    FlyoutChip {
        id: fix
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: root.repairLabel !== ""
        text: root.repairLabel
        enabled: root.repairEnabled && !root.busy
        onClicked: root.repaired()
    }
}
