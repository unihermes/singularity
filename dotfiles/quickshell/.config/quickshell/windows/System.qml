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
    // Caps the window's height to whatever the shortest connected screen
    // actually has room for, so it can never end up taller than the
    // display -- a fixed guess here was still cut off on a smaller panel.
    // 760 was that guess's fallback for when no screen size is known yet;
    // it stays as a floor via Math.min below so this never grows unbounded
    // either. Leaves room for the bar, this window's own chrome, and gaps
    // on every side. Anything past this scrolls (see grid below).
    readonly property real shortestScreen: {
        var ss = Quickshell.screens
        if (!ss || ss.length === 0) return 1080
        var min = ss[0].height
        for (var i = 1; i < ss.length; i++) min = Math.min(min, ss[i].height)
        return min
    }
    readonly property int maxGridHeight: Math.min(760,
        Math.max(320, shortestScreen - Theme.barHeight - 140))

    SystemStats {
        id: stats
        active: root.visible
    }

    // --- layout ----------------------------------------------------------

    // The three-column grid can run taller than a 1080p screen once every
    // section is populated (a laptop with plenty of storage entries, a
    // dozen input devices, etc.), so it scrolls past root.maxGridHeight
    // instead of pushing the window off-screen -- same pattern as the
    // Keybinds list.
    Item {
        width: parent.width
        height: Math.min(grid.implicitHeight, root.maxGridHeight)

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
