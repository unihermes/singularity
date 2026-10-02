// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/PreviewGlyph.qml
//

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

Text {
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    color: Theme.textStrong
    font.family: Theme.fontIcon
    font.pixelSize: Theme.iconSize
}
