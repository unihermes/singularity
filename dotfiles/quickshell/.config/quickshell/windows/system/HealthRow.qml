// Singularity - Quickshell
// ~/.config/quickshell/windows/system/HealthRow.qml
//
// A Health check: a status dot (filled for a problem, hollow for a pass, so
// it reads in grayscale), the check, the finding, and its fix buttons.

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
    // further repairs, [{ id, label }], drawn after the first
    property var more: []
    property bool busy: false
    property bool repairEnabled: true
    // a fix that removes something asks first, reading this
    property string confirmText: ""

    // id is "" for the first repair
    signal repaired(string id)

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
        radius: Theme.pill(width)
        color: root.problem ? root.tone : "transparent"
        border.width: Theme.borderWidth
        border.color: root.tone
    }

    Column {
        anchors.left: dot.right
        anchors.leftMargin: Theme.spaceXl
        anchors.right: fixes.left
        anchors.rightMargin: Theme.spaceL
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: root.label
            elide: Text.ElideRight
            color: root.problem ? Theme.textStrong : Theme.text
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontBody
        }

        Text {
            width: parent.width
            visible: root.detail !== ""
            text: root.busy ? "working…" : root.detail
            elide: Text.ElideRight
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
    }

    Row {
        id: fixes
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceS

        FlyoutChip {
            visible: root.repairLabel !== ""
            text: root.repairLabel
            confirmText: root.confirmText
            enabled: root.repairEnabled && !root.busy
            onClicked: root.repaired("")
        }

        Repeater {
            model: root.more

            FlyoutChip {
                required property var modelData
                text: modelData.label
                enabled: root.repairEnabled && !root.busy
                onClicked: root.repaired(modelData.id)
            }
        }
    }
}
