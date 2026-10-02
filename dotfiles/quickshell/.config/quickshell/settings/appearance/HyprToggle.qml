// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/HyprToggle.qml
//

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

SettingsField {
    id: ht
    readonly property Item page: hostPage

    property var path: []
    property string key: ""
    readonly property var field: page.hyprField(path, key)

    hint: field.editable ? note : "Not a plain value in hyprland.lua"
    property string note: ""

    Switch {
        anchors.right: parent.right
        checked: ht.field.value === true
        enabled: ht.field.editable
        onToggled: page.setHypr(ht.path, ht.key, !checked, ht.label + " " + (checked ? "off" : "on"))
    }
}
