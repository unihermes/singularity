// Singularity - Quickshell
// ~/.config/quickshell/launcher/LauncherClassic.qml
//
// The launcher's List, Grid and One line layouts: a box (centred, under
// the bar, or full screen per Theme.launcherPosition) holding the mode's
// heading, the field, and the results as rows, as an icon grid (apps
// only), or as one sideways line.

import QtQuick
import "../services"
import "../flyouts"

Item {
    id: view

    required property var launcher
    anchors.fill: parent

    readonly property bool line: launcher.layout === "line"
    readonly property bool gridOn: launcher.layout === "grid" && launcher.mode === "apps"
    readonly property int visibleRows: Settings.launcherRows + (launcher.full ? 4 : 0)
    readonly property int gridColumns: launcher.full ? 8 : 6
    // whichever view is showing: the keys and the clicks drive this one
    readonly property var shown: gridOn ? grid : list

    // the layout's side of LauncherField
    readonly property int count: shown.count
    readonly property bool sideways: gridOn || line
    readonly property var chords: []
    function move(dx, dy) {
        var step = dy !== 0 ? dy * (gridOn ? gridColumns : 1) : dx
        shown.currentIndex = Math.max(0, Math.min(shown.count - 1, shown.currentIndex + step))
    }
    function current() {
        return shown.count > 0 ? { item: launcher.items[shown.currentIndex], kind: launcher.kind } : null
    }
    function chord(name) {}

    Connections {
        target: view.launcher
        function onWasReset() { list.currentIndex = 0; grid.currentIndex = 0 }
        function onWasTyped() { list.currentIndex = 0; grid.currentIndex = 0 }
    }

    PanelFrame {
        width: Theme.fit(view.launcher.full ? 960 : 760)
        height: body.implicitHeight + Theme.panelPad * 4
        // centred, or under the bar, at a fixed size so it doesn't re-centre
        // per keystroke
        x: Math.round((parent.width - width) / 2)
        y: !view.launcher.underBar ? Math.round((parent.height - height) / 2)
            : view.launcher.atBottom ? parent.height - Theme.flyoutOffset - height
            : Theme.flyoutOffset

        Absorber {}

        Column {
            id: body
            x: Theme.panelPad * 2
            y: Theme.panelPad * 2
            width: parent.width - Theme.panelPad * 4
            spacing: Theme.spaceL

            // the mode's name, with the key hints at the rule's far end
            // rather than in a footer
            FlyoutHeading {
                visible: !view.line
                text: view.launcher.modeNames[view.launcher.mode].toUpperCase()
                hints: Theme.launcherDetails ? view.launcher.hints : []
            }

            LauncherField { launcher: view.launcher; view: view }

            Item {
                width: parent.width
                height: view.line ? view.launcher.rowHeight
                    : view.visibleRows * (view.launcher.rowHeight + list.spacing) - list.spacing

                LauncherEmpty { launcher: view.launcher; visible: view.shown.count === 0 }

                ListView {
                    id: list
                    visible: count > 0 && !view.gridOn
                    width: parent.width
                    height: parent.height
                    clip: true
                    orientation: view.line ? ListView.Horizontal : ListView.Vertical
                    spacing: Theme.spaceXs
                    boundsBehavior: Flickable.StopAtBounds
                    model: view.gridOn ? [] : view.launcher.items
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: LauncherRow {
                        required property var modelData
                        required property int index
                        launcher: view.launcher
                        item: modelData
                        current: ListView.isCurrentItem
                        hug: view.line
                        width: view.line ? implicitWidth : list.width
                        onHovered: list.currentIndex = index
                        onClicked: view.launcher.activate(modelData, view.launcher.kind)
                    }
                }

                // apps as a grid: a large icon over its name
                GridView {
                    id: grid
                    visible: count > 0 && view.gridOn
                    width: parent.width
                    height: parent.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    cellWidth: Math.floor(width / view.gridColumns)
                    cellHeight: cellWidth
                    model: view.gridOn ? view.launcher.items : []
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

                    delegate: LauncherTile {
                        required property var modelData
                        required property int index
                        launcher: view.launcher
                        entry: modelData
                        width: grid.cellWidth
                        height: grid.cellHeight
                        current: GridView.isCurrentItem
                        onHovered: grid.currentIndex = index
                        onClicked: view.launcher.activate(modelData, "app")
                    }
                }

                ScrollBar {
                    visible: !view.line && overflow > 0
                    anchors.right: parent.right
                    anchors.rightMargin: -Theme.spaceM
                    flickable: view.shown
                }
            }
        }
    }
}
