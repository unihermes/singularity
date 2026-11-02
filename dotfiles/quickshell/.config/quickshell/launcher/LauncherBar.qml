// Singularity - Quickshell
// ~/.config/quickshell/launcher/LauncherBar.qml
//
// The In the bar layout: the field takes the clock's place on the bar and
// the results drop from it like a flyout (upward from a bottom bar). Rows
// are one line, the first nine numbered: Alt+1-9 opens one without moving
// to it. The foot names the mode prefixes and what Tab goes to.

import QtQuick
import "../services"
import "../flyouts"

Item {
    id: view

    required property var launcher
    anchors.fill: parent

    readonly property int count: list.count
    readonly property bool sideways: false
    readonly property var chords: [1, 2, 3, 4, 5, 6, 7, 8, 9].map(n => "alt+" + n)
    function move(dx, dy) {
        list.currentIndex = Math.max(0, Math.min(list.count - 1, list.currentIndex + dy))
    }
    function current() {
        return list.count > 0 ? { item: launcher.items[list.currentIndex], kind: launcher.kind } : null
    }
    function chord(name) {
        var i = parseInt(name.slice(4)) - 1
        if (i < list.count) launcher.activate(launcher.items[i], launcher.kind)
    }

    Connections {
        target: view.launcher
        function onWasReset() { list.currentIndex = 0 }
        function onWasTyped() { list.currentIndex = 0 }
    }

    readonly property real boxWidth: Theme.fit(500)
    readonly property real centreX: launcher.clockX >= 0 ? launcher.clockX : width / 2
    readonly property real boxX: Math.round(Math.max(Theme.edgeMargin,
        Math.min(width - boxWidth - Theme.edgeMargin, centreX - boxWidth / 2)))
    readonly property real barY: launcher.atBottom ? height - Theme.barMargin - Theme.barHeight : Theme.barMargin

    // the field, over the clock on the bar
    Rectangle {
        x: view.boxX
        y: view.barY
        width: view.boxWidth
        height: Theme.barHeight
        color: Theme.bar
        radius: Theme.barFull ? 0 : Theme.radiusInner

        Absorber {}

        LauncherField {
            launcher: view.launcher
            view: view
            x: Theme.spaceXs
            y: Theme.spaceXs
            width: parent.width - Theme.spaceXs * 2
            height: parent.height - Theme.spaceXs * 2
            hints: [view.launcher.modeNames[view.launcher.mode]]
        }
    }

    PanelFrame {
        x: view.boxX
        width: view.boxWidth
        height: body.implicitHeight + Theme.panelPad * 2
        y: view.launcher.atBottom ? view.barY - height : view.barY + Theme.barHeight

        Absorber {}

        Column {
            id: body
            x: Theme.panelPad
            y: Theme.panelPad
            width: parent.width - Theme.panelPad * 2
            spacing: Theme.spaceS

            Item {
                width: parent.width
                height: Math.max(view.launcher.lineHeight,
                    Math.min(list.contentHeight, Settings.launcherRows * (view.launcher.lineHeight + list.spacing)))

                LauncherEmpty { launcher: view.launcher; visible: list.count === 0; height: view.launcher.lineHeight }

                ListView {
                    id: list
                    anchors.fill: parent
                    clip: true
                    spacing: 1
                    boundsBehavior: Flickable.StopAtBounds
                    model: view.launcher.items
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: LauncherRow {
                        required property var modelData
                        required property int index
                        launcher: view.launcher
                        item: modelData
                        oneLine: true
                        number: index < 9 ? "Alt " + (index + 1) : ""
                        current: ListView.isCurrentItem
                        width: list.width
                        onHovered: list.currentIndex = index
                        onClicked: view.launcher.activate(modelData, view.launcher.kind)
                    }
                }
            }

            Rectangle { width: parent.width; height: Theme.borderWidth; color: Theme.stroke }

            // the prefixes, and where Tab goes
            Item {
                visible: Theme.launcherDetails
                width: parent.width
                height: footText.implicitHeight + Theme.spaceXs
                Text {
                    id: footText
                    x: Theme.spaceL
                    text: view.launcher.mode === "apps" ? "/ files    ; clipboard    = sums" : view.launcher.hints.slice(0, -1).join("    ")
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontCaption
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spaceL
                    text: "Tab " + view.launcher.nextModeName
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontCaption
                }
            }
        }
    }
}
