// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutAction.qml
//
// An action row: icon, label, optional status, and for toggles a
// switch. Buttons use it too, so every row shares the icon column. The
// switch mirrors `checked` (the real state); a click only emits activated().

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
    // room kept clear left of the switch, for a control laid over the row
    // (Bar Widgets' pin), so the label elides short of it
    property int trailingInset: 0

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
        anchors.rightMargin: Theme.spaceL + root.trailingInset
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
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontBody
        }

        Text {
            visible: root.status !== ""
            width: parent.width
            text: root.status
            elide: Text.ElideRight
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
    }

    // The switch. Lightness carries on/off, as everywhere else in the shell:
    // a bright track with a dark knob is on, a dark track with a dim knob off.
    Switch {
        id: toggle
        visible: root.checkable
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        interactive: false
        checked: root.checked
        enabled: root.enabled
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
