// Singularity - Quickshell
// ~/.config/quickshell/bar/BarModules.qml
//
// The bar's 19 modules (and the widgetItems registry shell.qml's Bar
// Widgets reordering keys off of), split out of shell.qml so the bar's
// layout plumbing isn't buried under every module's own logic.
//
// Non-visual on purpose: shell.qml's PanelWindow reparents every module
// here into its left/centre/right slot the moment this component
// finishes constructing (see its Component.onCompleted), so where these
// are declared doesn't matter -- only that they exist and keep the ids
// widgetItems below points at.

import Quickshell
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Shapes
import "../services"

Item {
    id: barModules

    required property var bar
    required property var screenScope
    // for specialShown, which follows Hyprland's events once for all bars
    required property var shellRoot
    // the tray icon's right-click opens this flyout, which lives outside
    // the bar entirely (it's a sibling flyout in the screen's Scope). It's
    // the flyout's LazyFlyout loader: ensure() builds it if needed.
    required property var trayMenu
    // same, for the open-windows strip's right-click menu
    required property var windowMenu

    readonly property var widgetItems: ({
        controlcentre: ccBtn, workspaces: wsFrame,
        windows: windowIcons, clock: clock, bluetooth: btBtn,
        network: netBtn, volume: volBtn, brightness: brightBtn,
        battery: battBtn, tray: trayFrame, media: mediaBtn,
        visualizer: vizFrame, weather: weatherBtn,
        notifications: notifBtn, privacy: privacyBtn,
        failed: failedBtn, updates: updatesBtn, claude: claudeBtn,
        desktop: desktopBtn })

    // Control centre. Sits left of the workspaces, where a
    // distro/menu button conventionally lives.
    BarModule {
        id: ccBtn
        icon: Theme.controlGlyph
        // one size whichever glyph is chosen, a little over the other modules'
        iconSize: Math.min(Theme.moduleHeight - 4, Theme.iconSize + 4)
        fixedWidth: Theme.moduleWidth
        active: screenScope.openFlyout === "controlcentre"
        onActivated: screenScope.toggleFlyout("controlcentre", ccBtn)
    }

    // One frame around the whole set, with the current
    // workspace shown as a widened pill rather than a number.
    // Three states read by size and weight alone: current is a
    // long bright bar, occupied a short one, empty a dim stub --
    // the same language as the gauges on the right, where how
    // much space a thing takes up is the information.
    ModuleFrame {
        id: wsFrame
        visible: Settings.widgetVisible("workspaces")
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceS
        // each mark already sits in a slot 2px wider on either side
        padH: Theme.modulePadH - 2

        Repeater {
            model: Settings.workspaceCount

            Item {
                required property int index
                readonly property int wsId: index + 1
                readonly property bool current: Hyprland.focusedWorkspace
                    ? Hyprland.focusedWorkspace.id === wsId
                    : false
                readonly property bool occupied: barModules.bar.workspaceHasWindows(wsId)

                anchors.verticalCenter: parent.verticalCenter
                // a little wider than the mark so an empty
                // workspace is still a comfortable click target
                readonly property bool textual: Theme.workspaceStyle === "numbers" || Theme.workspaceStyle === "roman"
                    || Theme.workspaceStyle === "names"
                // the apps style: an app open there, or null when it's empty
                readonly property var app: Theme.workspaceStyle === "apps" ? barModules.bar.workspaceApp(wsId) : null
                readonly property bool appMark: Theme.workspaceStyle === "apps" && app !== null
                implicitWidth: (appMark ? appBox.width : textual ? num.width : pip.width) + 4
                implicitHeight: Theme.moduleHeight - 8

                // pills, dots, lines and blocks: the same three states,
                // drawn as a pill that stretches, a dot or a short rule
                // that lights, or a square that fills
                Rectangle {
                    id: pip
                    readonly property bool blocks: Theme.workspaceStyle === "blocks"
                    readonly property bool lines: Theme.workspaceStyle === "lines"
                    visible: !parent.textual && !parent.appMark
                    anchors.centerIn: parent
                    height: blocks ? 10 : lines ? 3 : 7
                    width: blocks ? 10 : lines ? 14 : Theme.workspaceStyle === "dots" || Theme.workspaceStyle === "apps" ? 7
                        : parent.current ? 22 : (parent.occupied ? 11 : 7)
                    // fully rounded: half the height makes a pill
                    // at any width, and a circle at the stub size
                    radius: blocks ? Math.min(2, Theme.radiusSmall) : height / 2
                    color: parent.current ? Theme.accent
                        : blocks ? (parent.occupied ? Theme.subtext : "transparent")
                        : (parent.occupied ? Theme.subtext : Theme.muted)
                    border.width: blocks && !parent.current && !parent.occupied ? Theme.borderWidth : 0
                    border.color: Theme.muted

                    Behavior on width {
                        NumberAnimation { duration: Theme.dur(130); easing.type: Theme.ease }
                    }
                    Behavior on color { ColorAnimation { duration: Theme.dur(130) } }
                }

                Text {
                    id: num
                    visible: parent.textual
                    anchors.centerIn: parent
                    // a touch wider than a digit, so the row doesn't
                    // shift as the current one turns bold
                    width: Math.max(implicitWidth, Theme.barFs(12))
                    horizontalAlignment: Text.AlignHCenter
                    text: Theme.workspaceStyle === "roman"
                        ? ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"][parent.wsId - 1] || parent.wsId
                        : Theme.workspaceStyle === "names" ? Theme.workspaceNames[parent.wsId - 1] || parent.wsId
                        : parent.wsId
                    color: parent.current ? Theme.accent
                        : parent.occupied ? Theme.text : Theme.muted
                    font.family: Theme.fontText
                    font.pixelSize: Theme.barLabelSize
                    font.weight: parent.current ? Theme.weightStrong : Theme.weightBody
                }

                // the apps style: the app's icon, an accent rule under the
                // current workspace's
                Item {
                    id: appBox
                    visible: parent.appMark
                    anchors.centerIn: parent
                    width: Theme.barFs(15)
                    height: Theme.barFs(15)
                    opacity: parent.current ? 1 : 0.6

                    TintedIcon {
                        anchors.fill: parent
                        visible: !!parent.parent.app && parent.parent.app.source !== ""
                        source: parent.parent.app ? parent.parent.app.source : ""
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !!parent.parent.app && parent.parent.app.source === ""
                        text: parent.parent.app ? parent.parent.app.glyph : ""
                        color: Theme.text
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.barFs(14)
                    }
                    Rectangle {
                        visible: appBox.parent.current
                        anchors.top: parent.bottom
                        anchors.topMargin: 1
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        height: Theme.indicatorWidth
                        radius: height / 2
                        color: Theme.accent
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("hl.dsp.focus({workspace=" + parent.wsId + "})")
                }
            }
        }

        // The scratchpad (SUPER+grave), only while something is in it: lit
        // when it's shown on this monitor, with a count past one window
        Item {
            id: scratchMark
            readonly property var ws: Hyprland.workspaces.values.find(w => w.name === "special:scratchpad") || null
            readonly property int count: ws
                ? ws.toplevels.values.filter(t => !barModules.bar.isShellWindow(t)).length : 0
            readonly property var monitor: Hyprland.monitorFor(barModules.screenScope.modelData)
            // the monitor's own report until the first activespecial event
            readonly property bool shown: {
                const name = monitor ? monitor.name : ""
                if (name in barModules.shellRoot.specialShown)
                    return barModules.shellRoot.specialShown[name] === "special:scratchpad"
                const sp = monitor && monitor.lastIpcObject && monitor.lastIpcObject.specialWorkspace
                return !!sp && sp.name === "special:scratchpad"
            }

            visible: count > 0
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: scratchRow.implicitWidth + 4
            implicitHeight: Theme.moduleHeight - 8

            Row {
                id: scratchRow
                anchors.centerIn: parent
                spacing: Theme.spaceXs

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰆍"
                    color: scratchMark.shown ? Theme.accent
                        : scratchMouse.containsMouse ? Theme.text : Theme.subtext
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.barFs(15)
                    Behavior on color { ColorAnimation { duration: Theme.dur(130) } }
                }

                Text {
                    visible: scratchMark.count > 1
                    anchors.verticalCenter: parent.verticalCenter
                    text: scratchMark.count
                    color: scratchMark.shown ? Theme.accent : Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.barFs(11)
                }
            }

            MouseArea {
                id: scratchMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("hl.dsp.workspace.toggle_special('scratchpad')")
            }
        }

        // the overview of every window on every workspace, as the
        // chip's last mark after a divider: the selector and the
        // pips it expands on read as one control
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.borderWidth
            height: Theme.moduleHeight - 12
            color: Theme.stroke
        }

        Item {
            id: wsOverviewBtn
            readonly property bool open: screenScope.openFlyout === "workspaces"
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: overviewGlyph.implicitWidth + 4
            implicitHeight: Theme.moduleHeight - 8

            Text {
                id: overviewGlyph
                anchors.centerIn: parent
                text: "󰕰"
                color: wsOverviewBtn.open ? Theme.accent
                    : overviewMouse.containsMouse ? Theme.text : Theme.subtext
                font.family: Theme.fontIcon
                font.pixelSize: Theme.barFs(15)
                Behavior on color { ColorAnimation { duration: Theme.dur(130) } }
            }

            MouseArea {
                id: overviewMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: screenScope.toggleFlyout("workspaces", wsOverviewBtn)
            }
        }
    }

    // The open windows, trailing the workspaces: the focused workspace's,
    // or every workspace's (Theme.windowScope), in one frame -- they're a
    // single group, and a chip each would read as six separate modules.
    // Theme.windowStyle draws each one:
    //   icons      the icon over a pip in the workspace indicator's
    //              language: a long accent pill under the focused window,
    //              muted stubs under the rest, whose icons dim to match
    //   titled     the same, with the focused window's title beside its icon
    //   glide      the icons over one faint rail, with a single accent
    //              slider that travels to the focused window
    //   lift       no marks: the focused icon large and in colour, the
    //              rest small and grey
    //   inset      the focused icon in a recessed, double-stroked well
    //   segmented  segments of one control with hairlines between, the
    //              focused one on a soft accent ground
    //   spotlight  the focused window opens into a capsule with its title,
    //              the rest shrink to small icons
    //   tabs       icon and title for every window, the focused one's tab lit
    //   index      no icons: a number and the app's name for each, the
    //              focused one on an accent ground
    //   dots       a dot per window, the focused one a short accent pill
    ModuleFrame {
        id: windowIcons
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        // an empty chip on a bare workspace would be a floating
        // rectangle with nothing in it
        visible: iconRepeater.count > 0 && Settings.widgetVisible("windows")
        active: screenScope.openFlyout === "windowmenu"
        hoverWhole: false
        // the plain icon styles pad each icon by a hair, which would
        // otherwise stack on the chip's own padding
        padH: Theme.modulePadH - (["icons", "titled", "glide", "lift"].indexOf(Theme.windowStyle) >= 0
            ? Theme.spaceS / 2 : 0)

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
                    if (m[i].address === a.address) return i
                return -1
            }
            // the top of the marks under the icons: a pixel below an icon
            // that's lifted a pixel to clear them
            readonly property int markY: Math.round((Theme.moduleHeight + Theme.barFs(16)) / 2)

            Row {
                id: stripRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: strip.style === "tabs" || strip.style === "dots" || strip.style === "spotlight"
                        || strip.style === "index" ? Theme.spaceXs
                    : strip.style === "segmented" || strip.style === "inset"
                        || strip.style === "lift" ? 0 : Theme.spaceS

                Repeater {
                    id: iconRepeater
                    model: barModules.bar.focusedWorkspaceIcons()

                    Item {
                        id: winIcon
                        required property var modelData
                        required property int index
                        readonly property bool focused: strip.focusIndex === index
                        readonly property bool hovered: winMouse.containsMouse
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
                        readonly property bool underMark: mark === "pill"
                        readonly property string title: modelData.toplevel ? modelData.toplevel.title || "" : ""
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
                        readonly property int titleGap: spot ? Theme.spaceS : Theme.spaceXs
                        // spotlight's capsule is fully rounded, so its icon
                        // sits further in to clear the curve
                        readonly property int padX: spot ? Theme.spaceS + 2
                            : tabs || seg || indexed || inset ? Theme.spaceS
                            : dots ? 1 : Theme.spaceS / 2
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
                            NumberAnimation { duration: Theme.dur(130); easing.type: Theme.ease }
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

                        // the hover fill under just this window, for the
                        // styles without a ground of their own, sized as a
                        // whole module's hover is
                        Rectangle {
                            readonly property bool grouped: Theme.moduleStyle === "grouped"
                            visible: winIcon.hovered && !winIcon.tabs && !winIcon.seg && !winIcon.spot
                                && !winIcon.indexed && !winIcon.inset
                                && winIcon.mark !== "ground" && winIcon.mark !== "box"
                            x: winIcon.lead
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - winIcon.lead
                            height: grouped ? Theme.groupHeight - Theme.channelWidth * 2 : Theme.moduleHeight - 6
                            radius: grouped ? Theme.radius : Theme.radiusSmall
                            color: Theme.overlay
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
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }

                            Rectangle {
                                visible: winIcon.focused
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width - Theme.spaceS * 2
                                height: Theme.indicatorWidth
                                radius: height / 2
                                color: Theme.accent
                            }
                        }

                        // segmented, spotlight and index: the whole slot's
                        // ground, a soft accent (solid for index) under the
                        // focused window and a hover fill under the rest
                        Rectangle {
                            visible: winIcon.seg || winIcon.spot || winIcon.indexed
                            x: winIcon.lead
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - winIcon.lead
                            height: winIcon.indexed ? Theme.moduleHeight - 8 : Theme.moduleHeight - 6
                            radius: winIcon.spot ? height / 2 : Theme.radiusSmall
                            color: winIcon.focused
                                ? (winIcon.indexed ? (Theme.hasAccent ? Theme.accent : Theme.selectedFill)
                                    : Qt.alpha(Theme.accent, 0.22))
                                : winIcon.hovered ? Theme.overlay : "transparent"
                            border.width: winIcon.focused && !winIcon.indexed ? Theme.borderWidth : 0
                            border.color: winIcon.spot ? Theme.accent : Qt.alpha(Theme.accent, 0.6)
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
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

                        // "ground" and "box": a square behind or around the icon,
                        // lit for the focused window, a hover fill for the rest
                        Rectangle {
                            visible: winIcon.mark === "ground" || winIcon.mark === "box"
                            anchors.centerIn: glyphBox
                            width: glyphBox.width + Theme.spaceS
                            height: glyphBox.height + Theme.spaceS
                            radius: Theme.radiusSmall
                            color: winIcon.mark === "ground" && winIcon.focused ? Theme.selectedFill
                                : winIcon.hovered && !winIcon.focused ? Theme.overlay : "transparent"
                            border.width: winIcon.focused ? Theme.borderWidth : 0
                            border.color: winIcon.mark === "box" ? Theme.accent : Theme.strokeFocus
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        }

                        // "above": a rule along the chip's top edge, just inside
                        // the double frame's inner stroke
                        Rectangle {
                            visible: winIcon.mark === "above"
                            anchors.horizontalCenter: glyphBox.horizontalCenter
                            y: 4
                            width: glyphBox.width + Theme.spaceXs
                            height: Theme.indicatorWidth
                            radius: height / 2
                            color: Theme.accent
                            opacity: winIcon.focused ? 1 : winIcon.hovered ? 0.4 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                        }

                        Item {
                            id: glyphBox
                            visible: !winIcon.dots && !winIcon.indexed
                            x: winIcon.lead + winIcon.padX + Math.round((winIcon.slotW - width) / 2)
                            anchors.verticalCenter: parent.verticalCenter
                            // lifted a single pixel: just enough to clear the
                            // pip, so the icon still sits level with the
                            // chips around it
                            anchors.verticalCenterOffset: winIcon.underMark || winIcon.glide ? -1 : 0
                            width: winIcon.iconPx
                            height: winIcon.iconPx
                            opacity: winIcon.lift ? (winIcon.focused ? 1 : winIcon.hovered ? 0.9 : 0.5)
                                : winIcon.lit ? 1 : 0.55
                            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                            Behavior on width {
                                enabled: winIcon.spot || winIcon.lift
                                NumberAnimation { duration: Theme.dur(160); easing.type: Theme.ease }
                            }
                            Behavior on height {
                                enabled: winIcon.spot || winIcon.lift
                                NumberAnimation { duration: Theme.dur(160); easing.type: Theme.ease }
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
                                NumberAnimation { duration: Theme.dur(180); easing.type: Theme.ease }
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

                        // tucked a pixel under the icon rather than pinned to
                        // the chip's edge, so it needn't push the icon up
                        Rectangle {
                            id: pip
                            visible: winIcon.underMark
                            anchors.top: glyphBox.bottom
                            anchors.topMargin: 1
                            anchors.horizontalCenter: glyphBox.horizontalCenter
                            height: Theme.indicatorWidth
                            radius: height / 2
                            width: winIcon.focused ? glyphBox.width - 2 : Theme.barFs(6)
                            color: winIcon.focused ? Theme.accent
                                : winIcon.hovered ? Theme.subtext : Theme.muted
                            Behavior on width {
                                NumberAnimation { duration: Theme.dur(130); easing.type: Theme.ease }
                            }
                            Behavior on color { ColorAnimation { duration: Theme.dur(130) } }
                        }

                        // the dots style's whole mark
                        Rectangle {
                            id: dot
                            visible: winIcon.dots
                            x: winIcon.lead + winIcon.padX
                            anchors.verticalCenter: parent.verticalCenter
                            height: Theme.barFs(6)
                            width: winIcon.focused ? Theme.barFs(14) : height
                            radius: height / 2
                            color: winIcon.focused ? Theme.accent
                                : winIcon.hovered ? Theme.subtext : Theme.muted
                            Behavior on width {
                                NumberAnimation { duration: Theme.dur(130); easing.type: Theme.ease }
                            }
                            Behavior on color { ColorAnimation { duration: Theme.dur(130) } }
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
                                var addr = "address:0x" + winIcon.modelData.address
                                if (mouse.button === Qt.RightButton) {
                                    var menu = barModules.windowMenu.ensure()
                                    // a different window's icon while the menu is
                                    // open retargets it rather than closing it
                                    if (screenScope.openFlyout === "windowmenu"
                                            && menu.address !== winIcon.modelData.address) {
                                        menu.address = winIcon.modelData.address
                                        menu.movePage = false
                                        screenScope.flyoutAnchorX = winIcon.mapToItem(null, winIcon.width / 2, 0).x
                                        screenScope.flyoutAnchorW = winIcon.width
                                        return
                                    }
                                    menu.address = winIcon.modelData.address
                                    menu.movePage = false
                                    screenScope.toggleFlyout("windowmenu", winIcon)
                                } else if (mouse.button === Qt.MiddleButton) {
                                    Hyprland.dispatch("hl.dsp.window.close({window=\"" + addr + "\"})")
                                } else {
                                    // focus and bring to top -- so floating windows stay
                                    // accessible even when behind a monocle-maximized window
                                    Hyprland.dispatch("hl.dsp.focus({window=\"" + addr + "\"})")
                                    Hyprland.dispatch("hl.dsp.window.bring_to_top({window=\"" + addr + "\"})")
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
                x: target ? stripRow.x + target.x + target.lead + target.padX : 0
                y: strip.markY - Math.floor((Theme.indicatorWidth - 1) / 2)
                width: target ? target.iconPx : 0
                height: Theme.indicatorWidth
                radius: height / 2
                color: Theme.accent
                Behavior on x {
                    enabled: slider.visible
                    NumberAnimation { duration: Theme.dur(220); easing.type: Theme.ease }
                }
            }
        }
    }

    // Time and date in one chip, which briefly shows volume, brightness and
    // layout changes instead (see ClockIsland.qml).
    ClockIsland {
        id: clock
        visible: Settings.widgetVisible("clock")
        screenScope: barModules.screenScope
    }

    BarModule {
        id: btBtn
        visible: Settings.widgetVisible("bluetooth")
        readonly property var adapter: Bluetooth.defaultAdapter
        icon: barModules.bar.btAdapterOn(adapter) ? "󰂯" : "󰂲"
        active: screenScope.openFlyout === "bluetooth"
        dimmed: !barModules.bar.btAdapterOn(adapter)
        onActivated: screenScope.toggleFlyout("bluetooth", btBtn)
    }

    BarModule {
        id: netBtn
        visible: Settings.widgetVisible("network")
        // the filled strength glyph, not the outlined md-wifi
        // arcs: its neighbours (volume, battery, power) are all
        // solid, and the thin one read as a different weight
        icon: Network.ssid !== "" ? "󰤨" : "󰤮"
        active: screenScope.openFlyout === "network"
        dimmed: Network.ssid === ""
        onActivated: {
            // the networks iwd already knows of; a fresh scan
            // only from the flyout's Rescan row
            Network.refreshList()
            screenScope.toggleFlyout("network", netBtn)
        }
    }

    BarModule {
        id: volBtn
        visible: Settings.widgetVisible("volume")
        fixedWidth: Theme.moduleWidth
        // the bar carries the level now, so the icon only has
        // to say muted or not -- and those two glyphs are the
        // same width, so the chip no longer resizes as you scroll
        icon: Audio.muted ? "󰖁" : "󰕾"
        fillValue: Audio.muted ? 0 : Audio.percent / 100
        active: screenScope.openFlyout === "volume"
        acceptWheel: true
        onActivated: screenScope.toggleFlyout("volume", volBtn)
        onMiddleClicked: Audio.toggleMute()
        onWheeled: d => Audio.setVolume(Audio.percent + d * 5)
    }

    BarModule {
        id: brightBtn
        visible: Brightness.available && Settings.widgetVisible("brightness")
        fixedWidth: Theme.moduleWidth
        icon: "󰃠"
        fillValue: Brightness.level / 100
        active: screenScope.openFlyout === "brightness"
        acceptWheel: true
        onActivated: screenScope.toggleFlyout("brightness", brightBtn)
        onWheeled: d => Brightness.set(Brightness.level + d * 5)
    }

    BarModule {
        id: battBtn
        fixedWidth: Theme.moduleWidth
        visible: Battery.present && Settings.widgetVisible("battery")
        // charging is all the glyph still needs to say; the
        // level is the bar's job
        icon: UPower.onBattery ? "󰁹" : "󰂄"
        fillValue: Battery.percent / 100
        // Charging wins over the low warning on purpose: at 8%
        // and plugged in, the useful fact is that it's recovering.
        fillColor: {
            if (!UPower.onBattery) return Theme.good
            if (Battery.percent <= 20) return Theme.alert
            return Theme.gaugeFill
        }
        active: screenScope.openFlyout === "battery"
        onActivated: {
            PpdProfile.refresh()
            screenScope.toggleFlyout("battery", battBtn)
        }
    }

    // ---- contextual modules ---------------------------------
    // Everything below except weather and the tray appears only
    // while it has something to say: media while a player is
    // open, the visualizer while sound is playing, and the
    // alert-style ones (privacy, failed units, updates, unread
    // notifications) only when there's something to act on.
    // Bar Widgets can still turn any of them off entirely.

    // system tray: one frame around every app's icon, like the
    // open-windows strip. Left raises the app's window (or activates
    // the app if it has none open), right opens the app's menu in a
    // flyout, middle is the app's secondary action.
    //
    // With the tray drawer on, only the pinned icons show until the chevron
    // opens the drawer.
    ModuleFrame {
        id: trayFrame
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceM
        visible: trayRepeater.count > 0 && Settings.widgetVisible("tray")
        active: screenScope.openFlyout === "traymenu"

        property bool drawerOpen: false

        Repeater {
            id: trayRepeater
            model: SystemTray.items.values

            TintedIcon {
                id: trayIcon
                required property var modelData
                visible: !Settings.trayDrawer || trayFrame.drawerOpen
                    || Settings.trayPinned.indexOf(modelData.id) !== -1
                anchors.verticalCenter: parent.verticalCenter
                source: modelData.icon
                implicitSize: Theme.barFs(16)

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        var item = trayIcon.modelData
                        if (mouse.button === Qt.MiddleButton) {
                            item.secondaryActivate()
                        } else if (mouse.button === Qt.RightButton || item.onlyMenu) {
                            if (!item.hasMenu) return
                            var menu = barModules.trayMenu.ensure()
                            menu.item = item
                            menu.stack = []
                            screenScope.toggleFlyout("traymenu", trayIcon)
                        } else {
                            // raise the app's own window when it has one
                            // open (on any workspace); only fall back to the
                            // app's activate() -- usually "show/hide main
                            // window" -- when there's nothing to raise
                            var win = barModules.bar.trayItemWindow(item)
                            if (win) {
                                var addr = "address:0x" + win.address
                                Hyprland.dispatch("hl.dsp.focus({window=\"" + addr + "\"})")
                                Hyprland.dispatch("hl.dsp.window.bring_to_top({window=\"" + addr + "\"})")
                            } else {
                                item.activate()
                            }
                        }
                    }
                }
            }
        }

        // the drawer's handle
        Text {
            visible: Settings.trayDrawer
            anchors.verticalCenter: parent.verticalCenter
            text: trayFrame.drawerOpen ? "󰅂" : "󰅁"
            color: drawerMouse.containsMouse ? Theme.textStrong : Theme.subtext
            font.family: Theme.fontIcon
            font.pixelSize: Theme.barFs(14)

            MouseArea {
                id: drawerMouse
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: trayFrame.drawerOpen = !trayFrame.drawerOpen
            }
        }
    }

    BarModule {
        id: mediaBtn
        readonly property var player: Media.player
        visible: player !== null && Settings.widgetVisible("media")
        icon: player && player.isPlaying ? "󰏤" : "󰐊"
        label: !player ? ""
            : (player.trackArtist ? player.trackArtist + " – " : "") + (player.trackTitle || player.identity)
        labelMaxWidth: Theme.fit(220)
        active: screenScope.openFlyout === "media"
        onActivated: screenScope.toggleFlyout("media", mediaBtn)
        onMiddleClicked: if (player && player.canTogglePlaying) player.togglePlaying()
    }

    // audio spectrum, in the meter colour, drawn as Theme.vizStyle: thin
    // pills growing from the middle (the workspace indicator's shape
    // language), bars rising from the bottom, stacked dots, or one line
    ModuleFrame {
        id: vizFrame
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceXs
        visible: Visualizer.playing && Settings.widgetVisible("visualizer")

        readonly property string style: Theme.vizStyle
        readonly property int bandW: Theme.barFs(3)
        readonly property int bandH: Theme.moduleHeight - 10

        Repeater {
            model: vizFrame.style === "line" ? 0 : Visualizer.barCount

            Item {
                id: band
                required property int index
                readonly property real v: Math.max(0, Math.min(1, (Visualizer.bars[index] || 0) / 100))
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: vizFrame.bandW
                implicitHeight: vizFrame.bandH

                Rectangle {
                    visible: vizFrame.style !== "dots"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: vizFrame.style === "mirror" ? parent.verticalCenter : undefined
                    anchors.bottom: vizFrame.style === "rise" ? parent.bottom : undefined
                    width: vizFrame.bandW
                    radius: vizFrame.style === "rise" ? Math.min(1, Theme.radiusSmall) : vizFrame.bandW / 2
                    height: Math.max(3, parent.height * band.v)
                    color: Theme.meterFill
                    Behavior on height { NumberAnimation { duration: Theme.dur(60) } }
                }

                // four dots from the bottom, lit up to the band's level
                Column {
                    visible: vizFrame.style === "dots"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.max(1, (vizFrame.bandH - vizFrame.bandW * 4) / 3)
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            width: vizFrame.bandW
                            height: vizFrame.bandW
                            radius: width / 2
                            color: Theme.meterFill
                            // index 0 is the top dot; the bottom one is always lit
                            opacity: band.v * 4 >= 3 - index || index === 3 ? 1 : 0.18
                            Behavior on opacity { NumberAnimation { duration: Theme.dur(60) } }
                        }
                    }
                }
            }
        }

        // the line style: one stroke through every band's level
        Shape {
            visible: vizFrame.style === "line"
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: Visualizer.barCount * (vizFrame.bandW + vizFrame.spacing) - vizFrame.spacing
            implicitHeight: vizFrame.bandH
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Theme.meterFill
                strokeWidth: Math.max(1.5, Theme.borderWidth * 1.5)
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathPolyline {
                    path: {
                        var pts = [], n = Visualizer.barCount
                        var w = vizFrame.style === "line" ? n * (vizFrame.bandW + vizFrame.spacing) - vizFrame.spacing : 0
                        var h = vizFrame.bandH
                        for (var i = 0; i < n; i++) {
                            var v = Math.max(0, Math.min(1, (Visualizer.bars[i] || 0) / 100))
                            pts.push(Qt.point(n > 1 ? i * w / (n - 1) : 0, h - 1 - v * (h - 2)))
                        }
                        return pts
                    }
                }
            }
        }
    }

    BarModule {
        id: weatherBtn
        visible: Weather.ready && Settings.widgetVisible("weather")
        icon: Weather.iconFor(Weather.code, Weather.isNight)
        label: Weather.temp(Weather.tempF, Weather.tempC)
        active: screenScope.openFlyout === "weather"
        onActivated: screenScope.toggleFlyout("weather", weatherBtn)
    }

    BarModule {
        id: notifBtn
        // always shown, so the history is one click away; the badge is
        // only what's arrived since it was last opened
        visible: Settings.widgetVisible("notifications")
        icon: Notifications.dnd ? "󰂛" : "󰂚"
        badge: Notifications.unread
        dimmed: Notifications.dnd || Notifications.unread === 0
        active: screenScope.openFlyout === "notifications"
        // left: the history; right: Do Not Disturb
        onActivated: screenScope.toggleFlyout("notifications", notifBtn)
        onRightClicked: Notifications.toggleDnd()
    }

    BarModule {
        id: privacyBtn
        visible: Privacy.active && Settings.widgetVisible("privacy")
        // one glyph per kind of capture in progress
        icon: [Privacy.mic ? "󰍬" : "", Privacy.camera ? "󰄀" : "", Privacy.screen ? "󰍹" : ""]
            .filter(g => g !== "").join(" ")
        // the palette's alert hue, on purpose: this is the one
        // module that exists to be noticed
        iconColor: Theme.alert
        active: screenScope.openFlyout === "privacy"
        onActivated: screenScope.toggleFlyout("privacy", privacyBtn)
    }

    BarModule {
        id: failedBtn
        visible: FailedUnits.count > 0 && Settings.widgetVisible("failed")
        icon: "󰀦"
        iconColor: Theme.alert
        label: String(FailedUnits.count)
        active: screenScope.openFlyout === "failed"
        onActivated: {
            FailedUnits.refresh()
            screenScope.toggleFlyout("failed", failedBtn)
        }
    }

    BarModule {
        id: updatesBtn
        visible: Updates.count > 0 && Settings.widgetVisible("updates")
        icon: "󰚰"
        label: String(Updates.count)
        active: screenScope.openFlyout === "updates"
        onActivated: screenScope.toggleFlyout("updates", updatesBtn)
    }

    // Claude, editing the desktop itself (services/ClaudeShell.qml). The
    // label says it's working, then how many files are waiting for review;
    // the icon takes the accent while there's a reply or a diff not yet seen.
    BarModule {
        id: claudeBtn
        visible: ClaudeShell.available && Settings.widgetVisible("claude")
        icon: "󰚩"
        label: ClaudeShell.running ? spinner.frames[spinner.frame]
            : ClaudeShell.hasChanges ? String(ClaudeShell.files.length) : ""
        iconColor: ClaudeShell.unseen || ClaudeShell.hasChanges ? Theme.accent : "transparent"
        active: screenScope.openFlyout === "claude"
        onActivated: screenScope.toggleFlyout("claude", claudeBtn)

        Timer {
            id: spinner
            readonly property var frames: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
            property int frame: 0
            interval: 90
            repeat: true
            running: ClaudeShell.running && claudeBtn.visible
            onTriggered: frame = (frame + 1) % frames.length
        }
    }

    // Show desktop, as on Windows: a slim button at the end of its group,
    // set off by a hairline, whose rounded end is the group's own corner.
    // Without groups it's a slim chip of the style's own, with a short bar
    // in it. A click hides every window on the workspace
    // (singularityShowDesktop() in windows.lua, also SUPER+D); it lights
    // with the accent while they're hidden, and a second click brings them
    // back.
    Item {
        id: desktopBtn
        visible: Settings.widgetVisible("desktop")
        readonly property bool grouped: Theme.moduleGrouped
        // a window on the focused workspace that it hid is still hidden
        readonly property bool shown: {
            var ws = Hyprland.focusedWorkspace
            if (!ws) return false
            return ws.toplevels.values.some(t => {
                var tags = t.lastIpcObject ? t.lastIpcObject.tags || [] : []
                return tags.indexOf("showdesktop") !== -1
            })
        }

        signal activated()
        onActivated: Quickshell.execDetached(["hyprctl", "eval", "singularityShowDesktop()"])

        property bool slideX: false
        Behavior on x {
            enabled: desktopBtn.slideX
            NumberAnimation { duration: Theme.dur(160); easing.type: Theme.ease }
        }

        implicitWidth: grouped ? Theme.sp(8) : chip.implicitWidth
        implicitHeight: Theme.barHeight

        ModuleFrame {
            id: chip
            visible: !desktopBtn.grouped
            anchors.centerIn: parent
            padH: Theme.modulePadH / 2

            Rectangle {
                width: Theme.sp(3)
                height: Theme.iconSize - 2
                radius: width / 2
                color: desktopBtn.shown ? Theme.accent
                    : desktopMouse.containsMouse ? Theme.text : Theme.muted
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
            }
        }

        Rectangle {
            id: cap
            visible: desktopBtn.grouped
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: desktopBtn.grouped ? Theme.groupHeight - Theme.channelWidth * 2 : Theme.moduleHeight
            topRightRadius: desktopBtn.grouped ? Theme.radius : Theme.radiusSmall
            bottomRightRadius: topRightRadius
            color: desktopBtn.shown ? Theme.accent
                : desktopMouse.containsMouse ? Theme.overlay : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.durFast } }

            Rectangle {
                width: Theme.borderWidth
                height: parent.height
                color: desktopBtn.shown ? Theme.accent : Theme.stroke
            }
        }

        MouseArea {
            id: desktopMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: desktopBtn.activated()
        }
    }
}
