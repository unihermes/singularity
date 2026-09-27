// Singularity - Quickshell
// ~/.config/quickshell/flyouts/PowerMenu.qml
//
// SUPER+SHIFT+E: lock, suspend, log out, reboot or shut down, centred on the
// focused monitor. Arrows and Enter pick one, each action's letter runs it
// straight away, Escape or a click outside closes. The same actions as the
// Control Centre's Power page (services/Session.qml).

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../services"

OverlayWindow {
    id: root

    readonly property bool open: scope.openFlyout === "powermenu"
    readonly property var actions: Session.actions
    property int current: 0

    function requestClose() { scope.openFlyout = "" }

    function run(i) {
        const a = actions[i]
        if (!a) return
        requestClose()
        Session.run(a.act)
    }

    onOpenChanged: if (open) {
        current = 0
        Session.refresh()
    }

    visible: open
    focusMode: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    layerNamespace: "singularity-overlay"

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim

        MouseArea {
            anchors.fill: parent
            onClicked: root.requestClose()
        }
    }

    // Keys only attach to an Item, not to the window
    FocusScope {
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: root.requestClose()
        Keys.onPressed: event => {
            const n = root.actions.length
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab
                    || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                root.current = (root.current + n - 1) % n
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                root.current = (root.current + 1) % n
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                    || event.key === Qt.Key_Space) {
                root.run(root.current)
            } else {
                const i = root.actions.findIndex(a => a.key === event.text.toUpperCase())
                if (i < 0) return
                root.run(i)
            }
            event.accepted = true
        }
    }

    // laid out as the launcher is: a heading with the key hints, then the body
    PanelFrame {
        anchors.centerIn: parent
        width: body.implicitWidth + Theme.panelPad * 4
        height: body.implicitHeight + Theme.panelPad * 4

        // absorbs clicks so they don't reach the backdrop
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Column {
            id: body
            x: Theme.panelPad * 2
            y: Theme.panelPad * 2
            spacing: Theme.spaceL

            FlyoutHeading {
                width: row.width
                text: "POWER"
                hints: ["Arrows choose", "Enter run", "Esc close"]
            }

            Row {
                id: row
                spacing: Theme.spaceL

                Repeater {
                    model: root.actions

                    Rectangle {
                        id: tile
                        required property var modelData
                        required property int index
                        readonly property bool selected: root.current === index

                        width: Theme.fs(104)
                        height: Theme.fs(104)
                        radius: Theme.radiusInner
                        color: selected ? Theme.selectedFill : Theme.surface
                        border.width: Theme.borderWidth
                        border.color: selected ? Theme.selectedStroke : Theme.border

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spaceM

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.icon
                                color: tile.selected ? Theme.textStrong : Theme.text
                                font.family: Theme.fontIcon
                                font.pixelSize: Theme.fontHero
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.label
                                color: tile.selected ? Theme.textStrong : Theme.text
                                font.family: Theme.fontText
                                font.pixelSize: Theme.fontBody
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.key
                                color: Theme.subtext
                                font.family: Theme.fontText
                                font.pixelSize: Theme.fontCaption
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.current = tile.index
                            onClicked: root.run(tile.index)
                        }
                    }
                }
            }
        }
    }
}
