// Singularity - Quickshell
// ~/.config/quickshell/desktop/WidgetEditor.qml
//
// Edit mode for one screen's desktop widgets, over everything (the screen
// scope's "widgetedit"): drag a widget anywhere and it lines up with the
// screen's middle, its thirds, the margin in from each edge and the other
// widgets (in line, or a gap beside), a guide showing the line it took.
// The one picked gets its size (small, medium, large), Hide, and Move to
// the other screen. The shelf under the bar adds back hidden widgets,
// resets them all, and finishes, as Escape does.

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

    readonly property var others: Quickshell.screens.filter(s => s.name !== screen.name)
    readonly property var hidden: Settings.deskWidgetKeys.filter(k => !Settings.deskWidget(k).on)
    readonly property var names: ({ clock: "Clock", weather: "Weather", music: "Now playing", stats: "System", note: "Note" })

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
            model: Settings.deskWidgetKeys.filter(k => root.layer.shown(k))

            Item {
                id: slot
                required property string modelData
                readonly property var rect: root.layer.rectOf(modelData)
                // where the drag has it, null when it's at rest
                property var dragged: null
                property point grab: Qt.point(0, 0)
                readonly property bool isPicked: root.picked === modelData

                x: dragged ? dragged.x : rect.x
                y: dragged ? dragged.y : rect.y
                z: isPicked ? 1 : 0
                width: widget.width
                height: widget.height

                DeskWidget {
                    id: widget
                    key: slot.modelData
                    size: Settings.deskWidget(slot.modelData).size
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -Theme.spaceS
                    radius: Math.round(Theme.fit(164) * 0.14) + Theme.spaceS
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
                        const others = Settings.deskWidgetKeys
                            .filter(k => k !== slot.modelData && root.layer.shown(k)).map(k => root.layer.rectOf(k))
                        const s = Placement.snap({ x: p.x - slot.grab.x, y: p.y - slot.grab.y, w: slot.width, h: slot.height },
                                                 root.layer.area, root.layer.margin, Theme.sp(10), others, root.layer.gap)
                        slot.dragged = s
                        root.guides = s.guides
                    }
                    onReleased: {
                        if (slot.dragged)
                            Settings.setDeskWidget(slot.modelData, Placement.fractionsOf(slot.dragged, root.layer.area))
                        slot.dragged = null
                        root.guides = []
                    }
                }

                // the picked one's size, Hide and Move, above it (below it
                // when there's no room)
                PanelFrame {
                    visible: slot.isPicked && !slot.dragged
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
                            width: Theme.fit(120)
                            anchors.verticalCenter: parent.verticalCenter
                            model: [{ value: "s", text: "S" }, { value: "m", text: "M" }, { value: "l", text: "L" }]
                            current: Settings.deskWidget(slot.modelData).size
                            onPicked: v => Settings.setDeskWidget(slot.modelData, { size: v })
                        }
                        Repeater {
                            model: root.others
                            FlyoutChip {
                                required property var modelData
                                anchors.verticalCenter: parent.verticalCenter
                                icon: "󰍹"
                                text: "Move to " + modelData.name
                                onClicked: Settings.setDeskWidget(slot.modelData, { screen: modelData.name })
                            }
                        }
                        FlyoutChip {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "󰈉"
                            text: "Hide"
                            onClicked: {
                                Settings.setDeskWidget(slot.modelData, { on: false })
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
