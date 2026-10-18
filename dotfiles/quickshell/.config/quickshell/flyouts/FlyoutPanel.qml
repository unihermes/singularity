// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutPanel.qml
//
// Shared shell for every bar flyout: a full-screen transparent layer surface
// with the box (PanelFrame) on it. It closes on a press elsewhere (Backdrop,
// DismissGrab on other screens), Escape, or a workspace change. The bar
// stays outside its input, so modules work under an open flyout; nothing
// takes input while it fades out.

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "../services"
import "../services/ChannelPath.js" as ChannelPath

OverlayWindow {
    id: root

    // this flyout's name in the screen scope, which holds what's open and where
    required property string flyout

    readonly property bool open: scope.openFlyout === flyout
    // screen-local x (relative to this panel, which spans the whole
    // screen) that the box centres itself under
    readonly property real anchorX: scope.flyoutAnchorX
    // backdrop click, and content that wants to dismiss the flyout
    function requestClose() { scope.openFlyout = "" }

    property real menuWidth: 240
    // Exclusive keyboard focus instead of OnDemand; fixed while it's up
    property bool keyboardExclusive: false
    // distance from the bar's screen edge to the near edge of the box
    property real topOffset: Theme.flyoutOffset

    // how close the box may come to a screen edge (0 for the end panels, so
    // they run into the corner)
    property int edgeMargin: Theme.edgeMargin

    // data, not children, so non-visual helpers can sit among the rows
    default property alias content: contentColumn.data
    property alias contentColumn: contentColumn

    // 0 shut, 1 open: Theme.flyoutAnim plays over it both ways, and the
    // surface stays up until it has played out shut
    property real reveal: 0
    readonly property bool animated: Theme.flyoutAnim !== "none" && Theme.animFactor > 0
    NumberAnimation {
        id: revealAnim
        target: root
        property: "reveal"
        duration: Theme.dur(150)
        easing.type: Theme.ease
    }
    function play(to) {
        revealAnim.stop()
        if (!root.animated) { root.reveal = to; return }
        revealAnim.to = to
        revealAnim.start()
    }
    onOpenChanged: {
        if (open) section = scope.flyoutSection
        play(open ? 1 : 0)
    }
    Component.onCompleted: if (open) {
        section = scope.flyoutSection
        play(1)
    }

    // Grown (Theme.flyoutGrown): the bar group it hangs off, in this window's
    // coordinates, or null. The section is kept from opening.
    property string section: ""
    readonly property bool atBottom: Theme.barPosition === "bottom"
    readonly property var group: {
        if (!Theme.flyoutGrown || section === "" || !scope.barWindow) return null
        var g = scope.barWindow.groupRect(section)
        if (!g) return null
        var dy = atBottom ? root.height - scope.barWindow.implicitHeight : 0
        return { x0: g.x, x1: g.x + g.w, y0: g.y + dy, y1: g.y + g.h + dy, r: Theme.groupRadius }
    }
    readonly property bool grown: group !== null
    // how close a box edge or width must be to its group's to line up with it
    readonly property real snapReach: Theme.channelFillet + Math.max(Theme.groupRadius, grownRadius)
    readonly property int grownRadius: Theme.channelPanelRadius
    // the box's own rect, snapped to the group's sides only within 2px
    readonly property var grownRect: {
        if (!grown) return null
        var b = { x0: box.x, x1: box.x + box.width, r: grownRadius,
                  y0: atBottom ? box.y : group.y1, y1: atBottom ? group.y0 : box.y + box.height }
        return ChannelPath.snapTo(b, group, 2)
    }

    // Sectioned: each run of rows sits in its own frame (SectionRuns); the
    // content is padded to clear both frames.
    readonly property int sectionGap: 2
    readonly property int sectionPadY: Theme.spaceXs
    readonly property int padX: Theme.channelWidth * 2 + sectionGap + Theme.spaceM
    readonly property int padY: Theme.channelWidth * 2 + sectionGap + sectionPadY
    // Grown, the edge against the bar has no outline of its own (the group's
    // runs straight on into the box's), so it leaves out a channel's room.
    readonly property int padNear: grown ? padY - Theme.channelWidth : padY
    readonly property int padTop: atBottom ? padY : padNear

    visible: open || reveal > 0
    // one focus mode while the surface is up (a change while mapped doesn't
    // take, and a step to Exclusive would end DismissGrab's grab)
    focusMode: root.keyboardExclusive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    layerNamespace: "singularity-flyout"

    // input: the whole screen but the bar's strip while open, nothing while
    // it fades out
    mask: Region {
        item: root.open ? inputArea : null
        Region { item: barArea; intersection: Intersection.Subtract }
    }
    Item { id: inputArea; anchors.fill: parent }
    Item {
        id: barArea
        readonly property real barHeight: scope.barWindow ? scope.barWindow.implicitHeight : 0
        y: root.atBottom ? root.height - barHeight : 0
        width: root.width
        height: barHeight
    }

    DismissGrab {
        panel: root
        also: scope.allBars
    }

    Connections {
        target: Hyprland.monitorFor(root.screen)
        function onActiveWorkspaceChanged() { if (root.open) root.requestClose() }
    }

    // anywhere that isn't the box
    Backdrop {
        onDismissed: root.requestClose()
    }

    GrownFrame {
        visible: root.grown
        anchors.fill: parent
        opacity: box.opacity
        rects: !root.grown ? [] : root.atBottom ? [root.grownRect, root.group] : [root.group, root.grownRect]
        hole: !root.grown ? null : ({
            x0: root.group.x0 + Theme.channelWidth, x1: root.group.x1 - Theme.channelWidth,
            y0: root.group.y0 + Theme.channelWidth, y1: root.group.y1 - Theme.channelWidth,
            r: Theme.groupRadius - Theme.channelWidth
        })
    }

    // drop: clipped at the box's bar-side edge, so the sliding box doesn't
    // pass over its chip
    Item {
        id: dropClip
        // Escape from anywhere in the box that doesn't take it itself
        focus: true
        Keys.onEscapePressed: root.requestClose()
        readonly property bool cuts: Theme.flyoutAnim === "drop" && !root.grown
        y: cuts && !box.atBottom ? root.topOffset : 0
        width: root.width
        height: cuts ? root.height - root.topOffset : root.height
        clip: cuts

        PanelFrame {
            id: box
            bare: root.grown
            ground: Theme.surface
            x: {
                var free = Math.max(root.edgeMargin,
                                    Math.min(root.anchorX - width / 2,
                                             root.width - width - root.edgeMargin))
                // the centre group's flyouts stay centred on their module (the
                // clock's on the clock), however close a group edge comes
                if (!root.grown || root.section === "centre") return Math.round(free)
                // within reach of a group edge, flush with the nearer one
                var near = root.snapReach
                var d0 = Math.abs(free - root.group.x0)
                var d1 = Math.abs(free + width - root.group.x1)
                if (d0 < near && d0 <= d1) return root.group.x0
                if (d1 < near) return root.group.x1 - width
                return Math.round(free)
            }
            // hangs off the bar's edge; at the bottom measured from the far
            // edge, so it grows upward
            y: (root.grown ? (atBottom ? root.group.y0 - height : root.group.y1)
                : atBottom ? root.height - root.topOffset - height
                : root.topOffset) - dropClip.y
            // its own width, or the group's when within a fillet and corner
            // of it (too short a jog to read)
            readonly property real ownWidth: Theme.fit(root.menuWidth * Settings.flyoutWidth / 100) + (root.padX - Theme.panelPad) * 2
            width: root.grown && root.section !== "centre"
                    && Math.abs(ownWidth - (root.group.x1 - root.group.x0)) < root.snapReach
                ? root.group.x1 - root.group.x0 : ownWidth
            height: contentColumn.implicitHeight + root.padY + root.padNear

            readonly property bool atBottom: Theme.barPosition === "bottom"
            opacity: Theme.flyoutAnim === "none" ? 1 : root.reveal
            // drop slides out from under the bar, scale grows from it; grown
            // only fades
            transform: Translate {
                y: Theme.flyoutAnim === "drop" && !root.grown ? (1 - root.reveal) * Theme.sp(10) * (box.atBottom ? 1 : -1) : 0
            }
            scale: Theme.flyoutAnim === "scale" && !root.grown ? 0.9 + 0.1 * root.reveal : 1
            transformOrigin: atBottom ? Item.Bottom : Item.Top

            Behavior on height {
                NumberAnimation { duration: Theme.dur(90); easing.type: Theme.ease }
            }

            Absorber {}

            SectionRuns {
                x: Theme.channelWidth + root.sectionGap
                width: box.width - x * 2
                height: box.height
                column: contentColumn
                columnY: contentColumn.y
                padY: root.sectionPadY
            }

            Column {
                id: contentColumn
                x: root.padX
                y: root.padTop
                width: parent.width - root.padX * 2
                spacing: Theme.flyoutSpacing
                // FlyoutHeading and FlyoutDivider make room for the sections
                readonly property bool sectioned: true

                // the marker LookStepper looks for to place a dropdown's overlay
                readonly property bool isFlyoutPage: true
            }
        }
    }
}
