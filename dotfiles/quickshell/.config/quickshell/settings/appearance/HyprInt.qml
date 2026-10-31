// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/HyprInt.qml
//

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

SettingsField {
    id: hi
    readonly property Item page: hostPage

    property var path: []
    property string key: ""
    property int min: 0
    property int max: 20
    property string suffix: "px"
    // a slider, written when the drag ends, in the stepper's place
    property bool slider: false
    // the hint when the value is editable
    property string note: ""
    readonly property var field: page.hyprField(path, key)
    // gaps can be a "top,right,bottom,left" string; that stays hand-edited
    readonly property bool live: field.editable && typeof field.value === "number"

    hint: !field.editable ? "Not a plain value in looks.lua"
        : !live ? "Set per side in looks.lua (" + field.value + ")" : note

    SlideControl {
        visible: hi.slider
        anchors.left: parent.left
        anchors.right: parent.right
        enabled: hi.live
        value: hi.live ? hi.field.value : 0
        minimum: hi.min
        maximum: hi.max
        suffix: hi.suffix === "" ? "" : " " + hi.suffix
        onCommitted: v => page.setHypr(hi.path, hi.key, v, hi.label + " " + v + hi.suffix)
    }

    FlyoutStepper {
        visible: !hi.slider
        anchors.right: parent.right
        width: Theme.fit(160)
        value: hi.live ? hi.field.value : 0
        minimum: hi.live ? hi.min : 0
        maximum: hi.live ? hi.max : 0
        suffix: hi.suffix
        valueWidth: 56
        onStepped: d => page.setHypr(hi.path, hi.key,
            Math.max(hi.min, Math.min(hi.max, value + d)), hi.label + " " + (value + d) + hi.suffix)
    }
}
