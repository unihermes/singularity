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
    // a quiet word before the last of those glyphs, in a fixed column (a
    // network's strength in words beside its bars)
    property string iconsNote: ""
    // a quiet outlined word before everything at the right (Saved)
    property string tag: ""
    // a glyph in a fixed cell before the label (a device's type)
    property string leadingIcon: ""
    // an image in the same cell, for an app's own icon
    property string leadingImage: ""
    // a quieter word straight after the label (a display's connector)
    property string note: ""
    // the note is styled text, for a part drawn brighter (a version's change)
    property bool noteStyled: false
    // the label's fixed width before the note, so notes line up down a
    // list (an alias's command); 0 sizes it to the label
    property real labelColumn: 0
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

    // the row can be dragged: past a few pixels a press becomes a drag,
    // reporting the pointer in window coordinates, and the release is a
    // drop rather than a click ((-1, -1) when the drag was cut short)
    property bool draggable: false
    property bool dragging: false
    signal dragMoved(point at)
    signal dropped(point at)

    // makes the row itself two clicks, for what can't be undone: the first
    // arms it -- alert-red, reading confirmText -- and the second, within
    // three seconds, emits activated()
    property string confirmText: ""
    readonly property bool armed: disarm.running

    // An optional second action (forget a network, remove a device), shown
    // on hover in place of the trailing text: an IconButton in confirm mode,
    // since what it does can't be undone from here. Armed, the label asks.
    property string actionIcon: ""
    property string actionHint: ""
    readonly property bool actionArmed: actionBtn.armed
    signal action()
    // or, for what's easily undone (ignore a package), a chip with this text
    // that acts on the first click
    property string actionText: ""
    // a plain second button before the action, acting on the first click
    // (make a popout a main window)
    property string extraIcon: ""
    signal extra()
    // the entry can't be used right now (a window a popout is blocking):
    // its label and image go quiet, though it still takes clicks
    property bool dimmed: false

    width: parent ? parent.width : 0
    implicitHeight: Theme.rowHeight

    // How the active entry is marked is the style's (Theme.rowMark): a
    // tick on the left edge, or an accent-tinted ground
    readonly property string mark: Theme.rowMark

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -Theme.spaceS
        anchors.rightMargin: -Theme.spaceS
        radius: Theme.radiusInner
        color: root.highlighted && mark === "tint" ? Qt.tint(Theme.panel, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.24))
            : mouse.containsMouse ? Theme.hoverFill : "transparent"
    }

    // left edge tick on the active entry, instead of a fill: a filled row
    // would read as "hovered" next to the hover highlight
    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: -Theme.spaceS
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.indicatorWidth
        height: parent.height - 6
        radius: Theme.pill(width)
        color: Theme.accent

        visible: root.highlighted && root.mark === "tick"
    }

    Image {
        visible: root.leadingImage !== "" && root.leadingIcon === ""
        anchors.centerIn: leadText
        width: Theme.fontBody
        height: width
        sourceSize: Qt.size(width * 2, height * 2)
        source: root.leadingImage
        opacity: root.pulse * (root.dimmed ? 0.45 : 1)
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
        // up to whatever sits at the right; the note takes what's left
        width: Math.max(0, Math.min(root.note === "" ? Infinity
            : root.labelColumn > 0 ? root.labelColumn : labelMetrics.advanceWidth + 1,
            root.labelEnd - Theme.spaceL - x))
        text: root.armed ? root.confirmText
            : root.showAction && root.actionArmed && root.actionHint !== "" ? root.actionHint : root.label
        elide: Text.ElideRight
        color: {
            if (root.alert || root.armed) return Theme.alert
            if (!root.enabled || root.dimmed) return Theme.subtext
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
    readonly property real labelEnd: showAction ? (extraIcon !== "" ? extraBtn.x : actionText !== "" ? actionChip.x : actionBtn.x)
        : badgeTag.visible ? badgeTag.x
        : quietTag.visible ? quietTag.x
        : iconCells.visible ? iconCells.x : trailingText.x

    Text {
        id: noteText
        visible: root.note !== ""
        anchors.left: labelText.right
        anchors.leftMargin: Theme.spaceM
        anchors.baseline: labelText.baseline
        width: Math.max(0, root.labelEnd - Theme.spaceL - x)
        elide: Text.ElideRight
        // on the one line: a phone notification's text comes with its newlines
        text: root.noteStyled ? root.note : root.note.replace(/\s+/g, " ")
        maximumLineCount: 1
        textFormat: root.noteStyled ? Text.StyledText : Text.PlainText
        color: Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontCaption
        font.weight: Theme.weightBody
        opacity: root.pulse
    }

    HoverHandler { id: rowHover }
    readonly property bool showAction: (actionIcon !== "" || actionText !== "") && enabled && !busy && (rowHover.hovered || actionArmed)

    Row {
        id: iconCells
        visible: !root.showAction && root.trailing === "" && root.trailingIcons.length > 0
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        opacity: root.pulse

        Repeater {
            id: iconRep
            model: root.trailingIcons

            Row {
                required property string modelData
                required property int index

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.iconsNote !== "" && index === iconRep.count - 1
                    width: Theme.fit(52)
                    horizontalAlignment: Text.AlignRight
                    rightPadding: Theme.spaceS
                    text: root.iconsNote
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontSmall
                    font.weight: Theme.weightBody
                }
                Text {
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
    }

    Rectangle {
        id: quietTag
        visible: root.tag !== "" && !root.showAction
        anchors.right: iconCells.visible ? iconCells.left : trailingText.left
        anchors.rightMargin: Theme.spaceL
        anchors.verticalCenter: parent.verticalCenter
        width: tagText.implicitWidth + Theme.spaceM * 2
        height: tagText.implicitHeight + Theme.spaceXs
        radius: Theme.radiusSmall
        color: "transparent"
        border.width: Theme.borderWidth
        border.color: Theme.stroke

        Text {
            id: tagText
            anchors.centerIn: parent
            text: root.tag
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontCaption
            font.weight: Theme.weightBody
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
        preventStealing: root.draggable
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        property point pressAt: Qt.point(0, 0)
        // a drop's release still clicks; this keeps it from activating
        property bool dropped: false

        onPressed: mouse => {
            pressAt = Qt.point(mouse.x, mouse.y)
            dropped = false
        }
        onPositionChanged: mouse => {
            if (!pressed || !root.draggable) return
            // a few pixels of slop, so a shaky click stays a click
            if (!root.dragging && Math.abs(mouse.x - pressAt.x) < 6 && Math.abs(mouse.y - pressAt.y) < 6) return
            root.dragging = true
            root.dragMoved(mapToItem(null, mouse.x, mouse.y))
        }
        onReleased: mouse => {
            if (!root.dragging) return
            root.dragging = false
            dropped = true
            root.dropped(mapToItem(null, mouse.x, mouse.y))
        }
        onCanceled: if (root.dragging) {
            root.dragging = false
            root.dropped(Qt.point(-1, -1))
        }
        onClicked: {
            if (dropped) return
            if (root.confirmText !== "" && !disarm.running) { disarm.restart(); return }
            disarm.stop()
            root.activated()
        }
    }

    Timer { id: disarm; interval: 3000 }

    // after the row's MouseArea, so it sits on top and takes its own clicks
    IconButton {
        id: actionBtn
        visible: root.showAction && root.actionText === ""
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        icon: root.actionIcon
        confirm: true
        onClicked: root.action()
    }

    IconButton {
        id: extraBtn
        visible: root.showAction && root.extraIcon !== ""
        anchors.right: root.actionText !== "" ? actionChip.left : actionBtn.left
        anchors.rightMargin: Theme.spaceXs
        anchors.verticalCenter: parent.verticalCenter
        icon: root.extraIcon
        onClicked: root.extra()
    }

    FlyoutChip {
        id: actionChip
        visible: root.showAction && root.actionText !== ""
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.actionText
        onClicked: root.action()
    }
}
