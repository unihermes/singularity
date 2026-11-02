// Singularity - Quickshell
// ~/.config/quickshell/bar/WindowsModule.qml
//
// The open windows after the workspaces, in one frame: the focused
// workspace's or every workspace's (Theme.windowScope), drawn per
// Theme.windowStyle (icons, glide, lift, inset, segmented, rings, fade,
// viewfinder, tint, liquid), never with text. An app with several windows
// shows it in each style: pips, notches, a count, arcs, ghost copies,
// ticks or stacked edges.
// The icons sit dead centre; every mark goes on the screen edge's side of
// them, above on a top bar and below on a bottom one.

import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import "../services"

ModuleFrame {
    id: windowsModule
    required property var host
    anchors.verticalCenter: parent.verticalCenter
    spacing: 0
    // an empty chip on a bare workspace would be a floating
    // rectangle with nothing in it
    visible: iconRepeater.count > 0 && Settings.widgetVisible("windows")
    hoverWhole: false
    // the plain icon styles give each icon a wide slot (Theme.iconSlotW),
    // whose room either side would otherwise stack on the chip's own padding
    padH: Math.max(0, Theme.modulePadH - (strip.wideSlots && !Theme.moduleTaskbar ? Theme.windowIconPadding : 0))

    // four corner brackets round a box, viewfinder's mark
    component Corners: Item {
        property color ink: Theme.accent
        readonly property int arm: 5
        readonly property int stroke: 2
        Repeater {
            model: 4
            Item {
                required property int index
                readonly property bool east: index % 2 === 1
                readonly property bool south: index > 1
                x: east ? parent.width - width : 0
                y: south ? parent.height - height : 0
                width: parent.arm
                height: parent.arm
                Rectangle { y: parent.south ? parent.height - height : 0; width: parent.width; height: parent.parent.stroke; color: parent.parent.ink }
                Rectangle { x: parent.east ? parent.width - width : 0; width: parent.parent.stroke; height: parent.height; color: parent.parent.ink }
            }
        }
    }

    // tint's wash: the app's own icon blown up and blurred to its colours,
    // seen through `mask` (an Item of the wash's size, drawn in white)
    component Wash: Item {
        id: wash
        property string source: ""
        property Item mask
        property real iconX
        property real iconY
        property int iconPx
        // brighter, for a thin line that has to read
        property real lift: 0
        layer.enabled: visible
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: wash.mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.01
        }
        IconImage {
            x: wash.iconX + wash.iconPx / 2 - width / 2
            y: wash.iconY + wash.iconPx / 2 - height / 2
            width: Math.max(wash.iconPx * 3, 2 * (wash.iconX + wash.iconPx / 2),
                2 * (wash.width - wash.iconX - wash.iconPx / 2), 2 * (wash.iconY + wash.iconPx / 2),
                2 * (wash.height - wash.iconY - wash.iconPx / 2))
            height: width
            source: wash.source
            layer.enabled: wash.visible
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1
                blurMax: 32
                saturation: 0.3
                brightness: wash.lift
            }
        }
    }

    Item {
        id: strip
        implicitWidth: stripRow.implicitWidth
        implicitHeight: Theme.moduleHeight

        readonly property string style: Theme.windowStyle
        readonly property bool wideSlots: ["icons", "glide", "lift", "rings", "fade", "viewfinder", "tint", "liquid"]
            .indexOf(style) >= 0
        // the focused window's place in the strip, -1 when it isn't in it
        readonly property int focusIndex: {
            var a = Hyprland.activeToplevel
            var m = iconRepeater.model
            if (!a || !m) return -1
            for (var i = 0; i < m.length; i++)
                if (m[i].windows.some(w => w.address === a.address)) return i
            return -1
        }
        readonly property Item focusItem: focusIndex >= 0 && focusIndex < iconRepeater.count
            ? iconRepeater.itemAt(focusIndex) : null
        // marks go toward the screen's edge
        readonly property bool atBottom: Theme.barPosition === "bottom"
        // Match the geometry actually drawn by ModuleFrame or the shared group.
        readonly property bool closedFrame: Theme.frameStroked
            && (!Theme.frameCustom || Theme.frameStyle === "notch" || Theme.frameStyle === "bevel")
        readonly property bool grouped: Theme.moduleGrouped && closedFrame
        readonly property bool framed: grouped || (closedFrame && (Theme.moduleStyle === "outline"
            || (Theme.frameCustom && Theme.moduleStyle !== "bare")))
        readonly property real frameInset: Theme.frameCustom && Theme.frameStyle === "bevel" ? Theme.borderWidth * 1.5
            : Theme.frameDouble && style !== "tint" ? 2 + Theme.borderWidth
            : grouped && Theme.frameChannel ? Theme.channelWidth : Theme.borderWidth
        readonly property bool leftEnd: !grouped || groupEnd(false)
        readonly property bool rightEnd: !grouped || groupEnd(true)
        function groupEnd(reverse) {
            var order = Settings.widgetOrder(host.bar.sectionOf(windowsModule))
            for (var n = 0; n < order.length; n++) {
                var key = order[reverse ? order.length - n - 1 : n]
                var item = host.bar.slotItem(key)
                if (item && item.visible) return item === windowsModule
            }
            return false
        }
        readonly property real frameHeight: grouped ? Theme.groupHeight : windowsModule.chipHeight
        readonly property real fillHeight: framed ? Math.max(0, frameHeight - frameInset * 2) : Theme.iconHoverHeight
        readonly property real fillRadius: framed ? (Theme.frameCustom ? 0
            : Math.max(0, (grouped ? Theme.groupRadius : Theme.radius) - frameInset)) : Theme.radiusSmall
        readonly property real endBleed: framed ? windowsModule.padH + (grouped ? Theme.channelWidth : 0) - frameInset : 0
        readonly property var groupFrame: grouped ? host.bar.groupRect(host.bar.sectionOf(windowsModule)) : null
        readonly property real cut: framed && Theme.frameCustom && Theme.frameStyle === "notch"
            ? Math.max(0, Math.min(Theme.notchSize, (groupFrame ? groupFrame.w : windowsModule.width) / 4, frameHeight / 3) - frameInset * (2 - Math.SQRT2)) : 0
        readonly property real segmentHeight: fillHeight
        // a full-size icon's top and bottom, centred in the strip
        readonly property int iconTop: Math.round((Theme.moduleHeight - Theme.windowIconSize) / 2)
        readonly property int iconBottom: iconTop + Theme.windowIconSize
        // glide's groove, in the gap between the icons and the screen's edge
        readonly property int markH: 3
        readonly property int markY: atBottom ? Math.min(Theme.moduleHeight - markH, iconBottom + 1)
            : Math.max(0, iconTop - markH - 1)

        // segmented: the outlined track every segment sits in
        Rectangle {
            visible: strip.style === "segmented" && !strip.framed
            z: 2
            x: stripRow.x
            width: stripRow.width
            height: strip.segmentHeight
            anchors.verticalCenter: parent.verticalCenter
            radius: Theme.radiusSmall
            color: "transparent"
            border.width: 1
            border.color: Theme.stroke
        }

        // liquid: the blob behind the focused icon; on a move its leading
        // edge goes first and the trailing one catches up
        WindowSlotFill {
            id: blob
            readonly property Item target: strip.style === "liquid" ? strip.focusItem : null
            readonly property real wantL: target ? stripRow.x + target.x + (strip.framed ? target.fillX : 1) : 0
            readonly property real wantR: target ? stripRow.x + target.x + (strip.framed ? target.fillX + target.fillWidth : target.width - 1) : 0
            property real l: 0
            property real r: 0
            property bool rightward: true
            property int lastIndex: -1
            visible: target !== null
            x: l
            width: Math.max(0, r - l)
            height: strip.fillHeight
            anchors.verticalCenter: parent.verticalCenter
            radius: height / 2
            topLeftRadius: strip.framed ? (target && target.first && strip.leftEnd ? strip.fillRadius : 0) : radius
            bottomLeftRadius: topLeftRadius
            topRightRadius: strip.framed ? (target && target.last && strip.rightEnd ? strip.fillRadius : 0) : radius
            bottomRightRadius: topRightRadius
            leftCut: target && target.first && strip.leftEnd ? strip.cut : 0
            rightCut: target && target.last && strip.rightEnd ? strip.cut : 0
            color: Qt.alpha(Theme.accent, 0.45)
            onWantLChanged: place()
            onWantRChanged: place()
            function place() {
                if (strip.focusIndex !== lastIndex) {
                    rightward = strip.focusIndex > lastIndex
                    lastIndex = strip.focusIndex
                }
                l = wantL
                r = wantR
            }
            Behavior on l {
                enabled: blob.visible
                NumberAnimation { duration: blob.rightward ? Theme.dur(300) : Theme.durMedium; easing.type: Theme.ease }
            }
            Behavior on r {
                enabled: blob.visible
                NumberAnimation { duration: blob.rightward ? Theme.durMedium : Theme.dur(300); easing.type: Theme.ease }
            }
        }

        Row {
            id: stripRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: strip.style === "segmented" || strip.style === "inset" || strip.wideSlots
                || Theme.moduleTaskbar ? 0 : Theme.spaceS

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
                    readonly property bool glide: style === "glide"
                    readonly property bool seg: style === "segmented"
                    readonly property bool inset: style === "inset"
                    readonly property bool lift: style === "lift"
                    readonly property bool rings: style === "rings"
                    readonly property bool fade: style === "fade"
                    readonly property bool finder: style === "viewfinder"
                    readonly property bool tint: style === "tint"
                    readonly property bool liquid: style === "liquid"
                    // Theme.windowMark, for the icons style
                    readonly property string mark: style === "icons" ? Theme.windowMark : ""
                    readonly property bool pillMark: mark === "pill"
                    // Flat's taskbar: each icon a wide slot, the focused
                    // one on a lit ground, the pips on the screen edge
                    readonly property bool slotted: Theme.moduleTaskbar && style === "icons"
                    readonly property bool slotLit: slotted && focused
                    // the app's window in focus, else its main one
                    readonly property var shown: {
                        var a = Hyprland.activeToplevel
                        var ws = modelData.windows
                        for (var i = 0; a && i < ws.length; i++)
                            if (ws[i].address === a.address) return ws[i]
                        return modelData
                    }
                    // how many windows the app has, and which of them is shown
                    readonly property int winCount: modelData.windows.length
                    readonly property bool multi: winCount > 1
                    readonly property int shownIndex: Math.max(0, modelData.windows.findIndex(w => w.address === shown.address))
                    // the styles without a pip of their own grow one per
                    // window when there's more than one
                    readonly property bool morePips: multi && (mark === "ground" || inset || seg || liquid)
                    readonly property bool pipsShown: pillMark || morePips
                    // the window count on the icon's corner
                    readonly property bool badged: multi && lift
                    // glide's rail: a notch per window under the icon
                    readonly property int notchSegs: Math.min(4, winCount)
                    readonly property real notchW: (iconPx - (notchSegs - 1)) / notchSegs
                    readonly property bool notched: glide && multi
                    readonly property int smallIconPx: Math.round(Theme.windowIconSize * 0.75)
                    readonly property int largeIconPx: Math.min(Theme.moduleHeight - 8, Math.round(Theme.windowIconSize * 1.125))
                    // rings: the ring as tall as the strip allows, the icon inside it
                    readonly property int ringPx: Math.min(Theme.moduleHeight, Theme.windowIconSize + 8)
                    readonly property int iconPx: lift ? (focused ? largeIconPx : smallIconPx)
                        : rings ? ringPx - 10 : Theme.windowIconSize
                    // lift keeps a slot the size of its largest icon, so
                    // focusing a window doesn't shuffle the strip; rings
                    // one the ring's size
                    readonly property int slotW: lift ? largeIconPx : rings ? ringPx : glyphBox.width
                    readonly property int padX: Theme.windowIconPadding
                    readonly property bool first: index === 0
                    readonly property bool last: index === iconRepeater.count - 1
                    readonly property real fillX: first ? -(strip.leftEnd ? strip.endBleed : strip.framed ? windowsModule.padH : 0) : 0
                    readonly property real fillWidth: width - fillX + (last ? (strip.rightEnd ? strip.endBleed : strip.framed ? windowsModule.padH : 0) : 0)
                    // viewfinder's and tint's box round the icon
                    readonly property int boxPx: Theme.windowIconSize + 6

                    anchors.verticalCenter: parent.verticalCenter
                    // a little wider than the icon, so neighbours' pips
                    // don't run together and each is a comfortable target
                    implicitWidth: slotW + padX * 2
                    implicitHeight: Theme.moduleHeight

                    // the rule between one workspace's windows and the next's,
                    // centred in the gap so it takes no room of its own
                    Rectangle {
                        visible: winIcon.index > 0 && winIcon.modelData.groupStart
                        z: 1
                        x: -Math.round(stripRow.spacing / 2)
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: strip.framed || winIcon.seg ? strip.fillHeight : Math.round(Theme.moduleHeight * 0.5)
                        color: Theme.stroke
                    }

                    // segmented: the divider between two segments, gone
                    // beside the lit one
                    Rectangle {
                        visible: winIcon.seg && winIcon.index > 0 && !winIcon.modelData.groupStart
                            && !winIcon.focused && strip.focusIndex !== winIcon.index - 1
                        x: 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: strip.segmentHeight
                        color: Theme.stroke
                    }

                    // the hover fill under this window, for styles with no
                    // hover of their own (and Flat's focused taskbar slot)
                    WindowSlotFill {
                        visible: (winIcon.hovered || winIcon.slotLit) && !winIcon.seg && !winIcon.inset
                            && !winIcon.rings && !winIcon.fade && !winIcon.finder && !winIcon.tint
                            && !(winIcon.liquid && winIcon.focused) && winIcon.mark !== "ground"
                        x: winIcon.fillX
                        anchors.verticalCenter: parent.verticalCenter
                        width: winIcon.fillWidth
                        height: strip.fillHeight
                        radius: Theme.moduleStyle === "grouped" ? Theme.radius : Theme.radiusSmall
                        topLeftRadius: strip.framed || winIcon.seg ? (winIcon.first && strip.leftEnd ? strip.fillRadius : 0) : radius
                        bottomLeftRadius: topLeftRadius
                        topRightRadius: strip.framed || winIcon.seg ? (winIcon.last && strip.rightEnd ? strip.fillRadius : 0) : radius
                        bottomRightRadius: topRightRadius
                        leftCut: winIcon.first && strip.leftEnd ? strip.cut : 0
                        rightCut: winIcon.last && strip.rightEnd ? strip.cut : 0
                        color: Theme.overlay
                        border.width: winIcon.opened && !strip.framed ? Theme.borderWidth : 0
                        border.color: Theme.strokeFocus
                    }

                    // segmented: the slot's ground (accent under the focused
                    // window, hover fill under the rest), inside the track
                    WindowSlotFill {
                        visible: winIcon.seg
                        x: winIcon.fillX
                        anchors.verticalCenter: parent.verticalCenter
                        width: winIcon.fillWidth
                        height: strip.segmentHeight
                        radius: Theme.radiusSmall
                        topLeftRadius: strip.framed || winIcon.seg ? (winIcon.first && strip.leftEnd ? strip.fillRadius : 0) : radius
                        bottomLeftRadius: topLeftRadius
                        topRightRadius: strip.framed || winIcon.seg ? (winIcon.last && strip.rightEnd ? strip.fillRadius : 0) : radius
                        bottomRightRadius: topRightRadius
                        leftCut: winIcon.first && strip.leftEnd ? strip.cut : 0
                        rightCut: winIcon.last && strip.rightEnd ? strip.cut : 0
                        color: winIcon.focused ? Qt.alpha(Theme.accent, 0.3)
                            : winIcon.hovered ? Theme.overlay : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.durFast; easing.type: Theme.ease } }
                    }

                    // inset: the well the focused icon sits in, its inner
                    // stroke echoing the double frame
                    WindowSlotFill {
                        visible: winIcon.inset && winIcon.lit
                        x: strip.framed ? winIcon.fillX : glyphBox.x + (glyphBox.width - width) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: strip.framed ? winIcon.fillWidth : glyphBox.width + 6
                        height: strip.framed ? strip.fillHeight : glyphBox.height + 4
                        radius: Theme.radiusSmall
                        topLeftRadius: strip.framed ? (winIcon.first && strip.leftEnd ? strip.fillRadius : 0) : radius
                        bottomLeftRadius: topLeftRadius
                        topRightRadius: strip.framed ? (winIcon.last && strip.rightEnd ? strip.fillRadius : 0) : radius
                        bottomRightRadius: topRightRadius
                        leftCut: winIcon.first && strip.leftEnd ? strip.cut : 0
                        rightCut: winIcon.last && strip.rightEnd ? strip.cut : 0
                        color: winIcon.focused ? Theme.base : Theme.overlay
                        border.width: winIcon.focused && !strip.framed ? 1 : 0
                        border.color: Theme.stroke

                        Rectangle {
                            visible: winIcon.focused && !strip.framed
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
                    WindowSlotFill {
                        visible: winIcon.mark === "ground"
                        x: strip.framed ? winIcon.fillX : glyphBox.x + (glyphBox.width - width) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: strip.framed ? winIcon.fillWidth : Theme.iconSlotW
                        height: strip.fillHeight
                        radius: Theme.radiusSmall
                        topLeftRadius: strip.framed ? (winIcon.first && strip.leftEnd ? strip.fillRadius : 0) : radius
                        bottomLeftRadius: topLeftRadius
                        topRightRadius: strip.framed ? (winIcon.last && strip.rightEnd ? strip.fillRadius : 0) : radius
                        bottomRightRadius: topRightRadius
                        leftCut: winIcon.first && strip.leftEnd ? strip.cut : 0
                        rightCut: winIcon.last && strip.rightEnd ? strip.cut : 0
                        color: winIcon.focused ? Theme.selectedFill
                            : winIcon.hovered && !winIcon.focused ? Theme.overlay : "transparent"
                        border.width: winIcon.focused && !strip.framed ? Theme.borderWidth : 0
                        border.color: Theme.strokeFocus
                        Behavior on color { ColorAnimation { duration: Theme.durFast; easing.type: Theme.ease } }
                    }

                    // Give transparent app icons a continuous ground inside a frame.
                    WindowSlotFill {
                        visible: winIcon.tint && (strip.framed || winIcon.modelData.source === "")
                        x: tintLayer.x + tintMask.tileX
                        y: tintMask.tileY - tintLayer.grow
                        width: tintMask.tileWidth
                        height: tintMask.tileHeight
                        radius: strip.framed ? strip.fillRadius : Theme.radiusSmall
                        topLeftRadius: strip.framed && !(winIcon.first && strip.leftEnd) ? 0 : radius
                        bottomLeftRadius: topLeftRadius
                        topRightRadius: strip.framed && !(winIcon.last && strip.rightEnd) ? 0 : radius
                        bottomRightRadius: topRightRadius
                        leftCut: winIcon.first && strip.leftEnd ? strip.cut : 0
                        rightCut: winIcon.last && strip.rightEnd ? strip.cut : 0
                        color: winIcon.modelData.source === "" ? (winIcon.focused ? Theme.subtext : winIcon.hovered ? Theme.overlay : Theme.surface)
                            : Theme.surface
                    }

                    // tint: a tile washed in the app's own colours, deeper
                    // for the focused window, with an edge per
                    // extra window (up to two) stacked behind it toward the
                    // screen's edge when there is no enclosing frame
                    Item {
                        id: tintLayer
                        readonly property int grow: 4
                        visible: winIcon.tint
                        x: winIcon.fillX
                        y: -grow
                        width: winIcon.fillWidth
                        height: parent.height + grow * 2
                        Item {
                            id: tintMask
                            readonly property real tileX: strip.framed ? 0 : glyphBox.x + glyphBox.width / 2 - winIcon.boxPx / 2
                            readonly property real tileY: tintLayer.grow + (winIcon.height - tileHeight) / 2
                            readonly property real tileWidth: strip.framed ? winIcon.fillWidth : winIcon.boxPx
                            readonly property real tileHeight: strip.framed ? strip.fillHeight : winIcon.boxPx
                            width: parent.width
                            height: parent.height
                            WindowSlotFill {
                                x: tintMask.tileX
                                y: tintMask.tileY
                                width: tintMask.tileWidth
                                height: tintMask.tileHeight
                                radius: strip.framed ? strip.fillRadius : Theme.radiusSmall
                                topLeftRadius: strip.framed && !(winIcon.first && strip.leftEnd) ? 0 : radius
                                bottomLeftRadius: topLeftRadius
                                topRightRadius: strip.framed && !(winIcon.last && strip.rightEnd) ? 0 : radius
                                bottomRightRadius: topRightRadius
                                leftCut: winIcon.first && strip.leftEnd ? strip.cut : 0
                                rightCut: winIcon.last && strip.rightEnd ? strip.cut : 0
                            }
                        }
                        // Keep cut-corner geometry live while hiding the mask itself.
                        ShaderEffectSource {
                            id: tintMaskTexture
                            anchors.fill: parent
                            sourceItem: winIcon.tint ? tintMask : null
                            hideSource: true
                            visible: false
                            live: true
                        }
                        Item {
                            id: tintRim
                            width: parent.width
                            height: parent.height
                            visible: false
                            layer.enabled: winIcon.tint
                            Repeater {
                                model: winIcon.tint && winIcon.multi && !strip.framed ? Math.min(2, winIcon.winCount - 1) : 0
                                Rectangle {
                                    required property int index
                                    readonly property int step: index + 1
                                    x: glyphBox.x - tintLayer.x + glyphBox.width / 2 - winIcon.boxPx / 2 + step * 3
                                    y: tintLayer.grow + glyphBox.y + glyphBox.height / 2
                                        + (strip.atBottom ? winIcon.boxPx / 2 + step * 2 - 1 : -winIcon.boxPx / 2 - step * 2)
                                    width: winIcon.boxPx - step * 6
                                    height: 1
                                }
                            }
                        }
                        Wash {
                            visible: winIcon.tint && winIcon.modelData.source !== ""
                            width: parent.width
                            height: parent.height
                            mask: tintMaskTexture
                            source: visible ? winIcon.modelData.source : ""
                            iconX: glyphBox.x - tintLayer.x
                            iconY: tintLayer.grow + glyphBox.y
                            iconPx: winIcon.iconPx
                            opacity: winIcon.focused ? 0.8 : winIcon.hovered ? 0.4 : 0.22
                            Behavior on opacity { NumberAnimation { duration: Theme.durFast; easing.type: Theme.ease } }
                        }
                        Wash {
                            visible: winIcon.tint && winIcon.modelData.source !== "" && winIcon.multi && !strip.framed
                            width: parent.width
                            height: parent.height
                            mask: tintRim
                            lift: 0.35
                            source: visible ? winIcon.modelData.source : ""
                            iconX: glyphBox.x - tintLayer.x
                            iconY: tintLayer.grow + glyphBox.y
                            iconPx: winIcon.iconPx
                            opacity: winIcon.focused ? 1 : 0.7
                        }
                    }
                    // rings: a ring round the icon, an arc per window (up to
                    // six), accent on the focused app with its shown window
                    // brightest, grey on hover or for an app with several
                    Canvas {
                        id: ring
                        readonly property int segs: Math.min(6, winIcon.winCount)
                        readonly property color ink: winIcon.focused ? Theme.accent
                            : winIcon.hovered ? Theme.subtext : Theme.muted
                        readonly property color dim: Qt.alpha(Theme.accent, 0.45)
                        visible: winIcon.rings && (winIcon.lit || winIcon.multi)
                        anchors.centerIn: glyphBox
                        width: winIcon.ringPx
                        height: width
                        onSegsChanged: requestPaint()
                        onInkChanged: requestPaint()
                        onVisibleChanged: requestPaint()
                        Connections {
                            target: winIcon
                            function onShownIndexChanged() { ring.requestPaint() }
                        }
                        onPaint: {
                            var c = getContext("2d")
                            c.reset()
                            var w = 2, rad = width / 2 - w / 2
                            var gap = segs > 1 ? Math.PI / 10 : 0
                            var step = 2 * Math.PI / segs
                            // the first arc starts on the screen edge's side
                            var start = strip.atBottom ? Math.PI / 2 : -Math.PI / 2
                            c.lineWidth = w
                            for (var k = 0; k < segs; k++) {
                                c.strokeStyle = winIcon.focused && segs > 1 && k !== Math.min(segs - 1, winIcon.shownIndex)
                                    ? dim : ink
                                c.beginPath()
                                c.arc(width / 2, height / 2, rad, start + k * step + gap / 2, start + (k + 1) * step - gap / 2)
                                c.stroke()
                            }
                        }
                    }

                    // viewfinder: grey corners round a hovered icon (the
                    // focused one's travel with it, below the strip)
                    Corners {
                        visible: winIcon.finder && winIcon.hovered && !winIcon.focused
                        anchors.centerIn: glyphBox
                        width: winIcon.boxPx
                        height: width
                        ink: Theme.subtext
                    }

                    // fade: one or two ghost copies of the icon behind it,
                    // stepping toward the screen's edge, for an app with
                    // several windows
                    Repeater {
                        model: winIcon.fade && winIcon.multi ? Math.min(2, winIcon.winCount - 1) : 0
                        TintedIcon {
                            required property int index
                            readonly property int step: (index + 1) * 2
                            x: glyphBox.x + step
                            y: glyphBox.y + (strip.atBottom ? step : -step)
                            z: -1 - index
                            width: glyphBox.width
                            height: width
                            visible: winIcon.modelData.source !== ""
                            source: winIcon.modelData.source
                            grey: !winIcon.focused
                            opacity: (winIcon.focused ? 0.4 : 0.28) / (index + 1)
                        }
                    }

                    Item {
                        id: glyphBox
                        x: winIcon.padX + Math.round((winIcon.slotW - width) / 2)
                        anchors.verticalCenter: parent.verticalCenter
                        width: winIcon.iconPx
                        height: winIcon.iconPx
                        opacity: winIcon.lift ? (winIcon.lit ? 1 : 0.8)
                            : winIcon.fade ? (winIcon.focused ? 1 : winIcon.hovered ? 0.85 : 0.42)
                            : winIcon.lit || winIcon.rings || winIcon.finder || winIcon.tint || winIcon.liquid ? 1 : 0.55
                        Behavior on opacity { NumberAnimation { duration: Theme.durFast; easing.type: Theme.ease } }
                        Behavior on width {
                            enabled: winIcon.lift
                            NumberAnimation { duration: Theme.durMedium; easing.type: Theme.ease }
                        }
                        Behavior on height {
                            enabled: winIcon.lift
                            NumberAnimation { duration: Theme.durMedium; easing.type: Theme.ease }
                        }

                        TintedIcon {
                            anchors.fill: parent
                            visible: winIcon.modelData.source !== ""
                            source: winIcon.modelData.source
                            grey: winIcon.fade && !winIcon.lit
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

                    // lift: the window count on the icon's corner
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

                    // A pip beside the icon on the screen edge's side (on
                    // Flat's taskbar, on the edge itself); a segment per
                    // window (up to four, popouts shorter, the focused one
                    // in the accent) for an app with several. Inset,
                    // segmented, liquid and the "ground" mark show it only
                    // then, liquid's as round drops.
                    Row {
                        id: pip
                        readonly property var segs: winIcon.modelData.windows.slice(0, 4)
                        readonly property bool split: segs.length > 1
                        visible: winIcon.pipsShown
                        readonly property int gap: winIcon.inset ? 3 : winIcon.liquid ? 2 : 1
                        y: winIcon.slotted && !winIcon.morePips ? (strip.atBottom ? winIcon.height - height : 0)
                            : strip.atBottom ? glyphBox.y + glyphBox.height + gap
                            : glyphBox.y - gap - height
                        anchors.horizontalCenter: glyphBox.horizontalCenter
                        spacing: winIcon.liquid ? 2 : 1
                        Repeater {
                            model: pip.segs
                            Rectangle {
                                required property var modelData
                                required property int index
                                height: winIcon.liquid ? 3 : Theme.indicatorWidth
                                radius: Theme.pill(height)
                                width: winIcon.liquid ? height
                                    : !pip.split ? (winIcon.focused && winIcon.slotted ? winIcon.width
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

                    // viewfinder: a tick per window (up to four) along the
                    // frame's edge side between its corners, the shown one
                    // longer
                    Row {
                        visible: winIcon.finder && winIcon.multi
                        anchors.horizontalCenter: glyphBox.horizontalCenter
                        y: strip.atBottom ? glyphBox.y + glyphBox.height / 2 + winIcon.boxPx / 2 - height
                            : glyphBox.y + glyphBox.height / 2 - winIcon.boxPx / 2
                        spacing: 2
                        Repeater {
                            model: winIcon.finder && winIcon.multi ? Math.min(4, winIcon.winCount) : 0
                            Rectangle {
                                required property int index
                                readonly property bool on: index === Math.min(3, winIcon.shownIndex)
                                width: winIcon.focused && on ? 4 : 2
                                height: 2
                                color: winIcon.focused ? (on ? Theme.accent : Qt.alpha(Theme.accent, 0.45))
                                    : winIcon.hovered ? Theme.subtext : Theme.muted
                            }
                        }
                    }

                    // glide: the groove's notch per window by the icon,
                    // which the slider lights for the window shown
                    Row {
                        visible: winIcon.notched
                        x: glyphBox.x
                        y: strip.markY
                        spacing: 1
                        Repeater {
                            model: winIcon.notched ? winIcon.notchSegs : 0
                            Rectangle {
                                width: winIcon.notchW
                                height: strip.markH
                                radius: Theme.pill(height)
                                color: winIcon.focused || winIcon.hovered ? Theme.subtext : Theme.muted
                            }
                        }
                    }

                    MouseArea {
                        id: winMouse
                        x: winIcon.fillX
                        width: winIcon.fillWidth
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

        // glide: the groove along every icon, and the slider that
        // travels in it to the focused one
        Rectangle {
            visible: strip.style === "glide"
            z: -1
            x: stripRow.x + Theme.spaceS / 2
            y: strip.markY
            width: stripRow.width - Theme.spaceS
            height: strip.markH
            radius: Theme.pill(height)
            color: Theme.overlay
        }
        Rectangle {
            id: slider
            readonly property Item target: strip.style === "glide" ? strip.focusItem : null
            visible: target !== null
            x: target ? stripRow.x + target.x + target.padX
                + (target.notched ? Math.min(3, target.shownIndex) * (target.notchW + 1) : 0) : 0
            y: strip.markY
            width: target ? (target.notched ? target.notchW : target.iconPx) : 0
            z: 2
            height: strip.markH
            radius: Theme.pill(height)
            color: Theme.accent
            Behavior on x {
                enabled: slider.visible
                NumberAnimation { duration: Theme.durSlow; easing.type: Theme.ease }
            }
        }

        // viewfinder: the focused icon's corners, sweeping to the next
        // focused one
        Corners {
            id: finder
            readonly property Item target: strip.style === "viewfinder" ? strip.focusItem : null
            visible: target !== null
            width: target ? target.boxPx : 0
            height: width
            x: target ? stripRow.x + target.x + target.padX + target.slotW / 2 - width / 2 : 0
            anchors.verticalCenter: parent.verticalCenter
            z: 1
            ink: Theme.accent
            Behavior on x {
                enabled: finder.visible
                NumberAnimation { duration: Theme.durSlow; easing.type: Theme.ease }
            }
        }
    }
}
