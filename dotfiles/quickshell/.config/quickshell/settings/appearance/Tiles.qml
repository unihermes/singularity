// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/Tiles.qml
//
// A choice judged by eye: one tile per value, each drawing what it does,
// the current one lit. `art` is a Component reading `parent.value`.

import Quickshell
import QtQuick
import "../../services/Looks.js" as Looks
import "../../services"
import "../../flyouts"
import ".."

Column {
    id: tl
    // the Appearance page this sits on, found by walking up
    readonly property Item page: {
        for (var p = parent; p; p = p.parent)
            if (p.isSettingsPage === true) return p
        return null
    }

    property string key: ""
    property string label: ""
    property string hint: ""
    property Component art: null
    property int columns: 4
    width: parent ? parent.width : 0
    spacing: Theme.spaceXs

    SettingsField {
        label: tl.label
        hint: tl.hint
        lookKey: Looks.looks[Looks.fallback].settings[tl.key] !== undefined ? tl.key : ""
    }

    SettingsTiles {
        columns: tl.columns
        model: (Settings.choices[tl.key] || []).map(v => ({ value: v, text: page.label(v, tl.key) }))
        current: Settings[tl.key]
        art: tl.art
        onPicked: v => {
            page.holdInPlace(tl)
            Settings.set(tl.key, v)
        }
    }
}
