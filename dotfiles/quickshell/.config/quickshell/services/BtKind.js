// Singularity - Quickshell
// ~/.config/quickshell/services/BtKind.js
//
// What a Bluetooth device is, from the icon name BlueZ derives from its
// device class ("audio-headphones", "input-mouse"): a glyph and a word for
// the Settings page's rows. Also the battery glyph for a level.

.pragma library

const kinds = {
    "audio-headphones":  [0xF02CB, "Headphones"],
    "audio-headset":     [0xF02CE, "Headset"],
    "audio-card":        [0xF04C3, "Speaker"],
    "phone":             [0xF03F2, "Phone"],
    "input-mouse":       [0xF037D, "Mouse"],
    "input-keyboard":    [0xF030C, "Keyboard"],
    "input-gaming":      [0xF0297, "Controller"],
    "input-tablet":      [0xF04F7, "Tablet"],
    "computer":          [0xF0322, "Computer"],
    "video-display":     [0xF0379, "Display"],
    "camera-video":      [0xF0567, "Camera"],
    "camera-photo":      [0xF0100, "Camera"],
    "printer":           [0xF042A, "Printer"],
}

const other = [0xF00AF, "Device"]

function glyph(icon) { return String.fromCodePoint((kinds[icon] || other)[0]) }
function word(icon) { return (kinds[icon] || other)[1] }

function battery(pct) {
    return String.fromCodePoint(pct >= 90 ? 0xF0079 : pct >= 70 ? 0xF0080
        : pct >= 50 ? 0xF007E : pct >= 30 ? 0xF007C : 0xF007A)
}

// the adapter's own: off, on, on with something connected
const adapterOff = String.fromCodePoint(0xF00B2)
const adapterOn = String.fromCodePoint(0xF00AF)
const adapterLinked = String.fromCodePoint(0xF00B1)
const rename = String.fromCodePoint(0xF03EB)
const scanning = String.fromCodePoint(0xF0450)
