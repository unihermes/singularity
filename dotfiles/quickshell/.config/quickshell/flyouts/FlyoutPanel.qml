// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutPanel.qml
//
// Shared shell for every bar flyout: a full-screen, transparent layer-shell
// surface with the box on it. The box itself is PanelFrame.qml.
//
// How it goes away, the same on every flyout:
//   - a press anywhere else on this screen: the Backdrop behind the box
//   - a press anywhere else at all, the other monitor included: DismissGrab
//   - Escape: the panel holds the keyboard while open (OnDemand, which
//     Hyprland focuses as it maps), and focus goes back when it closes
//   - this monitor's workspace changing under it, by a bind or otherwise
// The bar is left out of the surface's input, so it stays live under an
// open flyout: another module opens its flyout in one click rather than
// two, its own module closes it, and scrolling on a chip still works. A
// press on the bar's ground closes it (Bar.qml). Nothing takes input while
// the flyout fades out, so a click straight after closing isn't lost.

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "../services"
import "../services/ChannelPath.js" as ChannelPath

OverlayWindow {
    id: root

    // This flyout's name in the bar's per-screen scope (shell.qml). The
    // scope holds which flyout is open and where it was clicked, so the
    // panel follows it rather than keeping any state of its own.
    required property string flyout

    readonly property bool open: scope.openFlyout === flyout
    // screen-local x (relative to this panel, which spans the whole
    // screen) that the box centres itself under
    readonly property real anchorX: scope.flyoutAnchorX
    // backdrop click, and content that wants to dismiss the flyout
    function requestClose() { scope.openFlyout = "" }

    property real menuWidth: 240
    // Exclusive keyboard focus rather than OnDemand: nothing else can take
    // the keyboard from it. Fixed, not bound to anything that changes while
    // it's up (see focusMode).
    property bool keyboardExclusive: false
    // distance from the bar's screen edge to the near edge of the box
    property real topOffset: Theme.flyoutOffset

    // How close the box may come to the left/right screen edge once the
    // clamp below catches it. The panels whose trigger sits at the very end
    // of the bar (control centre at the far left, battery at the far right)
    // set this to 0 so they run into the corner instead of leaving a sliver
    // of desktop showing beside them.
    property int edgeMargin: Theme.edgeMargin

    // data, not children, so a panel can hold non-visual helpers (a Timer,
    // a QsMenuOpener) alongside its rows; the Column still lays out only the
    // Items among them
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

    // Grown (Theme.flyoutGrown): the bar group this flyout opened from, in
    // this window's coordinates, which the box hangs off; null to sit as
    // usual. The section is kept from opening, so a closing flyout doesn't
    // jump to the next one's group.
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
    // the box's own rect: its width never follows the group's, so a side
    // that nearly lines up with the group's makes a short jog rather than
    // snapping flush (only a step of a pixel or two is closed)
    readonly property var grownRect: {
        if (!grown) return null
        var b = { x0: box.x, x1: box.x + box.width, r: grownRadius,
                  y0: atBottom ? box.y : group.y1, y1: atBottom ? group.y0 : box.y + box.height }
        return ChannelPath.snapTo(b, group, 2)
    }

    // Sectioned: each run of rows between headings and dividers sits in a
    // frame of its own, drawn in the style's frame (SectionRuns), and the
    // content is padded to clear both frames.
    readonly property int sectionGap: 3
    readonly property int sectionPadY: Theme.spaceS
    readonly property int padX: Theme.channelWidth * 2 + sectionGap + Theme.spaceL
    readonly property int padY: Theme.channelWidth * 2 + sectionGap + sectionPadY

    visible: open || reveal > 0
    // One mode for as long as the surface is up, fading out included: a
    // change while mapped doesn't focus it, and a step up to Exclusive ends
    // the grab (DismissGrab). Hyprland hands the keyboard back on unmap.
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

    // A drop slides the box out from under the bar, but the flyout is a layer
    // above the bar's: unclipped, the box's edge would pass over the chip it
    // opened from, which then looks briefly shorter. Everything on the bar's
    // side of the box's own edge is cut off instead.
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
                // within reach of a group edge, flush with it: the nearer one when
                // both are in reach, so a box about the group's width lines up
                // on the side its module is on
                var near = root.snapReach
                var d0 = Math.abs(free - root.group.x0)
                var d1 = Math.abs(free + width - root.group.x1)
                if (d0 < near && d0 <= d1) return root.group.x0
                if (d1 < near) return root.group.x1 - width
                return Math.round(free)
            }
            // Hangs off whichever edge the bar is on: below it at the top,
            // above it at the bottom. Measured from the far edge in the bottom
            // case so the box grows upward as rows are added, which keeps it
            // pinned to the bar instead of sliding down over the screen edge.
            y: (root.grown ? (atBottom ? root.group.y0 - height : root.group.y1)
                : atBottom ? root.height - root.topOffset - height
                : root.topOffset) - dropClip.y
            // its own width, except within a fillet and corner of its group's:
            // that close, a jog would be too short to read as a step, so it
            // takes the group's width and both sides run straight
            readonly property real ownWidth: Theme.fit(root.menuWidth) + (root.padX - Theme.panelPad) * 2
            width: root.grown && root.section !== "centre"
                    && Math.abs(ownWidth - (root.group.x1 - root.group.x0)) < root.snapReach
                ? root.group.x1 - root.group.x0 : ownWidth
            height: contentColumn.implicitHeight + root.padY * 2

            readonly property bool atBottom: Theme.barPosition === "bottom"
            // a tab's corners at the bar are square, so it hangs from it
            readonly property int barCorner: Theme.flyoutAttach === "tab" ? 0 : radius
            topLeftRadius: atBottom ? radius : barCorner
            topRightRadius: atBottom ? radius : barCorner
            bottomLeftRadius: atBottom ? barCorner : radius
            bottomRightRadius: atBottom ? barCorner : radius

            opacity: Theme.flyoutAnim === "none" ? 1 : root.reveal
            // drop: slides out from under the bar; scale: grows from the edge
            // at the bar, centred on the chip
            // a grown flyout only fades: its frame is joined to the bar
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
                y: root.padY
                width: parent.width - root.padX * 2
                spacing: Theme.spaceM
                // FlyoutHeading and FlyoutDivider make room for the sections
                readonly property bool sectioned: true

                // Marks the page LookStepper looks for when an open dropdown
                // needs a box to put its overlay in (see that file) -- the same
                // marker SettingsPage gives SettingsDropdown.
                readonly property bool isFlyoutPage: true
            }
        }
    }

    // Tab (Theme.flyoutAttach "tab"): the module it opened from is the tab
    // the box hangs from. Its sides and far edge are stroked down to the
    // box, and the box's own edge under it is covered, so chip and box read
    // as one shape. Strokes and the strip between them only: the module's
    // icon shows through from the bar underneath.
    Item {
        id: tab
        visible: Theme.flyoutAttach === "tab" && scope.flyoutAnchorW > 0 && !root.grown
        anchors.fill: parent
        opacity: box.opacity

        readonly property int bw: Theme.borderWidth
        readonly property real x0: Math.round(root.anchorX - scope.flyoutAnchorW / 2)
        readonly property real x1: Math.round(root.anchorX + scope.flyoutAnchorW / 2)
        // the chip's far and near edges, measured from the bar's screen edge
        readonly property real inset: Theme.barMargin + (Theme.barHeight - Theme.moduleHeight) / 2
        readonly property real far: box.atBottom ? root.height - inset : inset
        readonly property real near: box.atBottom ? root.height - inset - Theme.moduleHeight : inset + Theme.moduleHeight
        // the box's edge facing the bar
        readonly property real edge: dropClip.y + (box.atBottom ? box.y + box.height : box.y)
        readonly property real y0: Math.min(far, edge)
        readonly property real y1: Math.max(far, edge)

        // between the chip and the box, and over the box's edge
        Rectangle {
            x: tab.x0 + tab.bw
            width: tab.x1 - tab.x0 - tab.bw * 2
            y: box.atBottom ? tab.edge - tab.bw : tab.near
            height: box.atBottom ? tab.near - tab.edge + tab.bw : tab.edge + tab.bw - tab.near
            color: box.ground
        }
        Rectangle { x: tab.x0; y: tab.y0; width: tab.bw; height: tab.y1 - tab.y0 + tab.bw; color: Theme.stroke }
        Rectangle { x: tab.x1 - tab.bw; y: tab.y0; width: tab.bw; height: tab.y1 - tab.y0 + tab.bw; color: Theme.stroke }
        Rectangle {
            x: tab.x0
            y: box.atBottom ? tab.far - tab.bw : tab.far
            width: tab.x1 - tab.x0
            height: tab.bw
            color: Theme.stroke
        }
    }
}
