// Singularity - Quickshell
// ~/.config/quickshell/windows/System.qml
//
// System: live usage gauges with per-core bars and 60-second history,
// network throughput, the heaviest processes, static facts, hardware specs
// and config shortcuts, in one standalone window opened from the Control
// Centre. Appearance settings are deliberately not duplicated here -- they
// live on the Appearance page.
//
// This file is the window and its three-column layout. The numbers come from
// services/SystemStats.qml, which only samples while this window is visible;
// each column is its own file under system/.

import Quickshell
import QtQuick
import "../services"
import "system"
import "../flyouts"

CentredWindow {
    id: root

    heading: "SYSTEM"
    contentWidth: col1Width + col2Width + col3Width + 2 * colGap

    // uneven on purpose: column 3 carries the longest static strings (GPU
    // model, board vendor+product, monitor list) and was clipping its own
    // values against the window edge at a uniform width -- the graphs and
    // gauges in column 1 need far less room than that text does.
    readonly property int col1Width: Theme.fs(300)
    readonly property int col2Width: Theme.fs(320)
    readonly property int col3Width: Theme.fs(420)
    readonly property int colGap: Theme.sp(24)

    SystemStats {
        id: stats
        active: root.visible
    }

    // --- layout ----------------------------------------------------------

    // The three-column grid runs taller than the window once every section
    // is populated (a laptop with plenty of storage entries, a dozen input
    // devices, etc.), so it scrolls inside the window's fixed height --
    // same pattern as the Keybinds list.
    Item {
        width: parent.width
        height: root.bodyHeight

        Flickable {
            id: gridFlick
            // fills the whole Item -- exactly grid's own width, so there's
            // no horizontal slack to accidentally scroll into and clip a
            // column against the edge
            anchors.fill: parent
            contentWidth: grid.implicitWidth
            contentHeight: grid.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds


            Row {
                id: grid
                spacing: root.colGap

                UsageColumn   { stats: stats; width: root.col1Width }
                ProcessColumn { stats: stats; width: root.col2Width }
                SpecsColumn   { stats: stats; width: root.col3Width }
            }
        }

        // scroll indicator, shown only once the grid actually overflows
        ScrollBar {
            anchors.right: parent.right
            flickable: gridFlick
        }
    }
}
