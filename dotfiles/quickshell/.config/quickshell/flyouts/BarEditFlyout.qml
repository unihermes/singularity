// Singularity - Quickshell
// ~/.config/quickshell/flyouts/BarEditFlyout.qml
//
// The edit shelf: open, the bar is in edit mode (BarEditor). It holds the
// hidden modules as chips, a drop zone for taking one off the bar, Reset
// and Done. Its chips' drags go through the bar's editor, so a chip can be
// dragged straight up into place; it also draws the dragged module while
// the pointer is off the bar.

import QtQuick
import "../services"

FlyoutPanel {
    id: shelf
    flyout: "baredit"
    menuWidth: 300

    readonly property var editor: scope.barWindow ? scope.barWindow.editor : null
    readonly property bool dragging: !!editor && editor.dragKey !== ""
    readonly property bool hideLit: dragging && !editor.overBar

    // the bar window's top in this one's coordinates
    readonly property real barTop: atBottom ? height - scope.barWindow.implicitHeight : 0

    // the hidden modules, held still while a drag runs (the chip being
    // dragged must outlive it)
    readonly property var hiddenNow: Settings.widgetSections.reduce(
        (a, s) => a.concat(Settings.widgetOrder(s).filter(k => !Settings.widgetVisible(k))), [])
    property var hiddenKeys: []
    onHiddenNowChanged: if (!dragging) hiddenKeys = hiddenNow
    onDraggingChanged: if (!dragging) hiddenKeys = hiddenNow
    Component.onCompleted: hiddenKeys = hiddenNow

    FlyoutHeading { text: "EDIT BAR" }

    Text {
        width: parent.width
        wrapMode: Text.Wrap
        text: "Drag modules along the bar, or down here to hide them. Click a centre module to pin it to the middle."
        color: Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontCaption
    }

    component Chip: Rectangle {
        id: chip
        required property string key
        readonly property var info: Settings.widgetMeta[key] || { label: key, icon: "" }
        property bool ghost: false
        readonly property bool held: !ghost && shelf.dragging && shelf.editor.dragKey === key
        width: chipRow.implicitWidth + Theme.spaceM * 2
        height: Theme.chipHeight + Theme.spaceXs
        radius: Theme.radiusInner
        color: ghost ? Theme.overlay : chipMouse.containsMouse ? Theme.hoverFillSoft : Theme.surface
        border.width: Theme.borderWidth
        border.color: ghost ? Theme.accent : Theme.stroke
        opacity: held ? 0.35 : 1

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: Theme.spaceS
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.info.icon
                color: Theme.subtext
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontIconSize
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.info.label
                color: Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
                font.weight: Theme.weightBody
            }
        }

        // in the bar window's coordinates, as the editor takes them
        MouseArea {
            id: chipMouse
            anchors.fill: parent
            enabled: !chip.ghost
            hoverEnabled: true
            preventStealing: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            function barPoint(mouse) {
                var p = mapToItem(null, mouse.x, mouse.y)
                return Qt.point(p.x, p.y - shelf.barTop)
            }
            onPressed: mouse => {
                var p = barPoint(mouse)
                shelf.editor.press(chip.key, p.x, p.y, true)
            }
            onPositionChanged: mouse => {
                if (!pressed) return
                var p = barPoint(mouse)
                shelf.editor.move(p.x, p.y)
            }
            onReleased: shelf.editor.release()
            onCanceled: shelf.editor.reset()
        }
    }

    // the hidden modules, and where a dragged one is dropped to hide it
    Rectangle {
        width: parent.width
        height: Math.max(Theme.chipHeight + Theme.spaceXs, hiddenFlow.implicitHeight) + Theme.spaceM * 2
        radius: Theme.radiusInner
        color: shelf.hideLit ? Theme.selectedFill : "transparent"
        border.width: Theme.borderWidth
        border.color: shelf.hideLit ? Theme.accent : Theme.stroke

        Text {
            visible: shelf.hiddenKeys.length === 0
            anchors.centerIn: parent
            text: "Nothing hidden"
            color: Theme.muted
            font.family: Theme.fontText
            font.pixelSize: Theme.fontCaption
        }

        Flow {
            id: hiddenFlow
            x: Theme.spaceM
            y: Theme.spaceM
            width: parent.width - Theme.spaceM * 2
            spacing: Theme.spaceS
            Repeater {
                model: shelf.hiddenKeys
                Chip { required property string modelData; key: modelData }
            }
        }
    }

    FlyoutDivider {}

    FlyoutRow {
        leadingIcon: "󰑓"
        label: "Reset to defaults"
        enabled: !Settings.widgetsDefault
        onActivated: Settings.resetWidgets()
    }

    FlyoutRow {
        leadingIcon: "󰄬"
        label: "Done"
        onActivated: shelf.requestClose()
    }

    // the dragged module while it's off the bar, over everything
    Chip {
        parent: shelf.contentItem
        visible: shelf.hideLit
        ghost: true
        key: shelf.dragging ? shelf.editor.dragKey : ""
        z: 100
        x: shelf.dragging ? shelf.editor.dragX - width / 2 : 0
        y: shelf.dragging ? shelf.editor.dragY + shelf.barTop - height / 2 : 0
    }
}
