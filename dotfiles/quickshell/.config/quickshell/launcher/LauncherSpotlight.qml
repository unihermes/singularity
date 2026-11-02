// Singularity - Quickshell
// ~/.config/quickshell/launcher/LauncherSpotlight.qml
//
// The Spotlight layout: one large field, no heading. Apps mode searches
// apps, files, clipboard and sums together (Launcher.blendedItems), under
// small section labels with the top hit large; before typing, the most
// used apps as a row of icons. Tab narrows to one kind, named at the
// field's end; Backspace in an empty field widens again. The box is only
// as tall as its results and grows from its top edge.

import QtQuick
import "../services"
import "../flyouts"

Item {
    id: view

    required property var launcher
    anchors.fill: parent

    readonly property bool recents: launcher.blended && launcher.query.trim() === ""
    // rows as { item, kind, section }, whatever the mode
    readonly property var rows: launcher.blended ? launcher.blendedItems
        : launcher.items.map(i => ({ item: i, kind: launcher.kind, section: "" }))
    readonly property var mostUsed: launcher.open ? Apps.list("").slice(0, 8) : []

    readonly property int count: recents ? mostUsed.length : list.count
    readonly property bool sideways: recents
    readonly property var chords: []
    function move(dx, dy) {
        if (recents) {
            strip.current = Math.max(0, Math.min(mostUsed.length - 1, strip.current + dx))
            return
        }
        list.currentIndex = Math.max(0, Math.min(list.count - 1, list.currentIndex + dy))
    }
    function current() {
        if (recents) return mostUsed.length > 0 ? { item: mostUsed[strip.current], kind: "app" } : null
        var r = rows[list.currentIndex]
        return list.count > 0 && r ? { item: r.item, kind: r.kind } : null
    }
    function chord(name) {}

    Connections {
        target: view.launcher
        function onWasReset() { list.currentIndex = 0; strip.current = 0 }
        function onWasTyped() { list.currentIndex = 0 }
    }

    PanelFrame {
        id: frame
        width: Theme.fit(view.launcher.full ? 860 : 700)
        height: body.implicitHeight
        x: Math.round((parent.width - width) / 2)
        // its top edge stays put as results come and go
        y: !view.launcher.underBar ? Math.round(parent.height * 0.2)
            : view.launcher.atBottom ? parent.height - Theme.flyoutOffset - height
            : Theme.flyoutOffset

        Absorber {}

        Column {
            id: body
            width: parent.width

            LauncherField {
                launcher: view.launcher
                view: view
                x: Theme.panelPad
                width: parent.width - Theme.panelPad * 2
                height: Theme.fs(64)
                textSize: Theme.fs(22)
                hints: view.launcher.blended ? [] : [view.launcher.modeNames[view.launcher.mode]]
            }

            Rectangle {
                visible: view.recents ? view.mostUsed.length > 0 : true
                width: parent.width
                height: Theme.borderWidth
                color: Theme.stroke
            }

            // before typing: the most used apps
            Row {
                id: strip
                property int current: 0
                visible: view.recents
                x: Theme.panelPad * 2
                topPadding: Theme.spaceM
                bottomPadding: Theme.spaceM
                Repeater {
                    model: view.recents ? view.mostUsed : []
                    LauncherTile {
                        required property var modelData
                        required property int index
                        launcher: view.launcher
                        entry: modelData
                        width: Math.floor((frame.width - Theme.panelPad * 4) / 8)
                        height: width
                        current: strip.current === index
                        onHovered: strip.current = index
                        onClicked: view.launcher.activate(modelData, "app")
                    }
                }
            }

            Item {
                visible: !view.recents
                x: Theme.panelPad
                width: parent.width - Theme.panelPad * 2
                height: visible ? Math.max(list.count > 0 ? 0 : view.launcher.rowHeight,
                        Math.min(list.contentHeight, (Settings.launcherRows + 3) * view.launcher.lineHeight))
                    + Theme.panelPad * 2 : 0

                LauncherEmpty {
                    launcher: view.launcher
                    y: Theme.panelPad
                    visible: list.count === 0
                    text: view.launcher.blended && Files.searching ? "Searching…" : view.launcher.emptyText
                }

                ListView {
                    id: list
                    y: Theme.panelPad
                    width: parent.width
                    height: parent.height - Theme.panelPad * 2
                    clip: true
                    spacing: 1
                    boundsBehavior: Flickable.StopAtBounds
                    model: view.recents ? [] : view.rows
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    section.property: "section"
                    section.delegate: Item {
                        required property string section
                        width: list.width
                        height: section !== "" ? sectionLabel.implicitHeight + Theme.spaceM : 0
                        Text {
                            id: sectionLabel
                            visible: parent.section !== ""
                            x: Theme.spaceL
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Theme.spaceXs
                            text: parent.section.toUpperCase()
                            color: Theme.subtext
                            font.family: Theme.fontText
                            font.weight: Theme.weightBody
                            font.pixelSize: Theme.fontEyebrow
                            font.letterSpacing: 1
                        }
                    }

                    delegate: LauncherRow {
                        required property var modelData
                        required property int index
                        launcher: view.launcher
                        item: modelData.item
                        kind: modelData.kind
                        large: modelData.section === "Top hit"
                        oneLine: !large
                        current: ListView.isCurrentItem
                        width: list.width
                        onHovered: list.currentIndex = index
                        onClicked: view.launcher.activate(modelData.item, modelData.kind)
                    }
                }
            }
        }
    }
}
