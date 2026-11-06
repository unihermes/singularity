// Singularity - Quickshell
// ~/.config/quickshell/launcher/LauncherSpotlight.qml
//
// The Spotlight layout, after Apple's: a large rounded search field and
// nothing else until you type. Apps mode searches apps, files, clipboard and
// sums together (Launcher.blendedItems), under small section titles with the
// top hit large; the current result is an accent capsule with its kind at
// the right. Tab narrows to one kind, named at the field's end; Backspace in
// an empty field widens again. The box is only as tall as its results and
// grows from its top edge.

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

    readonly property int count: recents ? 0 : list.count
    readonly property bool sideways: false
    readonly property var chords: []
    function move(dx, dy) {
        if (recents) return
        list.currentIndex = Math.max(0, Math.min(list.count - 1, list.currentIndex + dy))
    }
    function current() {
        if (recents) return null
        var r = rows[list.currentIndex]
        return list.count > 0 && r ? { item: r.item, kind: r.kind } : null
    }
    function chord(name) {}

    Connections {
        target: view.launcher
        function onWasReset() { list.currentIndex = 0 }
        function onWasTyped() { list.currentIndex = 0 }
    }

    PanelFrame {
        width: Theme.fit(view.launcher.full ? 860 : 680)
        height: body.implicitHeight
        radius: Theme.fs(20)
        x: Math.round((parent.width - width) / 2)
        // as Apple's: centred, its top edge about a fifth of the way down,
        // which stays put as results come and go, whatever the launcher position
        y: Math.round(parent.height * 0.21)

        Absorber {}

        Column {
            id: body
            width: parent.width

            LauncherField {
                launcher: view.launcher
                view: view
                x: Theme.panelPad
                width: parent.width - Theme.panelPad * 2
                height: Theme.fs(62)
                textSize: Theme.fs(24)
                glyph: view.launcher.blended ? "󰍉" : view.launcher.glyphs[view.launcher.mode]
                glyphSize: Theme.fs(26)
                glyphQuiet: true
                borderless: true
                hints: view.launcher.blended ? [] : [view.launcher.modeNames[view.launcher.mode]]
            }

            Rectangle {
                visible: !view.recents
                width: parent.width
                height: Theme.borderWidth
                color: Theme.stroke
            }

            Item {
                visible: !view.recents
                x: Theme.spaceM
                width: parent.width - Theme.spaceM * 2
                height: visible ? Math.max(list.count > 0 ? 0 : view.launcher.rowHeight,
                        Math.min(list.contentHeight, (Settings.launcherRows + 3) * view.launcher.lineHeight))
                    + Theme.spaceM * 2 : 0

                LauncherEmpty {
                    launcher: view.launcher
                    y: Theme.spaceM
                    visible: list.count === 0
                    text: view.launcher.blended && Files.searching ? "Searching…" : view.launcher.emptyText
                }

                ListView {
                    id: list
                    y: Theme.spaceM
                    width: parent.width
                    height: parent.height - Theme.spaceM * 2
                    clip: true
                    spacing: 2
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
                            text: parent.section
                            color: Theme.subtext
                            font.family: Theme.fontText
                            font.weight: Theme.weightStrong
                            font.pixelSize: Theme.fontCaption
                        }
                    }

                    delegate: LauncherRow {
                        required property var modelData
                        required property int index
                        launcher: view.launcher
                        item: modelData.item
                        kind: modelData.kind
                        apple: true
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
