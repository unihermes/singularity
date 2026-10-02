// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/Stepper.qml
//
// A Settings integer, stepped by `step` and clamped by Settings.limits.

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

SettingsField {
    id: st
    readonly property Item page: hostPage

    property string key: ""
    property int step: 1
    property string suffix: ""
    lookKey: key

    FlyoutStepper {
        anchors.right: parent.right
        width: Theme.fit(160)
        // guarded: these can evaluate before `key` is assigned
        value: Settings[st.key] || 0
        minimum: (Settings.limits[st.key] || { min: 0 }).min
        maximum: (Settings.limits[st.key] || { max: 0 }).max
        suffix: st.suffix
        valueWidth: 56
        onStepped: d => {
            page.holdInPlace(st)
            Settings.step(st.key, d * st.step)
        }
    }
}
