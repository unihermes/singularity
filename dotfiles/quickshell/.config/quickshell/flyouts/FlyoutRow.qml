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
    // Glyphs in fixed-width cells at the right, in place of `trailing` while
    // that's empty: marks that have to line up down a list (a network's lock
    // and strength). "" leaves its cell blank.
    property var trailingIcons: []
    // a glyph in a fixed cell before the label (a device's type)
    property string leadingIcon: ""
    // an image in the same cell, for an app's own icon
    property string leadingImage: ""
    // a quieter word straight after the label (a display's connector)
    property string note: ""
    // a word in an accent tag before the trailing text (Primary)
    property string badge: ""
    // something is in flight (connecting, pairing, a rescan): the row's
    // text pulses until it settles, and the row stops taking clicks
    property bool busy: false
    // pulses like busy but still takes clicks, for work the same row
    // stops (a Bluetooth scan)
    property bool pulsing: busy
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

    Image {
        visible: root.leadingImage !== "" && root.leadingIcon === ""
        anchors.centerIn: leadText
        width: Theme.fontBody
        height: width
        sourceSize: Qt.size(width * 2, height * 2)
        source: root.leadingImage
        opacity: root.pulse
    }

    Text {
        id: leadText
        visible: root.leadingIcon !== "" || root.leadingImage !== ""
        anchors.left: parent.left
        anchors.leftMargin: root.highlighted ? Theme.spaceM : 0
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconCell
        horizontalAlignment: Text.AlignHCenter
        text: root.leadingIcon
        color: labelText.color
        font.family: Theme.fontIcon
        font.pixelSize: Theme.fontBody
        font.weight: Theme.weightBody
        opacity: root.pulse
    }

    Text {
        id: labelText
        anchors.left: leadText.visible ? leadText.right : parent.left
        anchors.leftMargin: leadText.visible ? Theme.spaceM : root.highlighted ? Theme.spaceM : 0
        anchors.verticalCenter: parent.verticalCenter
        // up to whatever sits at the right, leaving the note its room
        width: Math.max(0, Math.min(root.note === "" ? Infinity : labelMetrics.advanceWidth + 1,
            root.labelEnd - Theme.spaceL - x - (noteText.visible ? noteText.implicitWidth + Theme.spaceM : 0)))
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
        font.weight: Theme.weightBody
        opacity: root.pulse
    }

    // the label's full width, which an eliding Text's own implicitWidth
    // can't give without a binding loop
    TextMetrics {
        id: labelMetrics
        font: labelText.font
        text: labelText.text
    }

    // where the label's room ends: the first thing at the right
    readonly property real labelEnd: showAction ? actionBtn.x
        : badgeTag.visible ? badgeTag.x
        : iconCells.visible ? iconCells.x : trailingText.x

    Text {
        id: noteText
        visible: root.note !== ""
        anchors.left: labelText.right
        anchors.leftMargin: Theme.spaceM
        anchors.baseline: labelText.baseline
        text: root.note
        color: Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontCaption
        font.weight: Theme.weightBody
        opacity: root.pulse
    }

    HoverHandler { id: rowHover }
    readonly property bool showAction: actionIcon !== "" && enabled && !busy && (rowHover.hovered || actionArmed)

    Row {
        id: iconCells
        visible: !root.showAction && root.trailing === "" && root.trailingIcons.length > 0
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        opacity: root.pulse

        Repeater {
            model: root.trailingIcons

            Text {
                required property string modelData
                width: Theme.iconCell
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: trailingText.color
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontBody
                font.weight: Theme.weightBody
            }
        }
    }

    Rectangle {
        id: badgeTag
        visible: root.badge !== "" && !root.showAction
        anchors.right: trailingText.left
        anchors.rightMargin: root.trailing === "" ? 0 : Theme.spaceL
        anchors.verticalCenter: parent.verticalCenter
        width: badgeText.implicitWidth + Theme.spaceM * 2
        height: badgeText.implicitHeight + Theme.spaceXs
        radius: Theme.radiusSmall
        color: Theme.accent

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: root.badge
            color: Theme.textOnAccent
            font.family: Theme.fontText
            font.pixelSize: Theme.fontCaption
            font.weight: Theme.weightBody
        }
    }

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
        font.weight: Theme.weightBody
        opacity: root.pulse
    }

    property real pulse: 1
    SequentialAnimation on pulse {
        running: root.pulsing
        loops: Animation.Infinite
        // back to solid when it stops, not frozen mid-fade
        onRunningChanged: if (!running) root.pulse = 1
        NumberAnimation { to: 0.3; duration: Theme.durPulse; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: Theme.durPulse; easing.type: Easing.InOutSine }
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
