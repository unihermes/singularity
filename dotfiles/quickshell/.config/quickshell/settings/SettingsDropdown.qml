// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsDropdown.qml
//
// A dropdown for a Settings field whose choices would not fit as a row of
// chips: a box showing the current value, and a list of every choice under
// it (or over it, near the bottom of the window) with the current one
// ticked. The list scrolls past `maxRows`.
//
// The list is a DropdownMenu, as FlyoutSelect's is, in an overlay filling
// the window, so it escapes the page's Flickable and a list opened at the
// bottom of a long page isn't cut off. The page can't scroll while it's
// open.
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

    property bool upward: false

    // Measured against the window, less its pads, so the list keeps the
    // same margin from the edge the window's own panel does.
    function place() {
        if (!overlayHost) return
        var p = root.mapToItem(overlayHost, 0, 0)
        var pad = Theme.windowPad + Theme.panelPad
        var below = (root.Window.height || 0) - (p.y + root.height) - pad
        var above = p.y - pad
        upward = below < menu.menuHeight && above > below
        menu.menuX = p.x
        menu.menuY = upward ? p.y - menu.menuHeight - Theme.spaceXs
                            : p.y + root.height + Theme.spaceXs
    }

    onOpenChanged: if (open) place()

    Rectangle {
        id: box
        width: parent.width
        height: Theme.rowHeight
        readonly property color edge: root.open ? Theme.strokeFocus
            : boxMouse.containsMouse ? Theme.strokeHover : Theme.stroke
        radius: Theme.radiusInner
        color: Theme.fieldFill
        border.width: Theme.controlBorder(edge)
        border.color: Theme.controlStroke(edge)

        ControlEdge { stroke: box.edge; sunken: true; radius: box.radius }

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

    DropdownMenu {
        id: menu
        owner: root
        overlayHost: root.overlayHost
        open: root.open
        model: root.model
        currentIndex: root.currentIndex
        labelFor: root.labelFor
        fontFor: root.fontFor
        maxRows: root.maxRows
        onPicked: v => root.picked(v)
        onDismissed: root.open = false
    }
}
