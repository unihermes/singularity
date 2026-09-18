// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutAction.qml
//
// One Quick Actions row: an icon, a label, an optional status line under it,
// and -- for toggles -- a switch on the right.
//
// Toggles and momentary buttons share this one component rather than the
// buttons being plain FlyoutRows: FlyoutRow has no icon column, so the
// screenshot and picker rows would sit a glyph-width left of the toggles
// above them and the whole page would read as two lists glued together.
//
// The switch mirrors state, it doesn't own it. `checked` is bound to the
// real thing (iwd's Powered, the adapter, the sink), and a click only emits
// activated() -- so a toggle that fails, or that something else flips,
// shows the truth instead of what was last clicked.

import QtQuick
import "../services"

Item {
    id: root

    property string icon: ""
    property string label: ""
    // second line: SSID, device name, volume. Empty collapses the row to
    // a single line.
    property string status: ""
    // false = momentary button: no switch, the row itself is the action
    property bool checkable: true
    property bool checked: false
    property bool enabled: true
    // a glyph in the switch's place on a non-checkable row, e.g. a lock on
    // a setting that can't be turned off
    property string trailingIcon: ""

    signal activated()

    width: parent ? parent.width : 0
    implicitHeight: status !== "" ? Theme.row(36) : Theme.rowHeightTall

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -Theme.spaceS
        anchors.rightMargin: -Theme.spaceS
        radius: Theme.radiusInner
        color: (root.enabled && mouse.containsMouse) ? Theme.hoverFill : "transparent"
    }

    // Fixed-width icon column, so labels line up whatever the glyph's own
    // advance is -- Nerd Font icons vary from 9 to 17px wide.
    Item {
        id: iconCell
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconCell
        height: parent.height

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: !root.enabled ? Theme.textDisabled
                : (root.checkable && !root.checked) ? Theme.subtext
                : Theme.textStrong
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontIconSize
        }
    }

    Column {
        anchors.left: iconCell.right
        anchors.leftMargin: Theme.spaceL
        anchors.right: root.checkable ? toggle.left
            : (root.trailingIcon !== "" ? trailing.left : parent.right)
        anchors.rightMargin: Theme.spaceL
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: root.label
            elide: Text.ElideRight
            color: !root.enabled ? Theme.subtext
                : mouse.containsMouse ? Theme.textStrong
                : Theme.text
            font.family: Theme.fontText
            font.pixelSize: Theme.fontBody
        }

        Text {
            visible: root.status !== ""
            width: parent.width
            text: root.status
            elide: Text.ElideRight
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontSmall
        }
    }

    // The switch. Lightness carries on/off, as everywhere else in the shell:
    // a bright track with a dark knob is on, a dark track with a dim knob off.
    Rectangle {
        id: toggle
        visible: root.checkable
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.fs(26)
        height: Theme.fs(14)
        radius: Math.min(height / 2, Theme.radius)
        color: root.checked ? Theme.meterFill : Theme.fieldFill
        border.width: Theme.borderWidth
        border.color: root.checked ? Theme.meterFill : Theme.stroke

        Behavior on color { ColorAnimation { duration: Theme.durFast } }

        Rectangle {
            width: parent.height - 6
            height: width
            radius: Math.min(width / 2, Theme.radiusSmall)
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Theme.base : Theme.muted

            Behavior on x { NumberAnimation { duration: Theme.durFast; easing.type: Theme.ease } }
        }
    }

    Text {
        id: trailing
        visible: !root.checkable && root.trailingIcon !== ""
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceM
        anchors.verticalCenter: parent.verticalCenter
        text: root.trailingIcon

        color: Theme.muted
        font.family: Theme.fontIcon
        font.pixelSize: Theme.fontIconSize
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: root.enabled
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
