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

    // Raise the chain up to the flyout page while open, same as
    // SettingsDropdown: without it, the dropdown would draw under whatever
    // page content comes after this select in paint order.
    property var raised: []
    onOpenChanged: {
        if (open) {
            list.positionViewAtIndex(Math.max(0, root.currentIndex), ListView.Contain)
            var r = []
            for (var p = root; p && p.isFlyoutPage !== true; p = p.parent) {
                r.push({ item: p, z: p.z })
                p.z = 100
            }
            raised = r
        } else {
            raised.forEach(e => e.item.z = e.z)
            raised = []
        }
    }
    Component.onDestruction: raised.forEach(e => { if (e.item) e.item.z = e.z })

    readonly property int currentIndex: {
        for (var i = 0; i < model.length; i++)
            if (model[i] === current) return i
        return -1
    }

    component Swatches: Row {
        property var colours: []
        spacing: 0
        Repeater {
            model: parent.colours
            Rectangle {
                required property var modelData
                width: Theme.fs(7)
                height: Theme.fs(12)
                color: modelData
            }
        }
    }

    // the closed row
    Item {
        id: closedRow
        width: parent.width
        height: Theme.rowHeight

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusInner
            color: root.open ? Theme.selectedFill
                : rowMouse.containsMouse ? Theme.hoverFillSoft : "transparent"
            border.width: Theme.borderWidth
            border.color: root.open ? Theme.selectedStroke
                : rowMouse.containsMouse ? Theme.strokeHover : Theme.stroke
        }

        Text {
            id: labelText
            x: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: Theme.text
            font.family: Theme.fontText
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

    // the list, floating over whatever comes after the closed row
    Rectangle {
        visible: root.open
        y: closedRow.height + Theme.spaceXs
        width: parent.width
        height: list.height + Theme.spaceXs * 2
        radius: Theme.radiusInner
        color: Theme.surface
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

                // the current choice's tick, as in every flyout list
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
                    anchors.right: itemSw.left
                    anchors.rightMargin: Theme.spaceM
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: root.labelFor(item.modelData)
                    color: item.isCurrent || itemMouse.containsMouse ? Theme.textStrong : Theme.text
                    font.family: root.fontFor(item.modelData)
                    font.pixelSize: Theme.fontBody
                }

                Swatches {
                    id: itemSw
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spaceM
                    anchors.verticalCenter: parent.verticalCenter
                    colours: root.swatchesFor(item.modelData)
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // picked() first: close() collapses list.model right
                        // away (root.open flips false), tearing down this
                        // delegate -- calling it after left `root` and
                        // `item` already gone, so the pick silently never
                        // fired.
                        if (!item.isCurrent) root.picked(item.modelData)
                        root.close()
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
