// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutRow.qml
//
// One line in a flyout: a label, an optional right-aligned value, and a
// click. Rows that are pure readout (battery health, time remaining) set
// `enabled: false` -- that drops the hover highlight and the pointer
// cursor so they don't advertise a click that does nothing.

import QtQuick
import "../services"

Item {
    id: root

    property string label: ""
    property string trailing: ""
    // marks the current/active entry (connected network, paired device)
    property bool highlighted: false
    property bool enabled: true
    // the trailing text is the row's current setting (Top, Grayscale), not
    // a chevron or tick, so it reads like a stepper's value
    property bool trailingIsValue: false
    // something is in flight (connecting, pairing): the trailing text
    // pulses until it settles, and the row stops taking clicks
    property bool busy: false

    signal activated()

    // An optional second action (forget a network, remove a device), shown
    // on hover in place of the trailing text. Two clicks, since what it does
    // can't be undone from here: the first arms it -- the icon turns into a
    // red check -- and the second confirms. Disarms itself after 3s.
    property string actionIcon: ""
    property string actionHint: ""
    readonly property bool actionArmed: actionDisarm.running
    signal action()

    width: parent ? parent.width : 0
    implicitHeight: Theme.rowHeight

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -Theme.spaceS
        anchors.rightMargin: -Theme.spaceS
        radius: Theme.radiusInner
        color: (root.enabled && mouse.containsMouse) ? Theme.hoverFill : "transparent"
    }

    // left edge tick on the active entry, instead of a fill: a filled row
    // would read as "hovered" next to the hover highlight
    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: -Theme.spaceS
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.indicatorWidth
        height: parent.height - 6
        radius: width / 2
        color: Theme.accent

        visible: root.highlighted
    }

    Text {
        id: labelText
        anchors.left: parent.left
        anchors.leftMargin: root.highlighted ? Theme.spaceM : 0
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: root.showAction ? actionBtn.left : trailingText.left
        anchors.rightMargin: Theme.spaceL
        text: root.showAction && root.actionArmed && root.actionHint !== "" ? root.actionHint : root.label
        elide: Text.ElideRight
        color: {
            if (!root.enabled) return Theme.subtext
            if (root.highlighted || mouse.containsMouse) return Theme.textStrong
            return Theme.text
        }
        font.family: Theme.fontText
        font.pixelSize: Theme.fontBody
    }

    HoverHandler { id: rowHover }
    readonly property bool showAction: actionIcon !== "" && enabled && (rowHover.hovered || actionArmed)

    Text {
        id: trailingText
        visible: !root.showAction
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.trailing
        // On a readout row (battery health, humidity) the trailing text is
        // the information itself, so it reads at text weight. On a clickable
        // row it's decoration -- a chevron, a check -- and stays quiet.
        color: root.trailingIsValue ? Theme.textStrong
            : root.enabled ? Theme.muted : Theme.text
        // icon glyphs turn up here (the check/ban marks on toggle rows),
        // and this is the one font that has them
        font.family: Theme.fontIcon
        font.pixelSize: Theme.fontBody

        SequentialAnimation on opacity {
            running: root.busy
            loops: Animation.Infinite
            // back to solid when it stops, not frozen mid-fade
            onRunningChanged: if (!running) trailingText.opacity = 1
            NumberAnimation { to: 0.3; duration: Theme.durPulse; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: Theme.durPulse; easing.type: Easing.InOutSine }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: root.enabled
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    Timer { id: actionDisarm; interval: 3000 }

    // after the row's MouseArea, so it sits on top and takes its own clicks
    Rectangle {
        id: actionBtn
        visible: root.showAction
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.fs(22)
        height: parent.height - 4
        radius: Theme.radiusInner
        color: root.actionArmed ? Theme.alert
            : actionMouse.containsMouse ? Theme.hoverFillSoft : "transparent"

        Text {
            anchors.centerIn: parent
            text: root.actionArmed ? "󰄬" : root.actionIcon
            color: root.actionArmed ? Theme.base
                : actionMouse.containsMouse ? Theme.textStrong : Theme.muted

            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontBody
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!root.actionArmed) { actionDisarm.restart(); return }
                actionDisarm.stop()
                root.action()
            }
        }
    }
}
