// Singularity - Quickshell
// ~/.config/quickshell/launcher/LauncherStart.qml
//
// The Start menu layout: a menu hung from the bar under the Control Centre
// button. The field across the top; down the side, Pinned, All apps and
// the app groups (Apps.groups) with their counts, then Files, Clipboard and
// Calculator; beside it the group's apps as a grid, or the mode's rows.
// Typing searches every app whatever the group. Ctrl+Up/Down walk the
// groups. Along the bottom, you, and lock, sleep, log out, restart and
// power off (the last three two clicks).

import Quickshell
import QtQuick
import "../services"
import "../flyouts"

Item {
    id: view

    required property var launcher
    anchors.fill: parent

    property string group: "pinned"
    // a group picked from another mode, applied once the switch to apps
    // has reset the menu
    property string pendingGroup: ""

    readonly property bool appsGrid: launcher.mode === "apps"
    readonly property var allApps: launcher.open ? Apps.list("", true) : []
    readonly property var groups: [{ key: "pinned", label: "Pinned", count: Apps.pinned.length },
            { key: "all", label: "All apps", count: allApps.length }]
        .concat(Apps.groups.map(g => ({ key: g.key, label: g.label,
            count: allApps.filter(e => Apps.groupOf(e) === g.key).length }))
        .filter(g => g.count > 0))
    readonly property var apps: !appsGrid ? []
        : launcher.query.trim() !== "" ? launcher.items
        : group === "pinned" ? Apps.pinned
        : group === "all" ? allApps
        : allApps.filter(e => Apps.groupOf(e) === group)
    readonly property int columns: 5

    readonly property int count: appsGrid ? grid.count : list.count
    readonly property bool sideways: appsGrid
    readonly property var chords: ["ctrl+up", "ctrl+down"]
    function move(dx, dy) {
        var v = appsGrid ? grid : list
        var step = appsGrid ? dx + dy * columns : dy
        v.currentIndex = Math.max(0, Math.min(v.count - 1, v.currentIndex + step))
    }
    function current() {
        if (appsGrid) return grid.count > 0 ? { item: apps[grid.currentIndex], kind: "app" } : null
        return list.count > 0 ? { item: launcher.items[list.currentIndex], kind: launcher.kind } : null
    }
    function chord(name) {
        if (!appsGrid) return
        var keys = groups.map(g => g.key)
        var i = keys.indexOf(group) + (name === "ctrl+down" ? 1 : -1)
        pick(keys[(i + keys.length) % keys.length])
    }
    function pick(key) {
        if (launcher.modes.indexOf(key) !== -1) {
            launcher.setMode(key)
            return
        }
        if (launcher.mode !== "apps") {
            pendingGroup = key
            launcher.setMode("apps")
            return
        }
        group = key
        if (launcher.field) launcher.field.clear()
        grid.currentIndex = 0
    }

    Connections {
        target: view.launcher
        function onWasReset() {
            view.group = view.pendingGroup || "pinned"
            view.pendingGroup = ""
            list.currentIndex = 0
            grid.currentIndex = 0
        }
        function onWasTyped() { list.currentIndex = 0; grid.currentIndex = 0 }
    }

    // a line down the rail: a group, or another mode
    component RailItem: Rectangle {
        id: ri
        property string key: ""
        property string label: ""
        property int count: -1
        readonly property bool lit: view.launcher.modes.indexOf(key) !== -1 ? view.launcher.mode === key
            : view.launcher.mode === "apps" && view.group === key && view.launcher.query.trim() === ""
        width: parent ? parent.width : 0
        height: Theme.rowHeight
        radius: Theme.radiusInner
        color: lit ? Theme.selectedFill : railMouse.containsMouse ? Theme.hoverFillSoft : "transparent"

        Rectangle {
            visible: ri.lit
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.indicatorWidth
            height: parent.height - 6
            radius: Theme.pill(width)
            color: Theme.accent
        }
        Text {
            x: Theme.spaceM
            anchors.verticalCenter: parent.verticalCenter
            text: ri.label
            color: ri.lit ? Theme.textStrong : Theme.text
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontBody
        }
        Text {
            visible: ri.count >= 0
            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceM
            anchors.verticalCenter: parent.verticalCenter
            text: ri.count
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontCaption
        }
        MouseArea {
            id: railMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.pick(ri.key)
        }
    }

    component Rule: Rectangle { color: Theme.stroke }

    PanelFrame {
        width: Theme.fit(720)
        height: body.implicitHeight
        // under the Control Centre button: from its left on the left of the
        // screen, from its right on the right, centred on it between
        readonly property real anchorX: view.launcher.controlX >= 0 ? view.launcher.controlX : Theme.fs(20)
        readonly property real wantX: anchorX < parent.width / 3 ? anchorX - Theme.fs(20)
            : anchorX > parent.width * 2 / 3 ? anchorX - width + Theme.fs(20)
            : anchorX - width / 2
        x: Math.round(Math.max(Theme.edgeMargin, Math.min(parent.width - width - Theme.edgeMargin, wantX)))
        y: view.launcher.atBottom ? parent.height - Theme.flyoutOffset - height : Theme.flyoutOffset

        Absorber {}

        Column {
            id: body
            width: parent.width

            Item {
                width: parent.width
                height: field.height + Theme.panelPad * 2
                LauncherField {
                    id: field
                    launcher: view.launcher
                    view: view
                    x: Theme.panelPad
                    y: Theme.panelPad
                    width: parent.width - Theme.panelPad * 2
                }
            }

            Rule { width: parent.width; height: Theme.borderWidth }

            Row {
                width: parent.width
                height: Theme.fit(400)

                Column {
                    id: rail
                    width: Theme.fit(180)
                    padding: Theme.spaceS
                    spacing: 1

                    Repeater {
                        model: view.groups
                        RailItem {
                            required property var modelData
                            width: rail.width - rail.padding * 2
                            key: modelData.key
                            label: modelData.label
                            count: modelData.count
                        }
                    }
                    Item { width: 1; height: Theme.spaceS }
                    Rule { width: rail.width - rail.padding * 2; height: Theme.borderWidth }
                    Item { width: 1; height: Theme.spaceS }
                    Repeater {
                        model: ["files", "clipboard", "calc"]
                        RailItem {
                            required property string modelData
                            width: rail.width - rail.padding * 2
                            key: modelData
                            label: view.launcher.modeNames[modelData]
                        }
                    }
                }

                Rule { width: Theme.borderWidth; height: parent.height }

                Item {
                    width: parent.width - rail.width - Theme.borderWidth
                    height: parent.height

                    FlyoutHeading {
                        id: heading
                        x: Theme.panelPad
                        y: Theme.panelPad
                        width: parent.width - Theme.panelPad * 2
                        text: !view.appsGrid ? view.launcher.modeNames[view.launcher.mode].toUpperCase()
                            : view.launcher.query.trim() !== "" ? "RESULTS"
                            : (view.groups.find(g => g.key === view.group) || { label: "" }).label.toUpperCase()
                        hints: !Theme.launcherDetails ? []
                            : view.appsGrid ? ["Ctrl+P pin", "Ctrl+↑↓ group"] : view.launcher.hints
                    }

                    Item {
                        x: Theme.panelPad
                        y: heading.y + heading.height + Theme.spaceM
                        width: parent.width - Theme.panelPad * 2
                        height: parent.height - y - Theme.panelPad

                        LauncherEmpty {
                            launcher: view.launcher
                            visible: view.count === 0
                            text: view.appsGrid && view.group === "pinned" && view.launcher.query.trim() === ""
                                ? "Nothing pinned: Ctrl+P on an app" : view.launcher.emptyText
                        }

                        GridView {
                            id: grid
                            visible: view.appsGrid
                            anchors.fill: parent
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            cellWidth: Math.floor(width / view.columns)
                            cellHeight: Math.round(cellWidth * 0.9)
                            model: view.apps
                            onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

                            delegate: LauncherTile {
                                required property var modelData
                                required property int index
                                launcher: view.launcher
                                entry: modelData
                                pinMark: view.group !== "pinned" || view.launcher.query.trim() !== ""
                                width: grid.cellWidth
                                height: grid.cellHeight
                                current: GridView.isCurrentItem
                                onHovered: grid.currentIndex = index
                                onClicked: view.launcher.activate(modelData, "app")
                            }
                        }

                        ListView {
                            id: list
                            visible: !view.appsGrid
                            anchors.fill: parent
                            clip: true
                            spacing: Theme.spaceXs
                            boundsBehavior: Flickable.StopAtBounds
                            model: view.appsGrid ? [] : view.launcher.items
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
                            flickable: view.appsGrid ? grid : list
                        }
                    }
                }
            }

            Rule { width: parent.width; height: Theme.borderWidth }

            // you, and the session's actions
            Item {
                width: parent.width
                height: Theme.controlSize + Theme.panelPad * 2

                Text {
                    x: Theme.panelPad * 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰀄  " + (Quickshell.env("USER") || "")
                    color: Theme.text
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontBody
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.panelPad
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spaceXs

                    Repeater {
                        model: Session.actions.filter(a => a.act !== "hibernate")
                        IconButton {
                            required property var modelData
                            icon: modelData.icon
                            // ending the session or the machine takes two clicks
                            confirm: ["logout", "reboot", "poweroff"].indexOf(modelData.act) !== -1
                            onClicked: {
                                view.launcher.requestClose()
                                Session.run(modelData.act)
                            }
                        }
                    }
                }
            }
        }
    }
}
