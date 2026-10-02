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
    // the hint when the value is editable
    property string note: ""
    readonly property var field: page.hyprField(path, key)
    // gaps can be a "top,right,bottom,left" string; that stays hand-edited
    readonly property bool live: field.editable && typeof field.value === "number"

    hint: !field.editable ? "Not a plain value in hyprland.lua"
        : !live ? "Set per side in hyprland.lua (" + field.value + ")" : note

    FlyoutStepper {
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
