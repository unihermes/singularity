// A Settings integer, stepped by `step` and clamped by Settings.limits;
// `slider` shows it as a slider, written when the drag ends.

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
    property bool slider: false
    defaultKey: key

    SlideControl {
        visible: st.slider
        anchors.left: parent.left
        anchors.right: parent.right
        value: Settings[st.key] || 0
        minimum: (Settings.limits[st.key] || { min: 0 }).min
        maximum: (Settings.limits[st.key] || { max: 0 }).max
        step: st.step
        suffix: st.suffix
        onCommitted: v => Settings.set(st.key, v)
    }

    FlyoutStepper {
        visible: !st.slider
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
