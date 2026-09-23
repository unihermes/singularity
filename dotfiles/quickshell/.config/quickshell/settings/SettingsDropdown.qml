// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsDropdown.qml
//
// A dropdown for a Settings field whose choices would not fit as a row of
// chips: a box showing the current value, and a list of every choice under
// it (or over it, near the bottom of the window) with the current one
// ticked. The list scrolls past `maxRows`.
//
// The list floats over the rows below rather than pushing them down, so
// while it's open every ancestor up to the page is raised above its
// siblings -- a dropdown inside a per-monitor or per-rule Column would
// otherwise draw under the next block.
//
//   SettingsDropdown {
//       anchors.right: parent.right
//       model: ["a", "b"]
//       current: Settings.thing
//       labelFor: v => Settings.choiceLabel(v)
//       onPicked: v => Settings.set("thing", v)
//   }

import QtQuick
import "../services"
import "../flyouts"

Item {
    id: root

    property var model: []
    property var current
    // how a choice reads; also what the box shows for the current one
    property var labelFor: v => String(v)
    // a choice's font, for a list of fonts set in themselves
    property var fontFor: v => Theme.fontText
    // what the box shows when nothing in the model is current
    property string placeholder: "Choose…"
    property int maxRows: 8
    property bool open: false

    signal picked(var value)

    readonly property int currentIndex: {
        for (var i = 0; i < model.length; i++)
            if (model[i] === current) return i
        return -1
    }

    width: Theme.fs(240)
    height: box.height
    opacity: enabled ? 1 : 0.5

    onEnabledChanged: if (!enabled) open = false

    // Raise the chain while open, and put every z back as it was on close.
    property var raised: []
    onOpenChanged: {
        if (open) {
            var r = []
            for (var p = root; p && p.isSettingsPage !== true; p = p.parent) {
                r.push({ item: p, z: p.z })
                p.z = 100
            }
            raised = r
            upward = spaceBelow() < menu.height && spaceAbove() > spaceBelow()
            list.positionViewAtIndex(Math.max(0, currentIndex), ListView.Center)
        } else {
            raised.forEach(e => e.item.z = e.z)
            raised = []
        }
    }
    Component.onDestruction: raised.forEach(e => { if (e.item) e.item.z = e.z })

    property bool upward: false
    // measured against the window, less its pads: the page's scroller clips
    // a little inside the window's edge
    function spaceBelow() {
        var y = root.mapToItem(null, 0, root.height).y
        return (root.Window.height || 0) - y - Theme.windowPad - Theme.panelPad
    }
    function spaceAbove() {
        return root.mapToItem(null, 0, 0).y - Theme.windowPad - Theme.panelPad
    }

    Rectangle {
        id: box
        width: parent.width
        height: Theme.fieldHeight
        radius: Theme.radiusInner
        color: Theme.fieldFill
        border.width: Theme.borderWidth
        border.color: root.open ? Theme.strokeFocus
            : boxMouse.containsMouse ? Theme.strokeHover : Theme.stroke

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spaceL
            anchors.right: chevron.left
            anchors.rightMargin: Theme.spaceS
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: root.currentIndex >= 0 ? root.labelFor(root.current) : root.placeholder
            color: root.currentIndex >= 0 ? Theme.textStrong : Theme.subtext
            font.family: root.currentIndex >= 0 ? root.fontFor(root.current) : Theme.fontText
            font.pixelSize: Theme.fontBody
        }

        Text {
            id: chevron
            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            text: root.open ? "󰅃" : "󰅀"
            color: Theme.subtext
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontIconSize
        }

        MouseArea {
            id: boxMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.open = !root.open
        }
    }

    Rectangle {
        id: menu
        visible: root.open
        y: root.upward ? -height - Theme.spaceXs : box.height + Theme.spaceXs
        width: parent.width
        height: list.height + Theme.spaceXs * 2
        radius: Theme.radiusInner
        color: Theme.panel
        border.width: Theme.borderWidth
        border.color: Theme.stroke

        ListView {
            id: list
            x: Theme.spaceXs
            y: Theme.spaceXs
            width: parent.width - Theme.spaceXs * 2
            height: Math.min(root.model.length, root.maxRows) * Theme.rowHeight
            clip: true
            interactive: root.model.length > root.maxRows
            boundsBehavior: Flickable.StopAtBounds
            model: root.model

            delegate: Rectangle {
                id: item
                required property var modelData
                required property int index
                readonly property bool isCurrent: index === root.currentIndex

                width: list.width
                height: Theme.rowHeight
                radius: Theme.radiusSmall
                color: itemMouse.containsMouse ? Theme.hoverFill : "transparent"

                // the current choice's tick, as in a flyout list
                Rectangle {
                    visible: item.isCurrent
                    x: Theme.spaceXs
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.indicatorWidth
                    height: parent.height - 6
                    radius: width / 2
                    color: Theme.accent
                }

                Text {
                    x: Theme.spaceL
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.spaceL * 2
                    elide: Text.ElideRight
                    text: root.labelFor(item.modelData)
                    color: item.isCurrent || itemMouse.containsMouse ? Theme.textStrong : Theme.text
                    font.family: root.fontFor(item.modelData)
                    font.pixelSize: Theme.fontBody
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // picked() first: closing collapses list.model right
                        // away, tearing down this delegate -- calling it
                        // after left `root` and `item` already gone, so the
                        // pick silently never fired.
                        if (!item.isCurrent) root.picked(item.modelData)
                        root.open = false
                    }
                }
            }
        }

        ScrollBar {
            anchors.right: parent.right
            anchors.rightMargin: 2
            flickable: list
        }
    }
}
