// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutSelect.qml
//
// A flyout's dropdown: a row with the label, the current choice and a
// chevron, which opens the whole list underneath it. Floats over whatever
// follows it instead of pushing it down, the same way SettingsDropdown
// does: the row's own height is all this ever reports upward, so opening
// it never resizes the flyout's box, and the dropdown itself is raised
// above the rows beneath it rather than shoving them further down the page.
//
// Several on one page share `group`: opening one closes the others, so
// the page never ends up with three lists open and a scroll to find them.
//
// The list is a DropdownMenu, as SettingsDropdown's is, in an overlay
// filling the flyout box. The overlay stops at the box, not the whole
// layer, so a click outside the flyout still dismisses the flyout itself.
//
// A choice can carry a strip of colour swatches (`swatchesFor`) -- the
// looks, shown by their palettes -- or be set in its own font (`fontFor`).

import QtQuick
import "../services"

Item {
    id: root

    property string label: ""
    property var model: []
    property var current
    property var labelFor: v => String(v)
    // a choice's font; the fonts list sets each in itself
    property var fontFor: v => Theme.fontText
    // a choice's swatches, [] for none
    property var swatchesFor: v => []
    // what the row shows after the name, like " *" for an adjusted look
    property string valueSuffix: ""
    property bool enabled: true
    property int maxRows: 7

    // an object with an `open` property, shared by the selects on a page;
    // null keeps this one to itself
    property var group: null
    property bool ownOpen: false
    readonly property bool open: group ? group.open === root : ownOpen

    signal picked(var value)

    function toggle() {
        if (group) group.open = open ? null : root
        else ownOpen = !ownOpen
    }
    function close() {
        if (group) { if (group.open === root) group.open = null }
        else ownOpen = false
    }

    width: parent ? parent.width : 0
    // Only the closed row -- the dropdown floats over whatever comes after
    // it rather than being counted here, so opening it never resizes
    // whatever is laying this out.
    height: closedRow.height
    opacity: enabled ? 1 : 0.5
    onEnabledChanged: if (!enabled) close()

    // The flyout page this select sits on -- the panel's content Column --
    // and the box holding it, which is what the overlay fills. The page
    // itself can't: a positioner manages its children's geometry, so an
    // anchored child stops it laying out at all.
    readonly property var pageItem: {
        for (var p = root.parent; p; p = p.parent)
            if (p.isFlyoutPage === true) return p
        return null
    }
    readonly property var overlayHost: pageItem ? pageItem.parent : null

    onOpenChanged: if (open && overlayHost) {
        var p = root.mapToItem(overlayHost, 0, 0)
        menu.menuX = p.x
        menu.menuY = p.y + closedRow.height + Theme.spaceXs
    }

    readonly property int currentIndex: {
        for (var i = 0; i < model.length; i++)
            if (model[i] === current) return i
        return -1
    }

    // the closed row
    Item {
        id: closedRow
        width: parent.width
        height: Theme.rowHeight

        Rectangle {
            id: selectBox
            readonly property color edge: root.open ? Theme.strokeFocus
                : rowMouse.containsMouse ? Theme.strokeHover : Theme.stroke
            anchors.fill: parent
            radius: Theme.radiusInner
            color: Theme.fieldFill
            border.width: Theme.controlBorder(edge)
            border.color: Theme.controlStroke(edge)

            ControlEdge { stroke: selectBox.edge; sunken: true; radius: selectBox.radius }
        }

        Text {
            id: labelText
            x: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: Theme.text
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontBody
        }

        Row {
            anchors.left: labelText.right
            anchors.leftMargin: Theme.spaceL
            anchors.right: chevron.left
            anchors.rightMargin: Theme.spaceS
            anchors.verticalCenter: parent.verticalCenter
            layoutDirection: Qt.RightToLeft
            spacing: Theme.spaceM

            Text {
                width: Math.min(implicitWidth, parent.width - sw.width - (sw.width > 0 ? parent.spacing : 0))
                elide: Text.ElideRight
                text: (root.currentIndex >= 0 ? root.labelFor(root.current) : "--") + root.valueSuffix
                color: Theme.textStrong
                font.family: root.currentIndex >= 0 ? root.fontFor(root.current) : Theme.fontText
                font.pixelSize: Theme.fontBody
            }

            Swatches {
                id: sw
                anchors.verticalCenter: parent.verticalCenter
                colours: root.currentIndex >= 0 ? root.swatchesFor(root.current) : []
            }
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
            id: rowMouse
            anchors.fill: parent
            enabled: root.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggle()
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
        swatchesFor: root.swatchesFor
        maxRows: root.maxRows
        onPicked: v => root.picked(v)
        onDismissed: root.close()
    }
}
