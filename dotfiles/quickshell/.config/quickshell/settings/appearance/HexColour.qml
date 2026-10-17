// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/HexColour.qml
//
// Settings[key] as any colour, #rrggbb (or #rgb, with or without the
// #), applied on Enter. The swatch beside it previews what's typed while
// it parses; a value set elsewhere (a swatch, a slider, a reset) replaces
// what's typed. `fallback` is the colour shown for "" -- the look's own,
// for a key that takes "" to mean that.

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

SettingsField {
    id: hex
    readonly property Item page: hostPage

    property string key: ""
    property color fallback: "transparent"
    // grayscale only, like the accent: the wallpaper palette brings its own
    property bool grayscaleOnly: true
    readonly property bool live: !grayscaleOnly || Settings.colourMode !== "wallpaper"
    readonly property string value: Settings[key] || ""
    lookKey: key
    hint: !live ? "Grayscale palette only" : "Type a hex colour and press Enter"

    function parse(t) {
        var h = String(t).trim().replace(/^#/, "")
        if (/^[0-9a-fA-F]{3}$/.test(h)) h = h.split("").map(c => c + c).join("")
        return /^[0-9a-fA-F]{6}$/.test(h) ? "#" + h.toLowerCase() : ""
    }

    onValueChanged: hexInput.text = value

    Row {
        id: hexRow
        anchors.right: parent.right
        spacing: Theme.spaceL
        enabled: hex.live
        opacity: enabled ? 1 : 0.4
        readonly property string typed: hex.parse(hexInput.text)

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.chipHeight
            height: Theme.chipHeight
            radius: Theme.radiusSmall
            color: hexRow.typed !== "" ? hexRow.typed : hex.fallback
            border.width: Theme.borderWidth
            border.color: Theme.stroke
        }

        FlyoutInput {
            id: hexInput
            width: Theme.fit(110)
            echoPassword: false
            placeholder: hex.value === "" && hex.fallback.a > 0 ? String(hex.fallback) : "#rrggbb"
            text: hex.value
            onAccepted: {
                if (hexRow.typed === "") {
                    page.say("\"" + text.trim() + "\" isn't a hex colour", true)
                    return
                }
                Settings.set(hex.key, hexRow.typed)
                text = hexRow.typed
                page.say(hex.label + " set to " + hexRow.typed, false)
            }
            onEscapePressed: text = hex.value
        }
    }
}
