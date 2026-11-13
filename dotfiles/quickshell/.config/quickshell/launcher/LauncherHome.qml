// The Home layout: the List box, but before you type it's a home screen.
// Apps: the pinned apps (Ctrl+P pins and unpins) as a grid, then recent
// files and the last few copies. Files: the main folders as chips above
// the recent files. The first key, and every other mode, shows the rows.

import QtQuick
import "../services"
import "../flyouts"

Item {
    id: view

    required property var launcher
    anchors.fill: parent

    readonly property bool typing: launcher.query.trim() !== ""
    readonly property bool homeApps: launcher.mode === "apps" && !typing
    readonly property bool homeFiles: launcher.mode === "files" && !typing
    readonly property int visibleRows: Settings.launcherRows + (launcher.full ? 4 : 0)
    readonly property int columns: launcher.full ? 8 : 6
    readonly property var pins: launcher.open ? Apps.pinned.slice(0, columns * 2) : []
    readonly property var folders: ["", "/Documents", "/Downloads", "/Pictures"]
        .map(p => Files.entry(Files.home + p, true))

    readonly property int count: homeApps ? pins.length : list.count
    readonly property bool sideways: homeApps
    readonly property var chords: []
    function move(dx, dy) {
        if (homeApps) {
            pinGrid.current = Math.max(0, Math.min(pins.length - 1, pinGrid.current + dx + dy * columns))
            return
        }
        list.currentIndex = Math.max(0, Math.min(list.count - 1, list.currentIndex + dy))
    }
    function current() {
        if (homeApps) return pins.length > 0 ? { item: pins[pinGrid.current], kind: "app" } : null
        return list.count > 0 ? { item: launcher.items[list.currentIndex], kind: launcher.kind } : null
    }
    function chord(name) {}

    Connections {
        target: view.launcher
        function onWasReset() { list.currentIndex = 0; pinGrid.current = 0 }
        function onWasTyped() { list.currentIndex = 0 }
    }

    // an eyebrow over a part of the home screen
    component Label: Text {
        color: Theme.subtext
        font.family: Theme.fontText
        font.weight: Theme.weightBody
        font.pixelSize: Theme.fontEyebrow
        font.letterSpacing: 1
    }

    PanelFrame {
        width: Theme.fit(view.launcher.full ? 960 : 760)
        height: body.implicitHeight + Theme.panelPad * 4
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

            FlyoutHeading {
                text: view.launcher.modeNames[view.launcher.mode].toUpperCase()
                hints: !Theme.launcherDetails ? []
                    : view.launcher.mode === "apps" ? view.launcher.hints.concat(["Ctrl+P pin"])
                    : view.launcher.hints
            }

            LauncherField { launcher: view.launcher; view: view }

            Item {
                id: area
                width: parent.width
                // one size for the home screen and the rows, so the box
                // doesn't jump at the first key
                height: Math.max(appsHome.implicitHeight,
                    view.visibleRows * (view.launcher.rowHeight + list.spacing) - list.spacing)

                // --- apps, before typing --------------------------------
                Column {
                    id: appsHome
                    visible: view.homeApps
                    width: parent.width
                    spacing: Theme.spaceS

                    Label { text: view.pins.length > 0 ? "PINNED" : "PINNED  ·  CTRL+P ON A SEARCH RESULT" }

                    Grid {
                        id: pinGrid
                        property int current: 0
                        columns: view.columns
                        Repeater {
                            model: view.pins
                            LauncherTile {
                                required property var modelData
                                required property int index
                                launcher: view.launcher
                                entry: modelData
                                width: Math.floor(area.width / view.columns)
                                height: Math.round(width * 0.8)
                                current: pinGrid.current === index
                                onHovered: pinGrid.current = index
                                onClicked: view.launcher.activate(modelData, "app")
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spaceXl
                        topPadding: Theme.spaceS

                        Repeater {
                            model: [
                                { label: "RECENT FILES", kind: "file", rows: Files.recent },
                                { label: "LAST COPIED", kind: "clip", rows: Clipboard.history },
                            ]
                            Column {
                                id: part
                                required property var modelData
                                width: (area.width - Theme.spaceXl) / 2
                                spacing: 1
                                Label { text: part.modelData.label }
                                Repeater {
                                    model: part.modelData.rows.slice(0, 3)
                                    LauncherRow {
                                        required property var modelData
                                        launcher: view.launcher
                                        item: modelData
                                        kind: part.modelData.kind
                                        oneLine: true
                                        width: part.width
                                        onClicked: view.launcher.activate(modelData, part.modelData.kind)
                                    }
                                }
                            }
                        }
                    }
                }

                // --- everything else: the rows, under the folders in files ---
                Column {
                    visible: !view.homeApps
                    width: parent.width
                    height: parent.height
                    spacing: Theme.spaceM

                    Flow {
                        id: folderChips
                        visible: view.homeFiles
                        width: parent.width
                        spacing: Theme.spaceS
                        Repeater {
                            model: view.homeFiles ? view.folders : []
                            FlyoutChip {
                                required property var modelData
                                icon: "󰉋"
                                text: modelData.path === Files.home ? "Home" : modelData.name
                                onClicked: {
                                    view.launcher.requestClose()
                                    Files.open(modelData)
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: parent.height - (folderChips.visible ? folderChips.height + parent.spacing : 0)

                        LauncherEmpty { launcher: view.launcher; visible: list.count === 0 }

                        ListView {
                            id: list
                            anchors.fill: parent
                            clip: true
                            spacing: Theme.spaceXs
                            boundsBehavior: Flickable.StopAtBounds
                            model: view.homeApps ? [] : view.launcher.items
                            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                            delegate: LauncherRow {
                                required property var modelData
                                required property int index
                                launcher: view.launcher
                                item: modelData
                                current: ListView.isCurrentItem
                                width: list.width
                                onHovered: list.currentIndex = index
                                onClicked: view.launcher.activate(modelData, view.launcher.kind)
                            }
                        }

                        ScrollBar {
                            visible: overflow > 0
                            anchors.right: parent.right
                            anchors.rightMargin: -Theme.spaceM
                            flickable: list
                        }
                    }
                }
            }
        }
    }
}
