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
    // the label reports a failure (a refresh that didn't land)
    property bool alert: false

    signal activated()

    // An optional second action (forget a network, remove a device), shown
    // on hover in place of the trailing text: an IconButton in confirm mode,
    // since what it does can't be undone from here. Armed, the label asks.
    property string actionIcon: ""
    property string actionHint: ""
    readonly property bool actionArmed: actionBtn.armed
    signal action()

    width: parent ? parent.width : 0
    implicitHeight: Theme.rowHeight

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -Theme.spaceS
        anchors.rightMargin: -Theme.spaceS
        radius: Theme.radiusInner
        color: mouse.containsMouse ? Theme.hoverFill : "transparent"
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
            if (root.alert) return Theme.alert
            if (!root.enabled) return Theme.subtext
            if (root.highlighted || mouse.containsMouse) return Theme.textStrong
            return Theme.text
        }
        font.family: Theme.fontText
        font.pixelSize: Theme.fontBody
    }

    HoverHandler { id: rowHover }
    readonly property bool showAction: actionIcon !== "" && enabled && !busy && (rowHover.hovered || actionArmed)

    Text {
        id: trailingText
        visible: !root.showAction
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.trailing
        // On a readout row (battery health, humidity) the trailing text is
        // the information itself, so it reads strong. On a clickable row
        // it's decoration -- a chevron, a check -- and stays quiet; a state
        // in flight (connecting) sits between the two.
        color: root.trailingIsValue ? Theme.textStrong
            : root.busy ? Theme.text
            : root.enabled ? Theme.muted : Theme.textDisabled
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
        hoverEnabled: root.enabled && !root.busy
        enabled: root.enabled && !root.busy
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    // after the row's MouseArea, so it sits on top and takes its own clicks
    IconButton {
        id: actionBtn
        visible: root.showAction
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        icon: root.actionIcon
        confirm: true
        onClicked: root.action()
    }
}
