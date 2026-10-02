// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/Choice.qml
//
// One chip per value of a Settings choice, lit on the current one.
// Past four values the row runs out of room, so those are a dropdown.
// Both mark the field they sit in as holding a look's setting (lookKey).

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

SettingsDropdown {
    // the Appearance page this sits on, found by walking up
    readonly property Item page: {
        for (var p = parent; p; p = p.parent)
            if (p.isSettingsPage === true) return p
        return null
    }

    property string key: ""
    Component.onCompleted: page.markField(this, key)
    anchors.right: parent.right
    model: Settings.choices[key] || []
    current: Settings[key]
    labelFor: v => page.label(v, key)
    onPicked: v => Settings.set(key, v)
}
