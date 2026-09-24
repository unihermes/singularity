// Singularity - Quickshell
// ~/.config/quickshell/settings/Keycaps.qml
//
// A Hyprland combo ("SUPER + SHIFT + Return") drawn as a row of keycaps,
// with each key under the name a person would give it: Enter, not Return;
// Left click, not mouse:272.

import QtQuick
import "../services"

Row {
    id: root

    // as HyprBinds writes it: keys joined by " + "
    property string keys: ""
    // the combo clashes with another bind
    property bool alert: false
    // already in the config, so shown quieter
    property bool dim: false

    spacing: Theme.spaceXs

    readonly property var names: ({
        SUPER: "Super", CTRL: "Ctrl", ALT: "Alt", SHIFT: "Shift", MOD5: "AltGr",
        SPACE: "Space", space: "Space", Return: "Enter", Escape: "Esc", Tab: "Tab",
        BackSpace: "Backspace", Delete: "Del", Insert: "Ins", Print: "PrtSc",
        Page_Up: "PgUp", Page_Down: "PgDn",
        left: "←", right: "→", up: "↑", down: "↓",
        equal: "=", minus: "-", comma: ",", period: ".", slash: "/", backslash: "\\",
        semicolon: ";", apostrophe: "'", grave: "`", bracketleft: "[", bracketright: "]",
        "mouse:272": "Left click", "mouse:273": "Right click", "mouse:274": "Middle click",
        mouse_up: "Scroll up", mouse_down: "Scroll down",
        "switch:on:Lid Switch": "Lid closed", "switch:off:Lid Switch": "Lid opened",
        XF86AudioRaiseVolume: "Volume +", XF86AudioLowerVolume: "Volume -",
        XF86AudioMute: "Mute", XF86AudioMicMute: "Mic mute",
        XF86MonBrightnessUp: "Brightness +", XF86MonBrightnessDown: "Brightness -",
        XF86AudioPlay: "Play", XF86AudioPause: "Pause", XF86AudioStop: "Stop",
        XF86AudioNext: "Next", XF86AudioPrev: "Previous",
    })

    function label(key) {
        if (names[key] !== undefined) return names[key]
        if (key.indexOf("XF86") === 0) return key.slice(4)
        return key.length === 1 ? key.toUpperCase() : key
    }

    Repeater {
        model: root.keys.split("+").map(k => k.trim()).filter(k => k !== "")

        Rectangle {
            required property string modelData

            width: cap.implicitWidth + Theme.spaceM * 2
            height: cap.implicitHeight + Theme.spaceXs * 2
            radius: Theme.radiusInner
            color: Theme.fieldFill
            border.width: Theme.borderWidth
            border.color: root.alert ? Theme.alert : Theme.stroke

            Text {
                id: cap
                anchors.centerIn: parent
                text: root.label(parent.modelData)
                color: root.alert ? Theme.alert : root.dim ? Theme.subtext : Theme.textStrong
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
            }
        }
    }
}
