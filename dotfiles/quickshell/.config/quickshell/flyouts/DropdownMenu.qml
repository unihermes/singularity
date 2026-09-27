// Singularity - Quickshell
// ~/.config/quickshell/flyouts/DropdownMenu.qml
//
// The open list of a dropdown, shared by FlyoutSelect (in a flyout) and
// SettingsDropdown (on a Settings page): every choice as a row, the current
// one ticked, scrolling past `maxRows`.
//
// It is drawn in an overlay filling `overlayHost` rather than inside the
// dropdown, above a catcher that closes it on a click anywhere else.
// Raising the dropdown's own ancestors instead cannot work: z orders
// siblings, so lifting an ancestor lifts that whole subtree, and the rest
// of the page comes with it and swallows the click. The overlay also
// escapes a page's Flickable, which clips.
//
// The dropdown places it (menuX, menuY, in overlayHost's coordinates) once,
// when it opens. While it's open the catcher swallows the wheel, so the page
// behind can't scroll out from under a list that doesn't follow it.

import QtQuick
import "../services"

Item {
    id: root

    // the dropdown this belongs to; the overlay falls back to it while
    // there is no host yet
    required property Item owner
    property var overlayHost: null
    property bool open: false
    property var model: []
    property int currentIndex: -1
    property var labelFor: v => String(v)
    property var fontFor: v => Theme.fontText
    // a choice's colour swatches, [] for none
    property var swatchesFor: v => []
    property int maxRows: 8
    property real menuX: 0
    property real menuY: 0
    property real menuWidth: owner.width

    // known without the list existing, so the dropdown can place it first
    readonly property int menuHeight: Math.min(model.length, maxRows) * Theme.rowHeight + Theme.spaceXs * 2

    signal picked(var value)
    signal dismissed()

    parent: overlayHost || owner
    anchors.fill: parent
    z: 9000
    // only while open, so nothing here takes a click or a wheel otherwise
    visible: open && overlayHost !== null
    enabled: visible

    onOpenChanged: if (open) list.positionViewAtIndex(Math.max(0, currentIndex), ListView.Center)

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: root.dismissed()
        onWheel: wheel => wheel.accepted = true
    }

    Rectangle {
        x: root.menuX
        y: root.menuY
        width: root.menuWidth
        height: root.menuHeight
        id: menuBox
        radius: Theme.radiusInner
        color: Theme.surface
        border.width: Theme.controlBorder(Theme.stroke)
        border.color: Theme.controlStroke(Theme.stroke)

        ControlEdge { radius: menuBox.radius }

        // a list too short to scroll mustn't pass the wheel through either
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => wheel.accepted = true
        }

        ListView {
            id: list
            x: Theme.spaceXs
            y: Theme.spaceXs
            width: parent.width - Theme.spaceXs * 2
            height: parent.height - Theme.spaceXs * 2
            clip: true
            interactive: root.model.length > root.maxRows
            boundsBehavior: Flickable.StopAtBounds
            // only while open: File Types puts sixty dropdowns on one page,
            // and a closed one has no reason to build delegates
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
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spaceL
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
                        // picked() first: closing collapses list.model right
                        // away, tearing down this delegate -- calling it
                        // after left `root` and `item` already gone, so the
                        // pick silently never fired.
                        if (!item.isCurrent) root.picked(item.modelData)
                        root.dismissed()
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
