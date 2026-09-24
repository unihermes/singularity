// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsDropdown.qml
//
// A dropdown for a Settings field whose choices would not fit as a row of
// chips: a box showing the current value, and a list of every choice under
// it (or over it, near the bottom of the window) with the current one
// ticked. The list scrolls past `maxRows`.
//
// The list is drawn in an overlay filling the window rather than inside the
// field, above a catcher that closes it on a click anywhere else. Raising
// the field's own ancestors instead -- what this did before -- cannot work:
// z orders siblings, so lifting an ancestor lifts that whole subtree, and
// the rest of the window comes with it and swallows the click. The overlay
// also escapes the page's Flickable, which clips, so a list opened at the
// bottom of a long page is no longer cut off.
//
// The list is placed once, when it opens, in window coordinates; a wheel
// anywhere closes it rather than letting the page scroll out from under it.
// The dismissing click is swallowed, as a menu's is everywhere else.
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

    width: Theme.fit(240)
    height: box.height
    opacity: enabled ? 1 : 0.5

    onEnabledChanged: if (!enabled) open = false

    // the window's root item, which the overlay fills; null only while the
    // field is being built, before it belongs to a window
    readonly property var overlayHost: root.Window ? root.Window.contentItem : null

    // Known without the list existing, so the flip can be decided before it
    // is placed.
    readonly property int menuHeight: Math.min(model.length, maxRows) * Theme.rowHeight + Theme.spaceXs * 2

    property bool upward: false
    property real menuX: 0
    property real menuY: 0

    // Measured against the window, less its pads, so the list keeps the
    // same margin from the edge the window's own panel does.
    function place() {
        if (!overlayHost) return
        var p = root.mapToItem(overlayHost, 0, 0)
        var pad = Theme.windowPad + Theme.panelPad
        var below = (root.Window.height || 0) - (p.y + root.height) - pad
        var above = p.y - pad
        upward = below < menuHeight && above > below
        menuX = p.x
        menuY = upward ? p.y - menuHeight - Theme.spaceXs
                       : p.y + root.height + Theme.spaceXs
    }

    onOpenChanged: if (open) {
        place()
        list.positionViewAtIndex(Math.max(0, currentIndex), ListView.Center)
    }

    Rectangle {
        id: box
        width: parent.width
        height: Theme.rowHeight
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

    // The overlay: the catcher fills the window, the list sits over it. Both
    // only exist while the list is open, so nothing here takes a click or a
    // wheel the rest of the time.
    Item {
        id: overlay
        parent: root.overlayHost || root
        anchors.fill: parent
        z: 9000
        visible: root.open && root.overlayHost !== null
        enabled: visible

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: root.open = false

            // The list is placed in window coordinates and doesn't follow
            // the page, so a wheel closes it rather than leaving it
            // stranded mid-scroll. It hangs off the catcher, not the
            // overlay, so the list keeps the wheel events over itself.
            WheelHandler {
                onWheel: root.open = false
            }
        }

        Rectangle {
            id: menu
            x: root.menuX
            y: root.menuY
            width: root.width
            height: root.menuHeight
            radius: Theme.radiusInner
            color: Theme.panel
            border.width: Theme.borderWidth
            border.color: Theme.stroke

            ListView {
                id: list
                x: Theme.spaceXs
                y: Theme.spaceXs
                width: parent.width - Theme.spaceXs * 2
                height: parent.height - Theme.spaceXs * 2
                clip: true
                interactive: root.model.length > root.maxRows
                boundsBehavior: Flickable.StopAtBounds
                // only while open: File Types puts sixty of these on one
                // page, and a closed one has no reason to build delegates
                model: root.open ? root.model : []

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
}
