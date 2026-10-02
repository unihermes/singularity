// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/HexAccent.qml
//
// Settings[key] as any colour, #rrggbb (or #rgb, with or without the
// #), applied on Enter. The swatch beside it previews what's typed while
// it parses; a swatch picked above replaces what's typed.

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

SettingsField {
    id: hex
    readonly property Item page: hostPage

    property string key: ""
    hint: Settings.colourMode === "wallpaper" ? "Grayscale palette only"
        : "Type a hex colour and press Enter"

    function parse(t) {
        var h = String(t).trim().replace(/^#/, "")
        if (/^[0-9a-fA-F]{3}$/.test(h)) h = h.split("").map(c => c + c).join("")
        return /^[0-9a-fA-F]{6}$/.test(h) ? "#" + h.toLowerCase() : ""
    }

    Row {
        id: hexRow
        anchors.right: parent.right
        spacing: Theme.spaceL
        enabled: Settings.colourMode !== "wallpaper"
        opacity: enabled ? 1 : 0.4
        readonly property string typed: hex.parse(hexInput.text)

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.chipHeight
            height: Theme.chipHeight
            radius: Theme.radiusSmall
            color: hexRow.typed !== "" ? hexRow.typed : "transparent"
            border.width: Theme.borderWidth
            border.color: Theme.stroke
        }

        FlyoutInput {
            id: hexInput
            width: Theme.fit(110)
            echoPassword: false
            placeholder: "#rrggbb"
            text: Settings[hex.key] || ""
            onAccepted: {
                if (hexRow.typed === "") {
                    page.say("\"" + text.trim() + "\" isn't a hex colour", true)
                    return
                }
                Settings.set(hex.key, hexRow.typed)
                text = hexRow.typed
                page.say(hex.label + " set to " + hexRow.typed, false)
            }
            onEscapePressed: text = Settings[hex.key] || ""

            // typing breaks the binding; follow a swatch picked above
            Connections {
                target: Settings
                function onAccentChanged() { if (hex.key === "accent") hexInput.text = Settings.accent }
            }
        }
    }
}
