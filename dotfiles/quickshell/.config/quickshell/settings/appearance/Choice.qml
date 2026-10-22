// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/Choice.qml
//
// A Settings choice as a dropdown (Choices is the chip row, for four values
// or fewer). Marks the field it sits in as holding a look's setting.

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
    // set where a setting's values have glyphs to show beside them
    property var glyphs: ({})
    glyphFor: v => glyphs[v] || ""
    onPicked: v => Settings.set(key, v)
}
