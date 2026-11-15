// A section's picture (PanelArt of `kind`) on the left with its settings
// beside it: put the fields inside, each taking `parent.labelWidth`.

import QtQuick
import "../../services"

Item {
    id: bs
    property string kind: ""
    default property alias rows: col.data
    width: parent ? parent.width : 0
    height: Math.max(pic.height, col.implicitHeight)

    PanelArt {
        id: pic
        kind: bs.kind
        width: Theme.fit(220)
        height: Math.round(width * 0.72)
    }
    Column {
        id: col
        readonly property real labelWidth: Theme.fit(178)
        x: pic.width + Theme.spaceXl
        width: bs.width - x
        spacing: Theme.spaceM
    }
}
