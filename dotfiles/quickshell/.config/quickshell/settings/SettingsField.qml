// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsField.qml
//
// One setting on a Settings page: a label with an optional hint under it on
// the left, and whatever controls it on the right (chips, a stepper's
// buttons, a slider, a field). Rows grow to fit a hint or a wrapping Flow of
// chips rather than clipping them.

import QtQuick
import "../services"

Item {
    id: root

    property string label: ""
    property string hint: ""
    // width of the label column; controls get the rest
    property int labelWidth: Theme.fs(240)
    readonly property bool isSettingsField: true

    // The page a search result landed on rings the field it named. Found by
    // walking up rather than passed in, so no page has to thread it through.
    // named for what it is rather than `page`, which every Settings page
    // already uses as its own id -- a property here would shadow it inside
    // any field the page declares
    readonly property var hostPage: {
        var p = parent
        while (p) {
            if (p.isSettingsPage === true) return p
            p = p.parent
        }
        return null
    }
    readonly property bool lit: hostPage !== null && root.label !== ""
        && hostPage.highlight === root.label

    default property alias control: slot.data

    width: parent ? parent.width : 0
    implicitHeight: Math.max(Theme.fieldHeight, labels.implicitHeight + Theme.spaceM, slot.childrenRect.height + Theme.spaceM)

    // the ring: sized past the row's edges so it reads as around the
    // setting, not as another control in it
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -Theme.spaceS
        anchors.rightMargin: -Theme.spaceS
        radius: Theme.radiusInner
        color: Theme.selectedFill
        border.width: Theme.borderWidth
        border.color: Theme.accent
        opacity: root.lit ? 1 : 0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: Theme.dur(180); easing.type: Theme.ease } }
    }

    Column {
        id: labels
        width: root.labelWidth - Theme.spaceXl

        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: root.label
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.fontText
            font.pixelSize: Theme.fontBody
        }

        Text {
            width: parent.width
            visible: root.hint !== ""
            text: root.hint
            wrapMode: Text.WordWrap
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontSmall
        }
    }

    // controls are right-aligned by their own anchors inside this slot
    Item {
        id: slot
        anchors.left: parent.left
        anchors.leftMargin: root.labelWidth
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: childrenRect.height
    }
}
