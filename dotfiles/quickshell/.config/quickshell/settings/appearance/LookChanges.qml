// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/LookChanges.qml
//
// The Look tab's list of changes: each setting that differs from the
// look in use, what it is now and what the look has, a way to the field
// and a way back

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

Column {
    // the Appearance page this sits on, found by walking up
    readonly property Item page: {
        for (var p = parent; p; p = p.parent)
            if (p.isSettingsPage === true) return p
        return null
    }

    width: parent.width
    spacing: Theme.spaceM

    // every change at once
    SettingsField {
        label: Settings.baselineIsDefault ? "Back to default" : "Reset look"
        visible: !Settings.lookPristine
        hint: Settings.baselineIsDefault ? "Put all of these back to your saved default"
            : "Put all of these back to " + page.label(Settings.look) + "'s own"

        FlyoutChip {
            anchors.right: parent.right
            text: "Undo all"
            confirmText: "Undo " + Settings.lookDiffs.length + "?"
            onClicked: {
                Settings.undoLookChanges()
                page.say(Settings.baselineIsDefault ? "Saved default restored"
                    : page.label(Settings.look) + " look restored", false)
            }
        }
    }

    Text {
        visible: Settings.lookPristine
        width: parent.width
        wrapMode: Text.WordWrap
        text: Settings.baselineIsDefault
            ? "Nothing changed since you saved your default. Anything you change on the other tabs shows up here."
            : "Nothing changed — " + page.label(Settings.look) + " is as it was designed. Anything you change on the other tabs shows up here."
        color: Theme.subtext
        font.family: Theme.fontText
        font.weight: Theme.weightBody
        font.pixelSize: Theme.fontSmall
    }

    Repeater {
        model: Settings.lookDiffs

        SettingsField {
            id: change
            required property string modelData
            // shares its label with the field it stands for
            searchable: false
            readonly property var lookValue: Settings.lookBaseline[modelData]
            label: page.keyLabels[modelData] || modelData
            hint: "Now " + page.valueText(modelData, Settings[modelData])
                + " · " + (Settings.baselineIsDefault ? "default" : page.label(Settings.look))
                + " has " + page.valueText(modelData, change.lookValue)

            Row {
                anchors.right: parent.right
                spacing: Theme.spaceS
                FlyoutChip {
                    text: "Show"
                    onClicked: page.highlight = change.label
                }
                FlyoutChip {
                    text: "Undo"
                    onClicked: Settings.resetLookKey(change.modelData)
                }
            }
        }
    }
}
