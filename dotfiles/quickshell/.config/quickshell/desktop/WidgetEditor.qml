// Singularity - Quickshell
// ~/.config/quickshell/desktop/WidgetEditor.qml
//
// Edit mode for one screen's desktop widgets, over everything (the screen
// scope's "widgetedit"): drag a widget anywhere and it lines up with the
// screen's middle, its thirds, the margin in from each edge and the other
// widgets (in line, or a gap beside), a guide showing the line it took.
// The one picked gets its size (small, medium, large), Hide, and Move to
// the other screen (a sticky note's Hide leaves it in the Notes window).
// A sticky note has no sizes: its corner drags to any size, stopping at
// the grid's widths and heights on the way.
// The shelf under the bar adds back hidden widgets, a new sticky note in
// the middle, resets the built-in ones' places, and finishes, as Escape
// does.

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../services"
import "../services/WidgetPlacement.js" as Placement
import "../flyouts"

OverlayWindow {
    id: root

    // this screen's DesktopWidgets: where each sits
    required property var layer

    readonly property bool open: scope.openFlyout === "widgetedit"
    function close() { scope.openFlyout = "" }

    visible: open
    focusMode: WlrKeyboardFocus.Exclusive
    layerNamespace: "singularity-flyout"

    // the widget picked, and the guides the one being dragged has taken
    property string picked: ""
    property var guides: []
    onOpenChanged: { picked = ""; guides = [] }

    // WidgetCard's grid: a note's size snaps to its widths and heights
    readonly property int unit: Theme.fit(164)
    function snapSize(v) {
        for (let n = 1; n <= 4; n++) {
            const g = n * unit + (n - 1) * layer.gap
            if (Math.abs(v - g) <= Theme.sp(10)) return g
        }
        return Math.round(v)
    }

    readonly property var others: Quickshell.screens.filter(s => s.name !== screen.name)
    // the built-in widgets that are off, to add back
    readonly property var hidden: Settings.deskWidgetKeys.filter(k => !layer.placeOf(k).on)
    readonly property var names: ({ clock: "Clock", weather: "Weather", music: "Now playing", stats: "System", sysinfo: "System info" })

    Item {
        id: canvas
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.close()

        // dims all but the bar, which stays as it is
        Rectangle {
            y: root.layer.area.y
            width: parent.width
            height: root.layer.area.h
            color: Qt.rgba(0, 0, 0, 0.3)
        }

        // a press on the bare screen puts the picked one down
        MouseArea {
            anchors.fill: parent
            onPressed: root.picked = ""
        }

        Repeater {
            model: root.guides

            Rectangle {
                required property var modelData
                readonly property bool across: modelData.dir === "h"
                x: across ? 0 : modelData.at - width / 2
                y: across ? modelData.at - height / 2 : 0
                width: across ? canvas.width : Theme.borderWidth * 2
                height: across ? Theme.borderWidth * 2 : canvas.height
                color: Theme.accent
                opacity: 0.8
            }
        }

        Repeater {
            model: root.layer.keys.filter(k => root.layer.shown(k))

            Item {
                id: slot
                required property string modelData
                readonly property var rect: root.layer.rectOf(modelData)
                // where the drag has it, null when it's at rest
                property var dragged: null
                property point grab: Qt.point(0, 0)
                // a note's size while its corner is dragged, null at rest
                property var resized: null
                readonly property bool note: modelData.indexOf("note:") === 0
                readonly property var place: root.layer.placeOf(modelData)
                readonly property bool isPicked: root.picked === modelData

                x: dragged ? dragged.x : rect.x
                y: dragged ? dragged.y : rect.y
                z: isPicked ? 1 : 0
                width: widget.width
                height: widget.height

                DeskWidget {
                    id: widget
                    key: slot.modelData
                    size: slot.place.size
                    unitsWide: slot.resized ? slot.resized.w / root.unit : slot.place.w || 0
                    unitsHigh: slot.resized ? slot.resized.h / root.unit : slot.place.h || 0
                    desk: root.layer
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -Theme.spaceS
                    color: "transparent"
                    border.width: slot.isPicked ? Theme.borderWidth * 2 : Theme.borderWidth
                    border.color: slot.isPicked ? Theme.accent : drag.containsMouse ? Theme.strokeHover : Theme.stroke
                }

                MouseArea {
                    id: drag
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onPressed: mouse => {
                        root.picked = slot.modelData
                        slot.grab = Qt.point(mouse.x, mouse.y)
                    }
                    onPositionChanged: mouse => {
                        if (!pressed) return
                        const p = mapToItem(canvas, mouse.x, mouse.y)
                        if (!slot.dragged && Math.hypot(mouse.x - slot.grab.x, mouse.y - slot.grab.y) < Theme.sp(4)) return
                        const others = root.layer.keys
                            .filter(k => k !== slot.modelData && root.layer.shown(k)).map(k => root.layer.rectOf(k))
                        const s = Placement.snap({ x: p.x - slot.grab.x, y: p.y - slot.grab.y, w: slot.width, h: slot.height },
                                                 root.layer.area, root.layer.margin, Theme.sp(10), others, root.layer.gap)
                        slot.dragged = s
                        root.guides = s.guides
                    }
                    onReleased: {
                        if (slot.dragged)
                            root.layer.setPlace(slot.modelData, Placement.fractionsOf(slot.dragged, root.layer.area))
                        slot.dragged = null
                        root.guides = []
                    }
                }

                // a picked note's corner, to size it: no smaller than a
                // unit wide and most of one high, and kept in the area
                Rectangle {
                    visible: slot.note && slot.isPicked && !slot.dragged
                    x: parent.width - width / 2 + Theme.spaceS / 2
                    y: parent.height - height / 2 + Theme.spaceS / 2
                    width: Theme.fit(14)
                    height: width
                    radius: width / 2
                    color: Theme.accent
                    border.width: Theme.borderWidth
                    border.color: Theme.textOnAccent

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Theme.fit(6)
                        cursorShape: Qt.SizeFDiagCursor
                        property point start: Qt.point(0, 0)
                        property size from: Qt.size(0, 0)
                        onPressed: mouse => {
                            start = mapToItem(canvas, mouse.x, mouse.y)
                            from = Qt.size(slot.width, slot.height)
                        }
                        onPositionChanged: mouse => {
                            if (!pressed) return
                            const p = mapToItem(canvas, mouse.x, mouse.y)
                            const a = root.layer.area
                            const w = Math.max(root.unit, Math.min(a.x + a.w - root.layer.margin - slot.x,
                                root.snapSize(from.width + p.x - start.x)))
                            const h = Math.max(Math.round(root.unit * 0.6), Math.min(a.y + a.h - root.layer.margin - slot.y,
                                root.snapSize(from.height + p.y - start.y)))
                            slot.resized = { w: w, h: h }
                        }
                        onReleased: {
                            if (!slot.resized) return
                            const r = slot.resized, f = Placement.fractionsOf({ x: slot.x, y: slot.y, w: r.w, h: r.h }, root.layer.area)
                            root.layer.setPlace(slot.modelData, { fx: f.fx, fy: f.fy, w: r.w / root.unit, h: r.h / root.unit })
                            slot.resized = null
                        }
                    }
                }

                // the picked one's size, Hide and Move, above it (below it
                // when there's no room)
                PanelFrame {
                    visible: slot.isPicked && !slot.dragged && !slot.resized
                    ground: Theme.surface
                    x: Math.max(-slot.x + Theme.edgeMargin, Math.min(0, canvas.width - slot.x - width - Theme.edgeMargin))
                    y: slot.y - height - Theme.spaceL * 2 >= root.layer.area.y
                        ? -height - Theme.spaceL * 2 : slot.height + Theme.spaceL * 2
                    width: tools.implicitWidth + Theme.panelPad * 2
                    height: tools.implicitHeight + Theme.panelPad * 2

                    Row {
                        id: tools
                        anchors.centerIn: parent
                        spacing: Theme.spaceM

                        FlyoutSegmented {
                            visible: !slot.note
                            width: Theme.fit(120)
                            anchors.verticalCenter: parent.verticalCenter
                            model: [{ value: "s", text: "S" }, { value: "m", text: "M" }, { value: "l", text: "L" }]
                            current: slot.place.size
                            onPicked: v => root.layer.setPlace(slot.modelData, { size: v })
                        }
                        Repeater {
                            model: root.others
                            FlyoutChip {
                                required property var modelData
                                anchors.verticalCenter: parent.verticalCenter
                                icon: "󰍹"
                                text: "Move to " + modelData.name
                                onClicked: root.layer.setPlace(slot.modelData, { screen: modelData.name })
                            }
                        }
                        FlyoutChip {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "󰈉"
                            text: "Hide"
                            onClicked: {
                                root.layer.setPlace(slot.modelData, { on: false })
                                root.picked = ""
                            }
                        }
                    }
                }
            }
        }

        // the shelf, under the bar
        PanelFrame {
            ground: Theme.surface
            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.barPosition === "bottom" ? parent.height - Theme.barExtent - Theme.flyoutOffset - height
                : Theme.barExtent + Theme.flyoutOffset
            width: shelf.implicitWidth + Theme.panelPad * 2
            height: shelf.implicitHeight + Theme.panelPad * 2

            Row {
                id: shelf
                anchors.centerIn: parent
                spacing: Theme.spaceM

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Drag a widget: it lines up with the others, the middle and the thirds"
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontSmall
                }
                Repeater {
                    model: root.hidden
                    FlyoutChip {
                        required property string modelData
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "󰐕"
                        text: root.names[modelData]
                        onClicked: Settings.setDeskWidget(modelData, { on: true, screen: root.screen.name })
                    }
                }
                FlyoutChip {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "󰐕"
                    text: "Note"
                    onClicked: root.layer.newNoteAt(root.layer.area.x + root.layer.area.w / 2 - root.layer.noteSize.w / 2,
                                                    root.layer.area.y + root.layer.area.h / 2 - root.layer.noteSize.h / 2)
                }
                FlyoutChip {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Reset"
                    confirmText: "Reset places?"
                    onClicked: Settings.resetDeskWidgets()
                }
                FlyoutChip {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Done"
                    onClicked: root.close()
                }
            }
        }
    }
}
