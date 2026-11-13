// A 0-1 opacity, shown and stepped as a percentage

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

SettingsField {
    id: hp
    readonly property Item page: hostPage

    property var path: []
    property string key: ""
    property int min: 50
    // a slider, written when the drag ends, in the stepper's place
    property bool slider: false
    readonly property var field: page.hyprField(path, key)
    readonly property bool live: field.editable && typeof field.value === "number"
    readonly property int pct: live ? Math.round(field.value * 100) : 100

    hint: live ? "" : "Not a plain value in looks.lua"

    SlideControl {
        visible: hp.slider
        anchors.left: parent.left
        anchors.right: parent.right
        enabled: hp.live
        value: hp.pct
        minimum: hp.min
        maximum: 100
        step: 5
        suffix: "%"
        onCommitted: v => page.setHypr(hp.path, hp.key, v / 100, hp.label + " " + v + "%")
    }

    FlyoutStepper {
        visible: !hp.slider
        anchors.right: parent.right
        width: Theme.fit(160)
        value: Math.round(hp.pct / 5)
        // min == max when not editable, which greys both buttons
        minimum: hp.live ? Math.round(hp.min / 5) : 20
        maximum: 20
        displayValue: hp.pct + "%"
        valueWidth: 56
        onStepped: d => {
            var p = Math.max(hp.min, Math.min(100, (value + d) * 5))
            page.setHypr(hp.path, hp.key, p / 100, hp.label + " " + p + "%")
        }
    }
}
