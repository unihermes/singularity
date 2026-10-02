// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/Choices.qml
//

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

FlyoutSegmented {
    id: ch
    // the Appearance page this sits on, found by walking up
    readonly property Item page: {
        for (var p = parent; p; p = p.parent)
            if (p.isSettingsPage === true) return p
        return null
    }

    property string key: ""
    property bool live: true
    Component.onCompleted: page.markField(this, key)

    anchors.right: parent.right
    fill: false
    enabled: live
    model: Settings.choices[key] || []
    labelFor: v => page.label(v, key)
    current: Settings[key]
    onPicked: v => {
        page.holdInPlace(ch)
        Settings.set(key, v)
    }
}
