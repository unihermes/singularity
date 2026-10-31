// Singularity - Quickshell
// ~/.config/quickshell/bar/WindowsModule.qml
//
// The open windows after the workspaces, in one frame: the focused
// workspace's or every workspace's (Theme.windowScope), drawn per
// Theme.windowStyle (icons, titled, glide, lift, inset, segmented,
// spotlight, tabs, index, dots). An app with several windows shows it in
// each style: pips, notches, a count, stacked slot edges or a ringed dot.
// The icons sit dead centre; every mark goes on the screen edge's side of
// them, above on a top bar and below on a bottom one.

import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../services"

ModuleFrame {
    required property var host
    anchors.verticalCenter: parent.verticalCenter
    spacing: 0
    // an empty chip on a bare workspace would be a floating
    // rectangle with nothing in it
    visible: iconRepeater.count > 0 && Settings.widgetVisible("windows")
    hoverWhole: false
    // the plain icon styles give each icon a slot as wide as the tray's,
    // whose room either side would otherwise stack on the chip's own padding
    padH: Theme.modulePadH - (["icons", "titled", "glide", "lift"].indexOf(Theme.windowStyle) >= 0
        && !Theme.moduleTaskbar ? Math.floor((Theme.iconSlotW - Theme.barFs(16)) / 2) : 0)

    Item {
        id: strip
        implicitWidth: stripRow.implicitWidth
        implicitHeight: Theme.moduleHeight

        readonly property string style: Theme.windowStyle
        // the focused window's place in the strip, -1 when it isn't in it
        readonly property int focusIndex: {
            var a = Hyprland.activeToplevel
            var m = iconRepeater.model
            if (!a || !m) return -1
            for (var i = 0; i < m.length; i++)
                if (m[i].windows.some(w => w.address === a.address)) return i
            return -1
        }
        // marks go toward the screen's edge
        readonly property bool atBottom: Theme.barPosition === "bottom"
        // a full-size icon's top and bottom, centred in the strip
        readonly property int iconTop: Math.round((Theme.moduleHeight - Theme.barFs(16)) / 2)
        readonly property int iconBottom: iconTop + Theme.barFs(16)
        // glide's rail, a pixel clear of the icons on the edge's side
        readonly property int markY: atBottom ? iconBottom + 1 : iconTop - 2

        Row {
            id: stripRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: strip.style === "tabs" || strip.style === "dots" || strip.style === "spotlight"
                    || strip.style === "index" ? Theme.spaceXs
                : strip.style === "segmented" || strip.style === "inset"
                    || strip.style === "lift" || strip.style === "icons" || strip.style === "titled"
                    || strip.style === "glide" || Theme.moduleTaskbar ? 0 : Theme.spaceS

            Repeater {
                id: iconRepeater
                model: host.bar.focusedWorkspaceIcons()

                Item {
                    id: winIcon
                    required property var modelData
                    required property int index
                    readonly property bool focused: strip.focusIndex === index
                    // the icon whose window list is open is lit as if
                    // hovered, rather than the whole strip
                    readonly property bool opened: host.screenScope.openFlyout === "appwindows"
                        && host.bar.appWindowsKey === modelData.key
                    readonly property bool hovered: winMouse.containsMouse || opened
                    readonly property bool lit: focused || hovered
                    readonly property string style: strip.style
                    readonly property bool dots: style === "dots"
                    readonly property bool tabs: style === "tabs"
                    readonly property bool glide: style === "glide"
                    readonly property bool spot: style === "spotlight"
                    readonly property bool seg: style === "segmented"
                    readonly property bool inset: style === "inset"
                    readonly property bool lift: style === "lift"
                    readonly property bool indexed: style === "index"
                    readonly property bool showTitle: tabs || ((style === "titled" || spot) && focused)
                    // Theme.windowMark, for the two icon styles
                    readonly property string mark: style === "icons" || style === "titled"
                        ? Theme.windowMark : ""
                    readonly property bool pillMark: mark === "pill"
                    // Flat's taskbar: each icon a wide slot, the focused
                    // one on a lit ground, the pips on the screen edge
                    readonly property bool slotted: Theme.moduleTaskbar && (style === "icons" || style === "titled")
                    readonly property bool slotLit: slotted && focused
                    // the app's window in focus, else its main one
                    readonly property var shown: {
                        var a = Hyprland.activeToplevel
                        var ws = modelData.windows
                        for (var i = 0; a && i < ws.length; i++)
                            if (ws[i].address === a.address) return ws[i]
                        return modelData
                    }
                    readonly property string title: shown.toplevel ? shown.toplevel.title || "" : ""
                    // how many windows the app has, and which of them is shown
                    readonly property int winCount: modelData.windows.length
                    readonly property bool multi: winCount > 1
                    readonly property int shownIndex: Math.max(0, modelData.windows.findIndex(w => w.address === shown.address))
                    // the styles without a pip of their own grow one per
                    // window when there's more than one
                    readonly property bool morePips: multi && (mark === "ground" || inset || seg)
                    readonly property bool pipsShown: pillMark || morePips
                    // the window count on the icon's corner
                    readonly property bool badged: multi && (lift || (spot && !focused))
                    // glide's rail: a notch per window under the icon
                    readonly property int notchSegs: Math.min(4, winCount)
                    readonly property real notchW: (iconPx - (notchSegs - 1)) / notchSegs
                    readonly property bool notched: glide && multi
                    // room for the rule between workspaces, in "all" scope
                    readonly property int lead: modelData.groupStart ? Theme.spaceS + 1 : 0
                    readonly property int iconPx: spot && !focused ? Theme.barFs(12)
                        : lift ? (focused ? Theme.barFs(18) : Theme.barFs(12)) : Theme.barFs(16)
                    // lift keeps a slot the size of its largest icon, so
                    // focusing a window doesn't shuffle the strip
                    readonly property int slotW: lift ? Theme.barFs(18) : glyphBox.width
                    // the icon, the dot or the label, and the title after it
                    readonly property int bodyWidth: dots ? dot.width
                        : indexed ? indexNum.implicitWidth + Theme.spaceS + indexName.width
                        : slotW + (titleText.width > 0
                            ? Math.min(titleGap, titleText.width) + titleText.width : 0)
                            + (spotCount.visible ? Theme.spaceS + spotCount.implicitWidth : 0)
                    readonly property int titleGap: spot ? Theme.spaceS : Theme.spaceXs
                    // spotlight's capsule is fully rounded, so its icon
                    // sits further in to clear the curve; the plain styles'
                    // slots are the tray's width (Theme.iconSlotW)
                    readonly property int padX: spot ? Theme.spaceS + 2
                        : tabs || seg || indexed || inset ? Theme.spaceS
                        : dots ? 1 : slotted ? Theme.spaceL : Math.floor((Theme.iconSlotW - slotW) / 2)
                    // tabs share a fixed budget, so a crowded workspace shortens
                    // every title rather than pushing into the bar's centre
                    readonly property int tabTitleMax: Math.max(Theme.fit(40), Math.min(Theme.fit(140),
                        Theme.fit(520) / Math.max(1, iconRepeater.count) - glyphBox.width - padX * 2 - Theme.spaceXs))
                    // the label colour on an accent ground
                    readonly property color textOnAccent: Theme.hasAccent
                        ? Theme.textOnAccent : Theme.textStrong

                    anchors.verticalCenter: parent.verticalCenter
                    // a little wider than the icon, so neighbours' pips
                    // don't run together and each is a comfortable target
                    implicitWidth: lead + bodyWidth + padX * 2
                    implicitHeight: Theme.moduleHeight

                    Behavior on implicitWidth {
                        enabled: winIcon.style === "titled"
                        NumberAnimation { duration: Theme.durFast; easing.type: Theme.ease }
                    }

                    // the rule between one workspace's windows and the next's
                    Rectangle {
                        visible: winIcon.modelData.groupStart
                        x: 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: Math.round(Theme.moduleHeight * 0.5)
                        color: Theme.stroke
                    }

                    // segmented: the hairline between two segments, gone
                    // beside the lit one
                    Rectangle {
                        visible: winIcon.seg && winIcon.index > 0 && !winIcon.modelData.groupStart
                            && !winIcon.focused && strip.focusIndex !== winIcon.index - 1
                        x: 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: Math.round(Theme.moduleHeight * 0.45)
                        color: Theme.stroke
                    }

                    // the hover fill under this window, for styles with no
                    // ground of their own (and Flat's focused taskbar slot)
                    Rectangle {
                        visible: (winIcon.hovered || winIcon.slotLit) && !winIcon.tabs && !winIcon.seg && !winIcon.spot
                            && !winIcon.indexed && !winIcon.inset
                            && winIcon.mark !== "ground"
                        x: winIcon.lead
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - winIcon.lead
                        height: Theme.iconHoverHeight
                        radius: Theme.moduleStyle === "grouped" ? Theme.radius : Theme.radiusSmall
                        color: Theme.overlay
                        border.width: winIcon.opened ? Theme.borderWidth : 0
                        border.color: Theme.strokeFocus
                    }

                    // a tab's ground: lit under the focused window, a hover
                    // fill under the others
                    Rectangle {
                        visible: winIcon.tabs
                        x: winIcon.lead
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - winIcon.lead
                        height: Theme.moduleHeight - 6
                        radius: Theme.radiusSmall
                        color: winIcon.focused ? Theme.selectedFill
                            : winIcon.hovered ? Theme.overlay : "transparent"
                        border.width: winIcon.focused ? Theme.borderWidth : 0
                        border.color: Theme.strokeFocus
                        Behavior on color { ColorAnimation { duration: Theme.durFast; easing.type: Theme.ease } }

                        // the underline, a segment per window when the app
                        // has more than one
                        Row {
                            id: tabLine
                            readonly property int segs: winIcon.multi ? Math.min(4, winIcon.winCount) : 1
                            visible: winIcon.focused || winIcon.multi
                            y: strip.atBottom ? parent.height - height : 0
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 2
                            Repeater {
                                model: tabLine.segs
                                Rectangle {
                                    required property int index
                                    width: (winIcon.width - winIcon.lead - Theme.spaceS * 2 - tabLine.spacing * (tabLine.segs - 1)) / tabLine.segs
                                    height: Theme.indicatorWidth
                                    radius: Theme.pill(height)
                                    color: winIcon.focused && (tabLine.segs === 1 || index === Math.min(3, winIcon.shownIndex)) ? Theme.accent
                                        : winIcon.focused || winIcon.hovered ? Theme.subtext : Theme.muted
                                }
                            }
                        }
                    }

                    // index: the edges of more slots peeking out past this
                    // one on the screen edge's side, one per extra window
                    // (up to two)
                    Repeater {
                        model: winIcon.indexed && winIcon.multi ? Math.min(2, winIcon.winCount - 1) : 0
                        Item {
                            required property int index
                            readonly property int step: index + 1
                            readonly property int groundTop: 4
                            x: winIcon.lead + step * 3
                            y: strip.atBottom ? winIcon.height - groundTop + step * 2 - height : groundTop - step * 2
                            width: winIcon.width - winIcon.lead - step * 6
                            height: 2
                            readonly property color edge: step === 1 ? Theme.subtext : Theme.muted
                            Rectangle { y: strip.atBottom ? 1 : 0; width: parent.width; height: 1; color: parent.edge }
                            Rectangle { width: 1; height: 2; color: parent.edge }
                            Rectangle { x: parent.width - 1; width: 1; height: 2; color: parent.edge }
                        }
                    }

                    // segmented, spotlight, index: the slot's ground (accent
                    // under the focused window, hover fill under the rest)
                    Rectangle {
                        visible: winIcon.seg || winIcon.spot || winIcon.indexed
                        x: winIcon.lead
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - winIcon.lead
                        height: winIcon.indexed ? Theme.moduleHeight - 8 : Theme.moduleHeight - 6
                        radius: winIcon.spot ? Theme.pill(height) : Theme.radiusSmall
                        color: winIcon.focused
                            ? (winIcon.indexed ? (Theme.hasAccent ? Theme.accent : Theme.selectedFill)
                                : Qt.alpha(Theme.accent, 0.22))
                            : winIcon.hovered ? Theme.overlay : "transparent"
                        border.width: winIcon.focused && !winIcon.indexed ? Theme.borderWidth : 0
                        border.color: winIcon.spot ? Theme.accent : Qt.alpha(Theme.accent, 0.6)
                        Behavior on color { ColorAnimation { duration: Theme.durFast; easing.type: Theme.ease } }
                    }

                    // inset: the well the focused icon sits in, its inner
                    // stroke echoing the double frame
                    Rectangle {
                        visible: winIcon.inset && winIcon.lit
                        anchors.centerIn: glyphBox
                        width: glyphBox.width + 6
                        height: glyphBox.height + 4
                        radius: Theme.radiusSmall
                        color: winIcon.focused ? Theme.base : Theme.overlay
                        border.width: winIcon.focused ? 1 : 0
                        border.color: Theme.stroke

                        Rectangle {
                            visible: winIcon.focused
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: Math.max(0, parent.radius - 2)
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.surface
                        }
                    }

                    // "ground": the hover box's size behind the icon, lit
                    // for the focused window, a hover fill for the rest
                    Rectangle {
                        visible: winIcon.mark === "ground"
                        anchors.centerIn: glyphBox
                        width: Theme.iconSlotW
                        height: Theme.iconHoverHeight
                        radius: Theme.radiusSmall
                        color: winIcon.focused ? Theme.selectedFill
                            : winIcon.hovered && !winIcon.focused ? Theme.overlay : "transparent"
                        border.width: winIcon.focused ? Theme.borderWidth : 0
                        border.color: Theme.strokeFocus
                        Behavior on color { ColorAnimation { duration: Theme.durFast; easing.type: Theme.ease } }
                    }

                    Item {
                        id: glyphBox
                        visible: !winIcon.dots && !winIcon.indexed
                        x: winIcon.lead + winIcon.padX + Math.round((winIcon.slotW - width) / 2)
                        anchors.verticalCenter: parent.verticalCenter
                        width: winIcon.iconPx
                        height: winIcon.iconPx
                        opacity: winIcon.lift ? (winIcon.focused ? 1 : winIcon.hovered ? 0.9 : 0.5)
                            : winIcon.lit ? 1 : 0.55
                        Behavior on opacity { NumberAnimation { duration: Theme.durFast; easing.type: Theme.ease } }
                        Behavior on width {
                            enabled: winIcon.spot || winIcon.lift
                            NumberAnimation { duration: Theme.durMedium; easing.type: Theme.ease }
                        }
                        Behavior on height {
                            enabled: winIcon.spot || winIcon.lift
                            NumberAnimation { duration: Theme.durMedium; easing.type: Theme.ease }
                        }

                        TintedIcon {
                            anchors.fill: parent
                            visible: winIcon.modelData.source !== ""
                            source: winIcon.modelData.source
                            grey: winIcon.lift && !winIcon.lit
                        }

                        // apps with no themed icon, and the shell's own windows
                        Text {
                            anchors.centerIn: parent
                            visible: winIcon.modelData.source === ""
                            text: winIcon.modelData.glyph
                            color: winIcon.focused ? Theme.textStrong : Theme.text
                            font.family: Theme.fontIcon
                            font.pixelSize: Math.round(parent.height * 15 / 16)
                        }
                    }

                    Text {
                        id: titleText
                        visible: width > 0
                        anchors.left: glyphBox.right
                        anchors.leftMargin: Math.min(winIcon.titleGap, width)
                        anchors.verticalCenter: parent.verticalCenter
                        text: winIcon.title
                        // measured apart from the Text, whose implicitWidth
                        // follows its own width once that is 0 and elided
                        TextMetrics { id: titleMetrics; font: titleText.font; text: titleText.text }
                        width: winIcon.showTitle ? Math.min(Math.ceil(titleMetrics.advanceWidth), winIcon.tabs ? winIcon.tabTitleMax
                            : winIcon.spot ? Theme.fit(160) : Theme.fit(220)) : 0
                        elide: Text.ElideRight
                        color: winIcon.focused ? Theme.textStrong : winIcon.lit ? Theme.text : Theme.subtext
                        font.family: Theme.fontText
                        font.weight: Theme.weightBody
                        font.pixelSize: Theme.barLabelSize
                        Behavior on width {
                            enabled: winIcon.spot
                            NumberAnimation { duration: Theme.durMedium; easing.type: Theme.ease }
                        }
                    }

                    // spotlight: which of the app's windows the capsule is
                    Text {
                        id: spotCount
                        visible: winIcon.spot && winIcon.focused && winIcon.multi
                        anchors.left: titleText.right
                        anchors.leftMargin: Theme.spaceS
                        anchors.verticalCenter: parent.verticalCenter
                        text: (winIcon.shownIndex + 1) + "/" + winIcon.winCount
                        color: Theme.subtext
                        font.family: Theme.fontText
                        font.weight: Theme.weightBody
                        font.pixelSize: Theme.barLabelSize
                    }

                    // lift, and spotlight's small icons: the window count
                    // on the icon's corner
                    Rectangle {
                        visible: winIcon.badged
                        height: Theme.barFs(9)
                        width: Math.max(height, badgeText.implicitWidth + 4)
                        radius: Theme.pill(height)
                        x: glyphBox.x + glyphBox.width - width / 2 - 1
                        y: strip.atBottom ? Math.min(winIcon.height - height, glyphBox.y + glyphBox.height - height / 2 - 1)
                            : Math.max(0, glyphBox.y - height / 2 + 1)
                        color: winIcon.focused && Theme.hasAccent ? Theme.accent : Theme.overlay
                        Text {
                            id: badgeText
                            anchors.centerIn: parent
                            text: winIcon.winCount
                            color: winIcon.focused && Theme.hasAccent ? Theme.textOnAccent : Theme.text
                            font.family: Theme.fontText
                            font.weight: Theme.weightStrong
                            font.pixelSize: Theme.barFs(8)
                        }
                    }

                    // index: the window's place in the strip and its app
                    Text {
                        id: indexNum
                        visible: winIcon.indexed
                        x: winIcon.lead + winIcon.padX
                        anchors.verticalCenter: parent.verticalCenter
                        text: winIcon.index + 1
                        color: winIcon.focused ? winIcon.textOnAccent : Theme.muted
                        opacity: winIcon.focused ? 0.65 : 1
                        font.family: Theme.fontText
                        font.weight: Theme.weightBody
                        font.pixelSize: Theme.barLabelSize
                    }
                    Text {
                        id: indexName
                        visible: winIcon.indexed
                        anchors.left: indexNum.right
                        anchors.leftMargin: Theme.spaceS
                        anchors.verticalCenter: parent.verticalCenter
                        text: winIcon.modelData.name || ""
                        TextMetrics { id: nameMetrics; font: indexName.font; text: indexName.text }
                        width: winIcon.indexed ? Math.min(Math.ceil(nameMetrics.advanceWidth), Theme.fit(120)) : 0
                        elide: Text.ElideRight
                        color: winIcon.focused ? winIcon.textOnAccent : winIcon.hovered ? Theme.text : Theme.subtext
                        font.family: Theme.fontText
                        font.weight: Theme.weightBody
                        font.pixelSize: Theme.barLabelSize
                    }

                    // A pip beside the icon on the screen edge's side (on
                    // Flat's taskbar, on the edge itself); a segment per
                    // window (up to four, popouts shorter, the focused one
                    // in the accent) for an app with several. Inset,
                    // segmented and the "ground" mark show it only then.
                    Row {
                        id: pip
                        readonly property var segs: winIcon.modelData.windows.slice(0, 4)
                        readonly property bool split: segs.length > 1
                        visible: winIcon.pipsShown
                        readonly property int gap: winIcon.inset ? 3 : 1
                        y: winIcon.slotted && !winIcon.morePips ? (strip.atBottom ? winIcon.height - height : 0)
                            : strip.atBottom ? glyphBox.y + glyphBox.height + gap
                            : glyphBox.y - gap - height
                        anchors.horizontalCenter: glyphBox.horizontalCenter
                        spacing: 1
                        Repeater {
                            model: pip.segs
                            Rectangle {
                                required property var modelData
                                required property int index
                                height: Theme.indicatorWidth
                                radius: Theme.pill(height)
                                width: !pip.split ? (winIcon.focused && winIcon.slotted ? winIcon.width - winIcon.lead
                                        : winIcon.focused || winIcon.slotted ? glyphBox.width - 2 : Theme.barFs(6))
                                    : modelData.popout ? Theme.barFs(winIcon.focused ? 6 : 4)
                                    : Theme.barFs(winIcon.focused ? 7 : 4)
                                color: winIcon.focused && (!pip.split || index === Math.min(3, winIcon.shownIndex)) ? Theme.accent
                                    : winIcon.focused || winIcon.hovered ? Theme.subtext : Theme.muted
                                Behavior on width {
                                    NumberAnimation { duration: Theme.durFast; easing.type: Theme.ease }
                                }
                                Behavior on color { ColorAnimation { duration: Theme.durFast; easing.type: Theme.ease } }
                            }
                        }
                    }

                    // the dots style's whole mark
                    Rectangle {
                        id: dot
                        visible: winIcon.dots
                        x: winIcon.lead + winIcon.padX
                        anchors.verticalCenter: parent.verticalCenter
                        height: Theme.barFs(6)
                        width: winIcon.focused ? Theme.barFs(14) : height
                        radius: Theme.pill(height)
                        color: winIcon.focused ? Theme.accent
                            : winIcon.hovered ? Theme.subtext : Theme.muted
                        Behavior on width {
                            NumberAnimation { duration: Theme.durFast; easing.type: Theme.ease }
                        }
                        Behavior on color { ColorAnimation { duration: Theme.durFast; easing.type: Theme.ease } }
                    }

                    // dots: a ring round the dot of an app with more than
                    // one window
                    Rectangle {
                        visible: winIcon.dots && winIcon.multi
                        x: dot.x - 2
                        anchors.verticalCenter: dot.verticalCenter
                        width: dot.width + 4
                        height: dot.height + 4
                        radius: Theme.pill(height)
                        color: "transparent"
                        border.width: 1
                        border.color: winIcon.focused || winIcon.hovered ? Theme.subtext : Theme.muted
                    }

                    // glide: the rail's notch per window under the icon,
                    // which the slider lights for the window shown
                    Row {
                        visible: winIcon.notched
                        x: glyphBox.x
                        y: strip.markY - Math.floor((Theme.indicatorWidth - 1) / 2)
                        spacing: 1
                        Repeater {
                            model: winIcon.notched ? winIcon.notchSegs : 0
                            Rectangle {
                                width: winIcon.notchW
                                height: Theme.indicatorWidth
                                radius: Theme.pill(height)
                                color: winIcon.focused || winIcon.hovered ? Theme.subtext : Theme.muted
                            }
                        }
                    }

                    MouseArea {
                        id: winMouse
                        x: winIcon.lead
                        width: parent.width - winIcon.lead
                        height: parent.height
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            // the app's window in focus, or its main one
                            var target = winIcon.shown.address
                            var addr = "address:0x" + target
                            var bar = host.bar
                            // several windows, or a right-click: the app's
                            // windows to pick from, a right-click opening the
                            // clicked window's actions (another app's icon
                            // retargets it)
                            var right = mouse.button === Qt.RightButton
                            if (right || (mouse.button === Qt.LeftButton && winIcon.modelData.windows.length > 1)) {
                                bar.appWindowsOpen = right ? target : ""
                                if (host.screenScope.openFlyout === "appwindows"
                                        && bar.appWindowsKey !== winIcon.modelData.key) {
                                    bar.appWindowsKey = winIcon.modelData.key
                                    host.screenScope.flyoutAnchorX = winIcon.mapToItem(null, winIcon.width / 2, 0).x
                                    return
                                }
                                bar.appWindowsKey = winIcon.modelData.key
                                host.screenScope.toggleFlyout("appwindows", winIcon)
                            } else if (mouse.button === Qt.MiddleButton) {
                                Hyprland.dispatch("hl.dsp.window.close({window=\"" + addr + "\"})")
                            } else {
                                // focus and bring to top -- so floating windows stay
                                // accessible even when behind a monocle-maximized window
                                Hyprland.dispatch("hl.dsp.focus({window=\"" + addr + "\"})")
                                Hyprland.dispatch("hl.dsp.window.bring_to_top()")
                            }
                        }
                    }
                }
            }
        }

        // glide: the rail under every icon, and the slider that
        // travels along it to the focused one
        Rectangle {
            visible: strip.style === "glide"
            x: stripRow.x + Theme.spaceS / 2
            y: strip.markY
            width: stripRow.width - Theme.spaceS
            height: 1
            color: Theme.stroke
        }
        Rectangle {
            id: slider
            readonly property Item target: strip.style === "glide" && strip.focusIndex >= 0
                && strip.focusIndex < iconRepeater.count ? iconRepeater.itemAt(strip.focusIndex) : null
            visible: target !== null
            x: target ? stripRow.x + target.x + target.lead + target.padX
                + (target.notched ? Math.min(3, target.shownIndex) * (target.notchW + 1) : 0) : 0
            y: strip.markY - Math.floor((Theme.indicatorWidth - 1) / 2)
            width: target ? (target.notched ? target.notchW : target.iconPx) : 0
            z: 1
            height: Theme.indicatorWidth
            radius: Theme.pill(height)
            color: Theme.accent
            Behavior on x {
                enabled: slider.visible
                NumberAnimation { duration: Theme.durSlow; easing.type: Theme.ease }
            }
        }
    }
}
