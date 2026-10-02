// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/FinishSwitch.qml
//
// A Settings boolean as a switch, resting while the style gives it
// nothing to do

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

SettingsField {
    id: fsw
    property string key: ""
    property bool live: true
    lookKey: key

    Switch {
        anchors.right: parent.right
        enabled: fsw.live
        opacity: fsw.live ? 1 : 0.4
        checked: !!Settings[fsw.key]
        onToggled: Settings.set(fsw.key, !Settings[fsw.key])
    }
}
