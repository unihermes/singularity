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
    // a glyph before the label (a battery or plug), and a row that's off
    property string mark: ""
    property bool dimmed: false
    // A setting the look carries (Looks.js `settings`): while it differs
    // from the look's own value the label is marked, and the mark puts it
    // back. "" for a field that isn't one.
    property string lookKey: ""
    readonly property bool modified: lookKey !== "" && Settings.lookDiffs.indexOf(lookKey) !== -1
    // width of the label column; controls get the rest. A redesigned page
    // (SettingsPage.sectioned) widens it and keeps hints to one line.
    property int labelWidth: hostPage && hostPage.sectioned ? Theme.fit(320) : Theme.fit(240)
    readonly property bool oneLineHint: !!hostPage && hostPage.sectioned
    readonly property bool isSettingsField: true
    // false for a row that only repeats another field's label (the
    // Appearance page's list of changes), so a search lands on the field
    property bool searchable: true

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

        // the label, and the mark of a change from the look
        Item {
            width: parent.width
            height: labelText.implicitHeight

            Text {
                id: labelText
                width: Math.min(implicitWidth, parent.width - (resetMark.visible ? resetMark.width + Theme.spaceS : 0))
                text: (root.mark !== "" ? root.mark + "  " : "") + root.label
                elide: Text.ElideRight
                color: root.dimmed ? Theme.subtext : Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.fontBody
                font.weight: Theme.weightBody
            }

            Text {
                id: resetMark
                visible: root.modified
                anchors.left: labelText.right
                anchors.leftMargin: Theme.spaceS
                anchors.verticalCenter: labelText.verticalCenter
                text: !resetMouse.containsMouse ? "●"
                    : Settings.baselineIsDefault ? "󰑓 default" : "󰑓 " + Settings.choiceLabel(Settings.look) + "'s"
                color: Theme.accent
                font.family: Theme.fontIcon
                font.pixelSize: resetMouse.containsMouse ? Theme.fontSmall : Theme.fontCaption

                MouseArea {
                    id: resetMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Settings.resetLookKey(root.lookKey)
                }
            }
        }

        Text {
            width: parent.width
            visible: root.hint !== ""
            text: root.hint
            wrapMode: root.oneLineHint ? Text.NoWrap : Text.WordWrap
            elide: root.oneLineHint ? Text.ElideRight : Text.ElideNone
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontSmall
            font.weight: Theme.weightBody
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
