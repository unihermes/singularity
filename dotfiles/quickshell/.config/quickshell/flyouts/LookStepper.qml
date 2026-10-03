// Singularity - Quickshell
// ~/.config/quickshell/flyouts/LookStepper.qml
//
// The look in use as a card: its name large between ‹ and ›, which step
// to the previous or next look and apply it, a line saying where it sits
// in the list and how many of its settings have been changed, and its
// palette as a band. A click on the name opens every look as a list (the
// same DropdownMenu SettingsDropdown uses), floating over what follows.

import Quickshell.Widgets
import QtQuick
import "../services"

Item {
    id: root

    // an object with an `open` property, shared by the page's lists so
    // only one is open; null keeps this one to itself
    property var group: null
    readonly property bool open: group ? group.open === root : ownOpen
    property bool ownOpen: false

    readonly property var order: LookStore.order
    readonly property int index: order.indexOf(Settings.look)
    readonly property int changes: Settings.lookDiffs.length

    function toggle() {
        if (group) group.open = open ? null : root
        else ownOpen = !ownOpen
    }
    function close() {
        if (group) { if (group.open === root) group.open = null }
        else ownOpen = false
    }
    function step(d) {
        close()
        var n = order.length
        if (n > 0) Settings.set("look", order[((index < 0 ? 0 : index) + d + n) % n])
    }
    // a look's palette, dark to light, then its accent if it has one
    function swatches(name) {
        var l = LookStore.looks[name]
        if (!l) return []
        var p = l.palette
        return [p.base, p.border, p.subtext, p.text].concat(l.accent ? [l.accent] : [])
    }

    width: parent ? parent.width : 0
    implicitHeight: col.implicitHeight

    // the flyout page, and the box holding it that the list floats in
    readonly property var pageItem: {
        for (var p = root.parent; p; p = p.parent)
            if (p.isFlyoutPage === true) return p
        return null
    }
    onOpenChanged: if (open && pageItem) {
        var p = nameBox.mapToItem(pageItem.parent, 0, 0)
        menu.menuX = root.mapToItem(pageItem.parent, 0, 0).x
        menu.menuY = p.y + nameBox.height + Theme.spaceXs
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.spaceS

        Item {
            width: parent.width
            height: Math.max(prev.height, nameBox.height)

            FlyoutChip {
                id: prev
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                glyph: true
                text: "󰅁"
                enabled: root.order.length > 1
                onClicked: root.step(-1)
            }

            Rectangle {
                id: nameBox
                anchors.left: prev.right
                anchors.right: next.left
                anchors.leftMargin: Theme.spaceS
                anchors.rightMargin: Theme.spaceS
                anchors.verticalCenter: parent.verticalCenter
                height: names.implicitHeight + Theme.spaceXs * 2
                radius: Theme.radiusInner
                color: nameMouse.containsMouse || root.open ? Theme.hoverFill : "transparent"

                Column {
                    id: names
                    x: Theme.spaceS
                    width: parent.width - Theme.spaceS * 2
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: LookStore.looks[Settings.look] ? LookStore.looks[Settings.look].name : Settings.look
                        color: Theme.textStrong
                        font.family: Theme.fontText
                        font.weight: Theme.weightStrong
                        font.pixelSize: Theme.fontTitle
                    }

                    Row {
                        spacing: Theme.spaceS

                        Text {
                            text: (root.index + 1) + " of " + root.order.length
                            color: Theme.subtext
                            font.family: Theme.fontText
                            font.weight: Theme.weightBody
                            font.pixelSize: Theme.fontCaption
                        }

                        Text {
                            visible: root.changes > 0
                            text: "· " + root.changes + " changed"
                            color: Theme.hasAccent ? Qt.lighter(Theme.accent, 1.4) : Theme.text
                            font.family: Theme.fontText
                            font.weight: Theme.weightBody
                            font.pixelSize: Theme.fontCaption
                        }
                    }
                }

                MouseArea {
                    id: nameMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggle()
                }
            }

            FlyoutChip {
                id: next
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                glyph: true
                text: "󰅂"
                enabled: root.order.length > 1
                onClicked: root.step(1)
            }
        }

        // the palette, the accent's block wider
        ClippingRectangle {
            id: band
            readonly property var colours: root.swatches(Settings.look)
            readonly property bool accented: !!LookStore.looks[Settings.look] && !!LookStore.looks[Settings.look].accent
            width: parent.width
            height: Theme.fs(14)
            radius: Theme.radiusSmall
            color: "transparent"
            border.width: Theme.borderWidth
            border.color: Theme.stroke

            Row {
                anchors.fill: parent

                Repeater {
                    model: band.colours

                    Rectangle {
                        required property var modelData
                        required property int index
                        readonly property real share: band.accented ? band.colours.length + 0.6 : band.colours.length
                        width: band.width / share * (band.accented && index === band.colours.length - 1 ? 1.6 : 1)
                        height: band.height
                        color: modelData
                    }
                }
            }
        }
    }

    DropdownMenu {
        id: menu
        owner: root
        overlayHost: root.pageItem ? root.pageItem.parent : null
        open: root.open
        model: root.order
        currentIndex: root.index
        labelFor: v => LookStore.looks[v] ? LookStore.looks[v].name : v
        swatchesFor: v => root.swatches(v)
        maxRows: 7
        onPicked: v => Settings.set("look", v)
        onDismissed: root.close()
    }
}
