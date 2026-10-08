// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/StyleOption.qml
//
// One of the current style's own options (Styles.js `options`) as a
// switch: a shared Finish setting when the option names a `key`, or an id
// in Settings.styleOptions.

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

SettingsField {
    id: so
    // the option's entry in Styles.js
    property var option: ({})
    readonly property string key: option.key || ""
    readonly property bool on: key === "" ? Theme.opt(option.id)
        : option.value !== undefined ? Settings[key] === option.value : !!Settings[key]

    label: option.label || ""
    hint: option.hint || ""
    lookKey: key !== "" ? key : "styleOptions"

    Switch {
        anchors.right: parent.right
        checked: so.on
        onToggled: {
            if (so.key === "") Settings.setStyleOption(so.option.id, !so.on)
            else if (so.option.value !== undefined) Settings.set(so.key, so.on ? "none" : so.option.value)
            else Settings.set(so.key, !so.on)
        }
    }
}
