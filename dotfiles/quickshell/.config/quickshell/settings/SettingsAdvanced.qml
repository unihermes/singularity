// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsAdvanced.qml
//
// A section's rarely changed rows, folded behind one "Advanced (n)" row at
// its foot; a search for one of them opens it (SettingsPage.scrollTo). The
// rows stay visible while folded, clipped to nothing, so their own
// `visible` still counts them.

import QtQuick
import "../services"
import "../flyouts"

Column {
    id: root

    default property alias content: rows.data
    property bool open: false
    readonly property bool isAdvancedFold: true
    // the fields showing in here, a Grid's counted one by one
    readonly property int count: tally(rows)

    function tally(item) {
        var n = 0
        for (var i = 0; i < item.children.length; i++) {
            var c = item.children[i]
            if (!c.visible) continue
            n += c.isSettingsField === true ? 1 : tally(c)
        }
        return n
    }

    width: parent ? parent.width : 0

    FlyoutRow {
        visible: root.count > 0
        width: parent.width
        label: "Advanced (" + root.count + ")"
        trailing: root.open ? "󰅀" : "󰅂"
        highlighted: root.open
        onActivated: root.open = !root.open
    }

    Column {
        id: rows
        width: parent.width
        topPadding: root.open ? Theme.spaceM : 0
        height: root.open ? implicitHeight : 0
        clip: true
        spacing: Theme.spaceM
    }
}
