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
    // an image before the label and hint (an app's icon)
    property string image: ""
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

    // the page, found by walking up, to ring a searched field (not named
    // `page`, which would shadow every page's own id)
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
    // small items on the label's line, after it (an icon theme's samples)
    property alias labelExtras: extras.data

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

    Image {
        id: leadImage
        visible: root.image !== ""
        anchors.verticalCenter: parent.verticalCenter
        width: visible ? Theme.iconCell : 0
        height: width
        sourceSize: Qt.size(width * 2, height * 2)
        source: root.image
    }

    Column {
        id: labels
        anchors.left: leadImage.visible ? leadImage.right : parent.left
        anchors.leftMargin: leadImage.visible ? Theme.spaceM : 0
        width: root.labelWidth - Theme.spaceXl - x

        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        // the label, the mark of a change from the look, and anything shown
        // after them (`labelExtras`)
        Item {
            width: parent.width
            height: Math.max(labelText.implicitHeight, extras.height)

            Text {
                id: labelText
                // room for the dot only: the mark's wider hover text runs
                // on over the hint rather than eliding the label
                width: Math.min(implicitWidth, parent.width - (resetMark.visible ? Theme.fs(14) + Theme.spaceS : 0))
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
                // under the pointer, what clicking puts back
                text: !resetMouse.containsMouse ? "●"
                    : "󰑓 " + (Settings.baselineIsDefault ? Settings.choiceLabel(Settings.style, "style") + " default" : Settings.choiceLabel(Settings.look))
                      + (root.hostPage && root.hostPage.valueText
                         ? ": " + root.hostPage.valueText(root.lookKey, Settings.lookBaseline[root.lookKey]) : "")
                color: resetMouse.containsMouse ? Theme.textStrong : Theme.accent
                font.family: Theme.fontIcon
                font.pixelSize: resetMouse.containsMouse ? Theme.fontSmall : Theme.fontCaption
                z: 1

                Rectangle {
                    visible: resetMouse.containsMouse
                    anchors.fill: parent
                    anchors.margins: -Theme.spaceXs
                    z: -1
                    radius: Theme.radiusSmall
                    color: Theme.surface
                    border.width: Theme.borderWidth
                    border.color: Theme.accent
                }

                MouseArea {
                    id: resetMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Settings.resetLookKey(root.lookKey)
                }
            }

            Row {
                id: extras
                anchors.left: resetMark.visible ? resetMark.right : labelText.right
                anchors.leftMargin: Theme.spaceL
                anchors.verticalCenter: labelText.verticalCenter
                spacing: Theme.spaceS
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
