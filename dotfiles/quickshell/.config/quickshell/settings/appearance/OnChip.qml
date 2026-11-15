// A Settings boolean as a lit chip, On or Off, at the right of its field.

import QtQuick
import "../../flyouts"

FlyoutChip {
    property bool on: false
    anchors.right: parent ? parent.right : undefined
    text: on ? "On" : "Off"
    icon: on ? "󰄬" : ""
    selected: on
}
