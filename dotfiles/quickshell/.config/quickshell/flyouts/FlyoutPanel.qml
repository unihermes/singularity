// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutPanel.qml
//
// Shared shell for every bar flyout: a full-screen, transparent,
// click-through-everywhere-except-the-box layer-shell surface. The
// full-screen size (rather than sizing to the box) is what makes
// "click anywhere else closes it" possible -- a MouseArea behind the
// box catches the click and closes the flyout; the box has its own
// MouseArea on top of that one, so clicks that land on the box itself
// don't reach the backdrop. The box itself is PanelFrame.qml.

import Quickshell
import Quickshell.Wayland
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
    // A layer-shell surface receives no key events unless it asks for focus,
    // so a text field in here would look focused and silently swallow every
    // keystroke. Only the panels that actually contain an input set this --
    // taking focus unconditionally would steal it from the focused window
    // every time any flyout opened.
    property bool wantsKeyboard: false
    // Stronger than wantsKeyboard: take the keyboard the moment the surface
    // is mapped, not on the next click into it. For search-as-you-type, where
    // making the user click the field first defeats the point. Safe because
    // the panel is transient -- focus goes back when it closes.
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
    focusMode: root.keyboardExclusive ? WlrKeyboardFocus.Exclusive
        : root.wantsKeyboard ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None
    layerNamespace: "singularity-flyout"

    // backdrop: anywhere that isn't the box
    MouseArea {
        anchors.fill: parent
        onClicked: root.requestClose()
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

    PanelFrame {
        id: box
        bare: root.grown
        ground: Theme.surface
        x: {
            var free = Math.max(root.edgeMargin,
                                Math.min(root.anchorX - width / 2,
                                         root.width - width - root.edgeMargin))
            if (!root.grown) return free
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
        y: root.grown ? (atBottom ? root.group.y0 - height : root.group.y1)
            : atBottom ? root.height - root.topOffset - height
            : root.topOffset
        // its own width, except within a fillet and corner of its group's:
        // that close, a jog would be too short to read as a step, so it
        // takes the group's width and both sides run straight
        readonly property real ownWidth: Theme.fit(root.menuWidth) + (root.padX - Theme.panelPad) * 2
        width: root.grown && Math.abs(ownWidth - (root.group.x1 - root.group.x0)) < root.snapReach
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

        // absorbs clicks so they don't fall through to the backdrop
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

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

            // Marks the page FlyoutSelect looks for when an open dropdown
            // needs a box to put its overlay in (see that file) -- the same
            // marker SettingsPage gives SettingsDropdown.
            readonly property bool isFlyoutPage: true
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
        readonly property real edge: box.atBottom ? box.y + box.height : box.y
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
