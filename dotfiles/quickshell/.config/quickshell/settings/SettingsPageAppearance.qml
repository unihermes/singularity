// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageAppearance.qml
//
// Appearance, in tabs, from the broadest choice to the finest:
//   Look       every look as a card; the wallpaper and how often a new one
//              comes; what's been changed from the look in use, each with
//              its way back; the saved default
//   Colours    the palette and the accents
//   Style      the style, its shape dials, the shell's font and size, and
//              the Finish switches
//   Bar        its layout, then its modules, workspaces, windows and clock
//   Panels     flyouts, the launcher, notifications and the overlays
//   Windows    how Hyprland draws windows
//   System     motion, and the fonts, icons and cursor of other apps
// Colours, Style, Bar and Panels open on a preview of the setup as it is.
//
// A look (LookStore) is a starting point: picking one sets everything it
// carries, which can then be adjusted one by one. A field holding such a
// setting is marked while it differs from the look, and the mark puts it
// back; the Look tab lists every such change. Every look but the fallback
// can be removed from its card, which deletes it from looks.json.
//
// Two stores behind it. The shell's own look is Settings.qml, the same
// values the Control Centre edits, so the two always agree and a change
// here applies the moment it's made. The Windows tab is the `general` and
// `decoration` tables in hyprland.lua, written as the Input page writes
// `input`: through HyprLuaWrite, then a reload.

import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import "../services/HyprTables.js" as HyprTables
import "../services/Looks.js" as Looks
import "../services/Styles.js" as Styles
import "../services"
import "../flyouts"
import "../bar"

SettingsPage {
    id: page

    sectioned: true
    // a small bar and flyout, drawn by the shell's own pieces, above the
    // tabs whose settings change how they look
    pinned: LivePreview {}
    pinnedVisible: ["colours", "style", "bar", "panels"].indexOf(tab) !== -1

    title: "Appearance"
    description: "Pick a look, then change anything about it. Changes apply as you make them; a dot marks a setting that differs from the look."

    tabs: [
        { id: "look",      label: "Look",      icon: "󰏘" },
        { id: "colours",   label: "Colours",   icon: "󰌁" },
        { id: "style",     label: "Style",     icon: "󰆧" },
        { id: "bar",       label: "Bar",       icon: "󰕰" },
        { id: "panels",    label: "Panels",    icon: "󰕮" },
        { id: "windows",   label: "Windows",   icon: "󰖲" },
        { id: "system",    label: "System",    icon: "󰒓" },
    ]
    stickyColumn: ({ look: tab_look, colours: tab_colours, style: tab_style,
                     bar: tab_bar, panels: tab_panels, windows: tab_windows,
                     system: tab_system })[tab] || tab_look

    function label(v, key) { return Settings.choiceLabel(v, key) }

    // the field a control sits in, marked as holding `key` when a look
    // carries it
    function markField(control, key) {
        var f = control.parent ? control.parent.parent : null
        if (f && f.isSettingsField === true && f.lookKey === "" && Looks.looks[Looks.fallback].settings[key] !== undefined)
            f.lookKey = key
    }

    // on the page rather than the card: the reload after the write destroys
    // the removed look's card before the result comes back
    function removeLook(name) { Settings.removeLook(name, (ok, msg) => say(msg, !ok)) }

    // --- shell pieces --------------------------------------------------------

    // One chip per value of a Settings choice, lit on the current one.
    // Past four values the row runs out of room, so those are a dropdown.
    // Both mark the field they sit in as holding a look's setting (lookKey).
    component Choice: SettingsDropdown {
        property string key: ""
        Component.onCompleted: page.markField(this, key)
        anchors.right: parent.right
        model: Settings.choices[key] || []
        current: Settings[key]
        labelFor: v => page.label(v, key)
        onPicked: v => Settings.set(key, v)
    }

    component Choices: FlyoutSegmented {
        id: ch
        property string key: ""
        property bool live: true
        Component.onCompleted: page.markField(this, key)

        anchors.right: parent.right
        fill: false
        enabled: live
        model: Settings.choices[key] || []
        labelFor: v => page.label(v, key)
        current: Settings[key]
        onPicked: v => {
            page.holdInPlace(ch)
            Settings.set(key, v)
        }
    }

    // Settings[key] as any colour, #rrggbb (or #rgb, with or without the
    // #), applied on Enter. The swatch beside it previews what's typed while
    // it parses; a swatch picked above replaces what's typed.
    component HexAccent: SettingsField {
        id: hex
        property string key: ""
        hint: Settings.colourMode === "wallpaper" ? "Grayscale palette only"
            : "Type a hex colour and press Enter"

        function parse(t) {
            var h = String(t).trim().replace(/^#/, "")
            if (/^[0-9a-fA-F]{3}$/.test(h)) h = h.split("").map(c => c + c).join("")
            return /^[0-9a-fA-F]{6}$/.test(h) ? "#" + h.toLowerCase() : ""
        }

        Row {
            id: hexRow
            anchors.right: parent.right
            spacing: Theme.spaceL
            enabled: Settings.colourMode !== "wallpaper"
            opacity: enabled ? 1 : 0.4
            readonly property string typed: hex.parse(hexInput.text)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.chipHeight
                height: Theme.chipHeight
                radius: Theme.radiusSmall
                color: hexRow.typed !== "" ? hexRow.typed : "transparent"
                border.width: Theme.borderWidth
                border.color: Theme.stroke
            }

            FlyoutInput {
                id: hexInput
                width: Theme.fit(110)
                echoPassword: false
                placeholder: "#rrggbb"
                text: Settings[hex.key] || ""
                onAccepted: {
                    if (hexRow.typed === "") {
                        page.say("\"" + text.trim() + "\" isn't a hex colour", true)
                        return
                    }
                    Settings.set(hex.key, hexRow.typed)
                    text = hexRow.typed
                    page.say(hex.label + " set to " + hexRow.typed, false)
                }
                onEscapePressed: text = Settings[hex.key] || ""

                // typing breaks the binding; follow a swatch picked above
                Connections {
                    target: Settings
                    function onAccentChanged() { if (hex.key === "accent") hexInput.text = Settings.accent }
                }
            }
        }
    }

    // A Settings boolean as a switch, resting while the style gives it
    // nothing to do
    component FinishSwitch: SettingsField {
        id: fsw
        property string key: ""
        property bool live: true
        lookKey: key

        Switch {
            anchors.right: parent.right
            enabled: fsw.live
            opacity: fsw.live ? 1 : 0.4
            checked: !!Settings[fsw.key]
            onToggled: Settings.set(fsw.key, !Settings[fsw.key])
        }
    }

    // A Settings integer, stepped by `step` and clamped by Settings.limits.
    component Stepper: SettingsField {
        id: st
        property string key: ""
        property int step: 1
        property string suffix: ""
        lookKey: key

        FlyoutStepper {
            anchors.right: parent.right
            width: Theme.fit(160)
            // guarded: these can evaluate before `key` is assigned
            value: Settings[st.key] || 0
            minimum: (Settings.limits[st.key] || { min: 0 }).min
            maximum: (Settings.limits[st.key] || { max: 0 }).max
            suffix: st.suffix
            valueWidth: 56
            onStepped: d => {
                page.holdInPlace(st)
                Settings.step(st.key, d * st.step)
            }
        }
    }

    // --- the look carousel ----------------------------------------------------
    // One card per look, side by side in a strip that scrolls sideways --
    // by drag, wheel, or the arrows. Each card is a miniature of the look
    // drawn with the look's own values rather than Theme's: its bar with
    // three chips in its module style, and a flyout with a heading, a lit
    // row and a meter, in its palette, accent, corners, strokes and font.
    // Clicking a card applies the look.

    component LookPreview: Rectangle {
        id: pv
        required property var look
        readonly property var pal: look.palette
        // the look's settings with what its style draws (Styles.resolve)
        readonly property var ls: Object.assign({}, look.settings, Styles.resolve(look.settings))
        readonly property color accent: look.accent || pal.bright
        readonly property int r: ls.radius
        readonly property int bw: ls.borderWidth
        readonly property bool floating: ls.barStyle === "floating"
        // islands: no one bar ground, just what's behind the chips
        readonly property bool groundless: ls.barStyle === "islands"
        readonly property bool inset: ls.barStyle !== "full"
        readonly property bool atBottom: ls.barPosition === "bottom"
        readonly property string mod: ls.moduleStyle
        readonly property bool bevelled: ls.frameStyle === "bevel" || grooved
        readonly property bool grooved: ls.frameStyle === "groove"
        readonly property bool stroked: !bevelled && ls.frameStyle !== "corners" && ls.frameStyle !== "none"
        readonly property var bv: look.bevel || { light: Qt.lighter(pal.border, 1.8), dark: Qt.darker(pal.border, 1.8) }

        // the desktop behind it: the look's deepest ground
        color: pal.base
        clip: true

        // bar
        Rectangle {
            id: miniBar
            x: pv.inset ? 5 : 0
            y: pv.atBottom ? parent.height - height - x : x
            width: parent.width - x * 2
            height: Theme.fs(18)
            radius: pv.floating ? Math.min(pv.r, height / 2) : 0
            color: pv.groundless ? "transparent" : pv.pal.bar
            border.width: pv.floating && !pv.bevelled ? pv.bw : 0
            border.color: pv.pal.border

            Bevel {
                visible: pv.floating && pv.bevelled
                anchors.fill: parent
                light: pv.bv.light
                dark: pv.bv.dark
                thickness: pv.bw
            }

            Rectangle {
                visible: !pv.inset && !pv.bevelled
                y: pv.atBottom ? 0 : parent.height - height
                width: parent.width
                height: pv.bw
                color: pv.pal.border
            }

            Bevel {
                visible: !pv.inset && pv.bevelled
                anchors.fill: parent
                light: pv.bv.light
                dark: pv.bv.dark
                thickness: pv.bw
            }

            // an island: its own ground around the chips
            Rectangle {
                visible: pv.ls.barStyle === "islands"
                x: miniChips.x - 3
                width: miniChips.width + 6
                height: parent.height
                radius: Math.min(pv.r, height / 2)
                color: pv.pal.bar
                border.width: pv.bw
                border.color: pv.pal.border
            }

            Row {
                id: miniChips
                anchors.verticalCenter: parent.verticalCenter
                x: pv.ls.barStyle === "islands" ? 6 : 4
                spacing: 3
                Repeater {
                    model: [false, true, false]
                    Rectangle {
                        required property bool modelData
                        width: modelData ? 22 : 14
                        height: miniBar.height - 6
                        radius: pv.mod === "pill" ? height / 2 : Math.min(pv.r, 4)
                        readonly property bool bare: pv.mod === "flat" || pv.mod === "bracket" || pv.mod === "underline"
                        color: bare ? "transparent"
                            : modelData ? pv.pal.overlay
                            : pv.mod === "outline" || pv.mod === "ghost" ? "transparent" : pv.pal.surface
                        border.width: pv.mod === "outline" ? pv.bw : 0
                        border.color: modelData ? pv.accent : pv.pal.border
                        Rectangle {
                            visible: (pv.mod === "flat" && parent.modelData) || pv.mod === "underline"
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 2
                            color: parent.modelData ? pv.accent : pv.pal.border
                        }
                        Text {
                            visible: pv.mod === "bracket"
                            anchors.centerIn: parent
                            text: "[" + " ".repeat(parent.modelData ? 2 : 1) + "]"
                            color: parent.modelData ? pv.accent : pv.pal.muted
                            font.family: pv.ls.fontFamily
                            font.pixelSize: parent.height
                        }
                    }
                }
            }
        }

        // flyout
        Rectangle {
            id: miniPanel
            x: pv.inset ? 14 : 10
            // hangs off the bar, on whichever edge it's on
            y: pv.atBottom ? miniBar.y - height - (pv.inset ? 5 : 0)
                : miniBar.y + miniBar.height + (pv.inset ? 5 : 0)
            width: parent.width * 0.62
            height: miniCol.implicitHeight + 12
            radius: pv.r
            color: pv.pal.panel
            opacity: 1
            border.width: pv.stroked ? pv.bw : 0
            border.color: pv.ls.frameStyle === "accent" ? pv.accent : pv.pal.border

            Bevel {
                visible: pv.bevelled
                anchors.fill: parent
                raised: !pv.grooved
                light: pv.bv.light
                dark: pv.bv.dark
                thickness: pv.bw
            }

            Rectangle {
                visible: pv.ls.frameStyle === "double"
                anchors.fill: parent
                anchors.margins: 3
                radius: Math.max(0, pv.r - 3)
                color: "transparent"
                border.width: 1
                border.color: pv.pal.muted
            }

            Bevel {
                visible: pv.bevelled
                anchors.fill: parent
                anchors.margins: 2
                raised: pv.grooved
                light: pv.pal.surface
                dark: pv.pal.base
                thickness: pv.bw
            }

            FrameCorners {
                visible: pv.ls.frameStyle === "corners"
                anchors.fill: parent
                length: 6
                thickness: pv.bw
                color: pv.accent
            }

            Column {
                id: miniCol
                x: 7
                y: 6
                width: parent.width - 14
                spacing: 3

                Row {
                    spacing: 4
                    Text {
                        text: (pv.ls.headingPrefix ? pv.ls.headingPrefix + " " : "") + (pv.ls.headingUpper ? "SOUND" : "Sound")
                        color: pv.pal.bright
                        font.family: Fonts.resolve(pv.ls.fontFamily)
                        font.pixelSize: Theme.fs(10)
                        font.weight: Theme.weightStrong
                        font.letterSpacing: pv.ls.headingUpper ? 0.5 : 0
                    }
                }
                // a lit row: hover fill and the accent tick
                Rectangle {
                    width: parent.width
                    height: Theme.fs(12)
                    radius: Math.max(0, pv.r - 2)
                    color: pv.pal.overlay
                    Rectangle { width: 2; height: parent.height - 4; y: 2; color: pv.accent }
                    Text {
                        x: 5
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Speakers"
                        color: pv.pal.bright
                        font.family: Fonts.resolve(pv.ls.fontFamily)
                        font.pixelSize: Theme.fs(9)
                    }
                }
                Text {
                    text: "Headphones"
                    color: pv.pal.text
                    font.family: Fonts.resolve(pv.ls.fontFamily)
                    font.pixelSize: Theme.fs(9)
                }
                // meter
                Rectangle {
                    width: parent.width
                    height: 4
                    radius: Math.min(2, pv.r)
                    color: pv.pal.base
                    Rectangle {
                        width: parent.width * 0.65
                        height: parent.height
                        radius: parent.radius
                        color: pv.ls.levelColour === "good" ? pv.look.good : pv.ls.levelColour === "text" ? pv.pal.text : pv.accent
                    }
                }
            }
        }
    }

    // --- visual pickers ------------------------------------------------------
    // A choice judged by eye: one tile per value, each drawing what it does,
    // the current one lit. `art` is a Component reading `parent.value`.
    component Tiles: Column {
        id: tl
        property string key: ""
        property string label: ""
        property string hint: ""
        property Component art: null
        property int columns: 4
        width: parent ? parent.width : 0
        spacing: Theme.spaceXs

        SettingsField {
            label: tl.label
            hint: tl.hint
            lookKey: Looks.looks[Looks.fallback].settings[tl.key] !== undefined ? tl.key : ""
        }

        SettingsTiles {
            columns: tl.columns
            model: (Settings.choices[tl.key] || []).map(v => ({ value: v, text: page.label(v, tl.key) }))
            current: Settings[tl.key]
            art: tl.art
            onPicked: v => {
                page.holdInPlace(tl)
                Settings.set(tl.key, v)
            }
        }
    }

    // Two bar chips, the right one open, as each style draws them
    Component {
        id: styleArt
        Item {
            id: ya
            readonly property string v: parent ? parent.value : ""
            readonly property int cw: Theme.fs(24)
            readonly property int ch: Theme.fs(16)
            readonly property int r: Math.min(Theme.radius, 5)
            width: Theme.fs(64)
            height: Theme.fs(34)

            // Glass: a tinted ground for the frost to sit on
            Rectangle {
                visible: ya.v === "glass"
                anchors.fill: parent
                radius: ya.r
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.darker(Theme.accent, 2.6) }
                    GradientStop { position: 1; color: Theme.surface }
                }
            }
            // Channel: one grooved band round both chips
            Item {
                visible: ya.v === "channel"
                x: 2; y: (ya.height - height) / 2
                width: ya.width - 4; height: ya.ch + 10
                Channel { radius: ya.r + 4 }
            }
            // Tabbed: the panel the open chip hangs into
            Rectangle {
                visible: ya.v === "tabbed"
                x: ya.width / 2; y: ya.height / 2 + ya.ch / 2
                width: ya.width / 2; height: ya.height - y
                color: Theme.panel
                border.width: 1; border.color: Theme.border
            }

            Row {
                anchors.centerIn: parent
                spacing: Theme.fs(6)
                Repeater {
                    model: [false, true]
                    Item {
                        id: chip
                        required property bool modelData
                        readonly property bool lit: modelData
                        width: ya.cw; height: ya.ch

                        Rectangle {
                            anchors.fill: parent
                            visible: ya.v !== "minimal" && ya.v !== "terminal" && ya.v !== "channel"
                                && !(ya.v === "basic" && !chip.lit) && !(ya.v === "tabbed" && !chip.lit)
                            radius: ya.v === "capsule" ? height / 2 : ya.v === "retro" ? 0
                                : ya.v === "tabbed" ? 0 : ya.r
                            color: ya.v === "glass" ? Qt.rgba(1, 1, 1, chip.lit ? 0.16 : 0.08)
                                : ya.v === "lined" ? Theme.panel
                                : ya.v === "tabbed" ? Theme.panel
                                : ya.v === "retro" ? Theme.surface
                                : (ya.v === "flat" || ya.v === "capsule") && chip.lit ? Theme.accent
                                : Theme.overlay
                            border.width: ya.v === "lined" || ya.v === "glass" ? 1 : 0
                            border.color: ya.v === "glass" ? Qt.rgba(1, 1, 1, 0.2) : chip.lit ? Theme.accent : Theme.border

                            Rectangle {
                                visible: ya.v === "lined"
                                anchors.fill: parent; anchors.margins: 2
                                radius: Math.max(0, parent.radius - 2)
                                color: "transparent"
                                border.width: 1; border.color: Theme.overlay
                            }
                            Bevel {
                                visible: ya.v === "retro"
                                anchors.fill: parent
                                raised: !chip.lit
                                light: Theme.bevelLight; dark: Theme.bevelDark
                            }
                            Rectangle {
                                visible: ya.v === "tabbed"
                                width: parent.width; height: 2
                                color: Theme.accent
                            }
                        }
                        // Channel's open chip: a fill and an accent ring
                        Rectangle {
                            visible: ya.v === "channel" && chip.lit
                            anchors.fill: parent
                            radius: ya.r
                            color: Theme.overlay
                            border.width: 2; border.color: Theme.accent
                        }
                        // the icon
                        Rectangle {
                            anchors.centerIn: parent
                            width: Theme.fs(8); height: Theme.fs(5)
                            radius: 1
                            color: (ya.v === "flat" || ya.v === "capsule") && chip.lit ? Theme.bright : Theme.text
                        }
                        // Minimal: a rule under each, lit under the open one
                        Rectangle {
                            visible: ya.v === "minimal"
                            anchors.bottom: parent.bottom
                            width: parent.width; height: 2
                            color: chip.lit ? Theme.accent : Theme.border
                        }
                        Text {
                            visible: ya.v === "terminal"
                            anchors.centerIn: parent
                            text: "[    ]"
                            color: chip.lit ? Theme.accent : Theme.muted
                            font.family: Theme.fontText
                            font.pixelSize: Theme.fs(14)
                            font.weight: Theme.weightStrong
                        }
                    }
                }
            }
        }
    }

    // rows packed as each density packs them
    Component {
        id: densityArt
        Rectangle {
            id: da
            readonly property string v: parent ? parent.value : ""
            readonly property int gap: v === "compact" ? 2 : v === "roomy" ? 6 : 4
            width: Theme.fs(64)
            height: Theme.fs(34)
            radius: Theme.radius + 2
            color: Theme.surface
            border.width: Theme.borderWidth
            border.color: Theme.muted
            clip: true

            Column {
                x: da.gap + 4
                y: da.gap + 3
                width: da.width - x * 2
                spacing: da.gap
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        width: parent.width * (index === 0 ? 0.6 : 1)
                        height: 3
                        radius: 1.5
                        color: index === 0 ? Theme.subtext : Theme.muted
                    }
                }
            }
        }
    }

    // --- live preview --------------------------------------------------------
    // The shell's own bar chips and a flyout, scaled down over the wallpaper,
    // so every change on the visual tabs shows as it's made. Built from the
    // real components, which read Theme, so it can't drift from the shell.
    component PreviewGroup: Item {
        default property alias chips: chipRow.data
        width: chipRow.width + (Theme.moduleGrouped ? Theme.channelWidth * 2 : 0)
        height: Theme.barHeight

        Item {
            visible: Theme.moduleGrouped
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Theme.groupHeight
            Channel { radius: Theme.groupRadius }
        }
        Row {
            id: chipRow
            x: Theme.moduleGrouped ? Theme.channelWidth : 0
            spacing: Theme.moduleSpacing
        }
    }

    component PreviewGlyph: Text {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: Theme.textStrong
        font.family: Theme.fontIcon
        font.pixelSize: Theme.iconSize
    }

    component LivePreview: Rectangle {
        id: lp
        readonly property real sc: 0.62
        width: parent ? parent.width : 0
        height: Math.round(stage.height * sc) + Theme.spaceL * 2
        radius: Theme.radiusInner
        color: Theme.base
        clip: true

        Image {
            anchors.fill: parent
            source: Wallpaper.current !== "" ? "file://" + Wallpaper.current : ""
            sourceSize.width: 640
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: 0.85
        }

        Item {
            id: stage
            x: Theme.spaceL
            y: Theme.spaceL
            width: (lp.width - Theme.spaceL * 2) / lp.sc
            height: Theme.barHeight + Theme.spaceS + flyout.height
            scale: lp.sc
            transformOrigin: Item.TopLeft

            Rectangle {
                width: parent.width
                height: Theme.barHeight
                radius: Theme.barFloating ? Theme.barRadius : Theme.radiusSmall
                color: Qt.rgba(Theme.bar.r, Theme.bar.g, Theme.bar.b, Theme.barOpacity)
                border.width: Theme.barFloating ? Theme.borderWidth : 0
                border.color: Theme.stroke
            }

            PreviewGroup {
                x: Theme.barInset + Theme.moduleGap
                ModuleFrame { PreviewGlyph { text: "󰣇" } }
                ModuleFrame {
                    Row {
                        spacing: Theme.spaceS
                        anchors.verticalCenter: parent.verticalCenter
                        Repeater {
                            model: 4
                            Rectangle {
                                required property int index
                                anchors.verticalCenter: parent.verticalCenter
                                width: index === 1 ? 18 : 6
                                height: 6
                                radius: 3
                                color: index === 1 ? Theme.accent : Theme.muted
                            }
                        }
                    }
                }
            }

            PreviewGroup {
                anchors.horizontalCenter: parent.horizontalCenter
                ModuleFrame {
                    active: true
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(new Date(), Theme.timeFormat)
                        color: Theme.textStrong
                        font.family: Theme.fontText
                        font.pixelSize: Theme.barLabelSize
                        font.weight: Theme.weightBody
                    }
                }
            }

            PreviewGroup {
                anchors.right: parent.right
                anchors.rightMargin: Theme.barInset + Theme.moduleGap
                ModuleFrame { PreviewGlyph { text: "󰖩" } }
                ModuleFrame {
                    fixedWidth: Theme.moduleWidth
                    fillValue: 0.45
                    PreviewGlyph { text: "󰕾" }
                }
                ModuleFrame {
                    fixedWidth: Theme.moduleWidth
                    fillValue: 0.8
                    fillColor: Theme.good
                    PreviewGlyph { text: "󰂄" }
                }
            }

            PanelFrame {
                id: flyout
                readonly property int padX: Theme.frameChannel ? Theme.channelWidth * 2 + 3 + Theme.spaceL : Theme.panelPad
                readonly property int padY: Theme.frameChannel ? Theme.channelWidth * 2 + 3 + Theme.spaceS : Theme.panelPad
                anchors.right: parent.right
                y: Theme.barHeight + Theme.spaceS
                width: Theme.fit(260) + padX * 2
                height: flyCol.implicitHeight + padY * 2
                ground: Theme.frameChannel ? Theme.surface : Theme.panelFill

                SectionRuns {
                    visible: Theme.frameChannel
                    x: Theme.channelWidth + 3
                    width: flyout.width - x * 2
                    height: flyout.height
                    column: flyCol
                    columnY: flyCol.y
                }

                Column {
                    id: flyCol
                    readonly property bool sectioned: Theme.frameChannel
                    x: flyout.padX
                    y: flyout.padY
                    width: flyout.width - flyout.padX * 2
                    spacing: Theme.spaceM

                    FlyoutHeading { text: "VOLUME  45%" }
                    Slider { width: parent.width; value: 45 }
                    FlyoutDivider {}
                    FlyoutAction { icon: "󰕾"; label: "Mute"; checked: false }
                    FlyoutRow { label: "Speakers"; highlighted: true }
                    FlyoutRow { label: "More in Settings"; trailing: "󰁔" }
                }
            }
        }

        // a picture: nothing in it takes the pointer
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
        }
    }

    // --- the Look tab's changes ----------------------------------------------

    // What each setting a look carries is called on this page, for the list
    // of changes; the same as its field's label, so "Show" can find it
    readonly property var keyLabels: ({
        style: "Style", radius: "Roundness", barStyle: "Bar shape", density: "Density",
        seeThrough: "See-through", scrim: "Overlay dimming", barSeparator: "Separators",
        shadows: "Shadows", gradient: "Shaded grounds", heavyLines: "Heavy lines",
        headingUpper: "Capital headings", headingRule: "Heading rule",
        fontFamily: "Font", barPosition: "Position", workspaceStyle: "Workspaces",
        clockStyle: "Clock", windowStyle: "Open windows", windowScope: "Windows shown",
        iconTint: "App icons", vizStyle: "Visualizer", flyoutAnim: "Flyouts open",
        launcherLayout: "Launcher layout", launcherPosition: "Launcher position",
        launcherDetails: "Launcher details", notifStyle: "Notification popups",
        altTabStyle: "Window switcher", overviewLayout: "Workspace overview",
        overviewBackdrop: "Overview backdrop", powerStyle: "Power menu", levelStyle: "Level popup",
        accent: "Accent", levelColour: "Level colour",
    })
    readonly property var keyUnits: ({ radius: "px", seeThrough: "%", scrim: "%" })
    function valueText(k, v) {
        if (typeof v === "boolean") return v ? "on" : "off"
        if (typeof v === "number") return v + (keyUnits[k] || "")
        if (v === "") return "none"
        return page.label(v, k)
    }

    // The Look tab's list of changes: each setting that differs from the
    // look in use, what it is now and what the look has, a way to the field
    // and a way back
    component LookChanges: Column {
        width: parent.width
        spacing: Theme.spaceM

        // every change at once
        SettingsField {
            label: Settings.baselineIsDefault ? "Back to default" : "Reset look"
            visible: !Settings.lookPristine
            hint: Settings.baselineIsDefault ? "Put all of these back to your saved default"
                : "Put all of these back to " + page.label(Settings.look) + "'s own"

            FlyoutChip {
                anchors.right: parent.right
                text: "Undo all"
                onClicked: {
                    Settings.undoLookChanges()
                    page.say(Settings.baselineIsDefault ? "Saved default restored"
                        : page.label(Settings.look) + " look restored", false)
                }
            }
        }

        Text {
            visible: Settings.lookPristine
            width: parent.width
            wrapMode: Text.WordWrap
            text: Settings.baselineIsDefault
                ? "Nothing changed since you saved your default. Anything you change on the other tabs shows up here."
                : "Nothing changed — " + page.label(Settings.look) + " is as it was designed. Anything you change on the other tabs shows up here."
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }

        Repeater {
            model: Settings.lookDiffs

            SettingsField {
                id: change
                required property string modelData
                // shares its label with the field it stands for
                searchable: false
                readonly property var lookValue: Settings.lookBaseline[modelData]
                label: page.keyLabels[modelData] || modelData
                hint: "Now " + page.valueText(modelData, Settings[modelData])
                    + " · " + (Settings.baselineIsDefault ? "default" : page.label(Settings.look))
                    + " has " + page.valueText(modelData, change.lookValue)

                Row {
                    anchors.right: parent.right
                    spacing: Theme.spaceS
                    FlyoutChip {
                        text: "Show"
                        onClicked: page.highlight = change.label
                    }
                    FlyoutChip {
                        text: "Undo"
                        onClicked: Settings.resetLookKey(change.modelData)
                    }
                }
            }
        }
    }

    SettingsTab {
        id: tab_look
        page: page
        tabId: "look"

        FlyoutHeading { text: "LOOK" }

        Item {
            id: carousel
            width: parent.width
            height: lookStrip.height + Theme.spaceL + dots.height

            readonly property int cardWidth: Theme.fit(210)
            // tall enough for the preview, the name and two lines of description,
            // so no card ends in an empty line
            readonly property int previewHeight: Math.round((cardWidth - Theme.spaceS * 2) * 0.48)
            readonly property int cardHeight: Theme.spaceS + previewHeight + Theme.spaceS
                + Math.ceil(nameMetrics.height) + Theme.spaceXs + Math.ceil(blurbMetrics.height) * 2 + Theme.spaceL + Theme.spaceS

            FontMetrics { id: nameMetrics; font.family: Theme.fontText; font.pixelSize: Theme.fontBody }
            FontMetrics { id: blurbMetrics; font.family: Theme.fontText; font.pixelSize: Theme.fontSmall }

            ListView {
                id: lookStrip
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: prevChip.width + Theme.spaceS
                anchors.rightMargin: nextChip.width + Theme.spaceS
                height: carousel.cardHeight
                orientation: ListView.Horizontal
                spacing: Theme.spaceL
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                highlightFollowsCurrentItem: false
                // every card built up front, so none is created mid-scroll
                cacheBuffer: count * step
                model: LookStore.order
                // open on the current look
                Component.onCompleted: positionViewAtIndex(Math.max(0, LookStore.order.indexOf(Settings.look)), ListView.Center)

                readonly property real step: carousel.cardWidth + spacing
                readonly property real maxX: originX + Math.max(0, contentWidth - width)

                NumberAnimation on contentX {
                    id: glide
                    running: false
                    duration: Theme.durSlow
                    easing.type: Theme.ease
                }

                function glideTo(x) {
                    glide.stop()
                    glide.to = Math.max(originX, Math.min(maxX, x))
                    glide.start()
                }

                // a page is one card: from the first card wholly in view, which
                // at the end of the strip isn't the one at its left edge
                function page(d) {
                    var first = Math.ceil((contentX - originX) / step - 0.01)
                    glideTo(originX + (first + d) * step)
                }

                // scroll just far enough to show card i whole
                function reveal(i) {
                    var x = originX + i * step
                    if (x < contentX) glideTo(x)
                    else if (x + carousel.cardWidth > contentX + width) glideTo(x + carousel.cardWidth - width)
                }

                // A plain mouse wheel, or a touchpad's vertical two-finger
                // swipe, has no x component -- repurpose that into scrolling
                // the strip sideways, so the page's own vertical scroll
                // doesn't have to be escaped first to reach it.
                //
                // A genuine horizontal swipe already carries an x component,
                // and is left alone here (event.accepted = false) so it falls
                // through to the ListView's own wheel handling -- the same
                // handling every vertical Flickable in the shell uses, which
                // is what makes swiping left move the view left there. Routing
                // it through the line above instead applied vertical's sign
                // convention to a horizontal gesture, which is backwards for it.
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        if (event.angleDelta.x !== 0) { event.accepted = false; return }
                        glide.stop()
                        lookStrip.contentX = Math.max(lookStrip.originX, Math.min(lookStrip.maxX,
                            lookStrip.contentX - event.angleDelta.y))
                    }
                }

                delegate: Rectangle {
                    id: card
                    required property string modelData
                    required property int index
                    readonly property var look: LookStore.looks[modelData]
                    readonly property bool current: Settings.look === modelData

                    width: carousel.cardWidth
                    height: lookStrip.height
                    radius: Theme.radius
                    color: Theme.surface
                    border.width: current ? 2 : Theme.borderWidth
                    border.color: current ? Theme.accent
                        : cardMouse.containsMouse ? Theme.strokeFocus : Theme.stroke

                    LookPreview {
                        id: preview
                        look: card.look
                        x: Theme.spaceS
                        y: Theme.spaceS
                        width: parent.width - Theme.spaceS * 2
                        height: carousel.previewHeight
                        radius: Theme.radiusInner
                    }

                    Column {
                        anchors.top: preview.bottom
                        anchors.topMargin: Theme.spaceS
                        x: Theme.spaceL
                        width: parent.width - Theme.spaceL * 2
                        spacing: Theme.spaceXs

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: card.look.name + (card.current ? (Settings.lookPristine ? "  ·  in use" : "  ·  adjusted") : "")
                            color: card.current ? Theme.textStrong : Theme.text
                            font.family: Fonts.resolve(card.look.settings.fontFamily)
                            font.pixelSize: Theme.fontBody
                            font.bold: true
                        }
                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            text: card.look.description
                            color: Theme.subtext
                            font.family: Theme.fontText
                            font.weight: Theme.weightBody
                            font.pixelSize: Theme.fontSmall
                        }
                    }

                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Settings.set("look", card.modelData)
                            page.say(card.look.name + " look applied", false)
                        }
                    }

                    // Remove, in the preview's corner: two clicks, since it
                    // deletes the look from looks.json and there's no undo short
                    // of git. Its own ground, so it reads over any preview.
                    Rectangle {
                        id: removeBox
                        visible: LookStore.removable(card.modelData)
                                 && (cardMouse.containsMouse || removeHover.hovered || removeChip.armed)
                        anchors.right: preview.right
                        anchors.top: preview.top
                        anchors.margins: Theme.spaceXs
                        width: removeChip.width
                        height: removeChip.height
                        radius: Theme.radiusInner
                        color: Theme.surface

                        HoverHandler { id: removeHover }

                        FlyoutChip {
                            id: removeChip
                            glyph: true
                            text: "󰅖"
                            confirmText: "Remove"
                            onClicked: page.removeLook(card.modelData)
                        }
                    }
                }
            }

            FlyoutChip {
                id: prevChip
                anchors.left: parent.left
                y: (lookStrip.height - height) / 2
                glyph: true
                text: "󰅁"
                enabled: !lookStrip.atXBeginning
                onClicked: lookStrip.page(-1)
            }

            FlyoutChip {
                id: nextChip
                anchors.right: parent.right
                y: (lookStrip.height - height) / 2
                glyph: true
                text: "󰅂"
                enabled: !lookStrip.atXEnd
                onClicked: lookStrip.page(1)
            }

            // one dot per look, the current one lit; click to jump
            Row {
                id: dots
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                spacing: Theme.spaceS
                Repeater {
                    model: LookStore.order
                    Rectangle {
                        required property string modelData
                        required property int index
                        width: Settings.look === modelData ? Theme.fs(14) : Theme.fs(6)
                        height: Theme.fs(6)
                        radius: Theme.fs(3)
                        color: Settings.look === modelData ? Theme.accent : Theme.muted
                        Behavior on width { NumberAnimation { duration: Theme.durFast; easing.type: Theme.ease } }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: lookStrip.reveal(parent.index)
                        }
                    }
                }
            }
        }

        Item { width: 1; height: Theme.spaceM }
        FlyoutHeading { text: "WALLPAPER" }

        SettingsField {
            label: "Current"
            hint: Wallpaper.name !== "" ? Wallpaper.name : "No wallpaper"

            Row {
                anchors.right: parent.right
                spacing: Theme.spaceS

                FlyoutChip { glyph: true; text: "󰒮"; enabled: Wallpaper.images.length > 1; onClicked: Wallpaper.step(-1) }

                FlyoutChip { glyph: true; text: "󰒝"; enabled: Wallpaper.images.length > 1; onClicked: Wallpaper.shuffle() }
                FlyoutChip { glyph: true; text: "󰒭"; enabled: Wallpaper.images.length > 1; onClicked: Wallpaper.step(1) }
            }
        }

        SettingsField {
            label: "One per look"
            hint: Settings.wallpaperPerLook ? "Each look keeps its own wallpaper"
                : "Every look shares this wallpaper"

            Switch {
                anchors.right: parent.right
                checked: Settings.wallpaperPerLook
                onToggled: Settings.setWallpaperPerLook(!Settings.wallpaperPerLook)
            }
        }

        // One choice over two settings: whether login picks a random wallpaper
        // (Settings.wallpaperShuffle, which wallpaper.sh reads) and whether one
        // is picked on a timer while logged in (wallpaperInterval). A timer
        // implies a random one at login too.
        SettingsField {
            label: "New wallpaper"
            hint: Settings.wallpaperInterval > 0 ? "Random at login, then on this interval"
                : Settings.wallpaperShuffle ? "A random one every login"
                : "Stays until you pick another"

            FlyoutSegmented {
                anchors.right: parent.right
                fill: false
                model: [{ value: "never", text: "Never" }, { value: "login", text: "At login" },
                        { value: 15, text: "15 min" }, { value: 30, text: "30 min" },
                        { value: 60, text: "1 hour" }, { value: 180, text: "3 hours" }]
                current: Settings.wallpaperInterval > 0 ? Settings.wallpaperInterval
                    : Settings.wallpaperShuffle ? "login" : "never"
                onPicked: v => {
                    Settings.setWallpaperShuffle(v !== "never")
                    Settings.set("wallpaperInterval", typeof v === "number" ? v : 0)
                }
            }
        }

        // Every image, four to a row; click one to show it.
        Flow {
            id: grid
            width: parent.width
            spacing: Theme.spaceL

            readonly property int columns: 4
            readonly property real cellWidth: (width - spacing * (columns - 1)) / columns

            Repeater {
                model: Wallpaper.images

                ClippingRectangle {
                    id: thumb
                    required property string modelData
                    readonly property bool current: modelData === Wallpaper.current

                    width: grid.cellWidth
                    height: Math.round(width * 9 / 16)
                    radius: Theme.radiusInner
                    color: Theme.base
                    border.width: current ? 2 : Theme.borderWidth
                    border.color: current ? Theme.accent
                        : thumbMouse.containsMouse ? Theme.strokeFocus : Theme.stroke

                    Image {
                        anchors.fill: parent
                        source: "file://" + thumb.modelData
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        // decoded at thumbnail size, not the image's own 4K
                        sourceSize.width: 360
                    }

                    MouseArea {
                        id: thumbMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wallpaper.set(thumb.modelData)
                    }
                }
            }
        }

        Text {
            visible: Wallpaper.images.length === 0
            text: "No images in the repo's wallpapers/ folder"
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontBody
        }

        Item { width: 1; height: Theme.spaceM }
        FlyoutHeading {
            text: Settings.lookPristine ? "CHANGES" : "CHANGES  " + Settings.lookDiffs.length
        }

        LookChanges {}

        Item { width: 1; height: Theme.spaceM }
        FlyoutHeading { text: "SAVED DEFAULT" }

        SettingsField {
            id: saveField
            label: "Set as default"
            // two clicks: overwriting the old default can't be undone
            hint: saveChip.armed ? "Click again to replace the saved default"
                : Settings.isDefault ? "This is the default"
                : "Make everything as it is now what Reset returns to"

            FlyoutChip {
                id: saveChip
                anchors.right: parent.right
                text: "Save"
                confirmText: "Confirm"
                enabled: !Settings.isDefault
                onClicked: {
                    Settings.saveAsDefault()
                    page.say("Current appearance saved as the default", false)
                }
            }
        }

        SettingsField {
            label: "Reset to default"
            hint: Settings.isDefault ? "Already at the default"
                : Settings.hasUserDefault ? "Back to the appearance you saved as default"
                : "Back to stock: the " + page.label(Looks.fallback) + " look as designed"

            FlyoutChip {
                anchors.right: parent.right
                text: "Reset"
                enabled: !Settings.isDefault
                onClicked: {
                    Settings.reset()
                    page.say("Appearance reset to the default", false)
                }
            }
        }

        SettingsField {
            label: "Factory reset"
            hint: Settings.hasUserDefault ? "Forget the saved default and go back to stock"
                : "No saved default — stock is the default"

            FlyoutChip {
                anchors.right: parent.right
                text: "Forget"
                enabled: Settings.hasUserDefault
                onClicked: {
                    Settings.factoryReset()
                    page.say("Saved default cleared, back to stock", false)
                }
            }
        }

    }

    SettingsTab {
        id: tab_colours
        page: page
        tabId: "colours"

        FlyoutHeading { text: "PALETTE" }

        SettingsField {
            label: "Palette"
            hint: "Grayscale, or tones from the wallpaper"
            Choices { key: "colourMode" }
        }

        SettingsField {
            label: "Intensity"
            visible: Settings.colourMode === "wallpaper"
            hint: Settings.colourMode !== "wallpaper" ? "Wallpaper palette only"
                : Wallpaper.generating ? "Generating palette…"
                : "How much wallpaper colour comes through"
            Choices { key: "colourScheme"; live: Settings.colourMode === "wallpaper" }
        }

        SettingsField {
            label: "Shade"
            visible: Settings.colourMode === "wallpaper"
            hint: Settings.colourMode !== "wallpaper" ? "Wallpaper palette only"
                : "Dark or light grounds; apps follow"
            Choices { key: "colourVariant"; live: Settings.colourMode === "wallpaper" }
        }

        // The palette in use, role by role, darkest to brightest.
        Row {
            id: swatches
            width: parent.width
            spacing: Theme.spaceS

            readonly property var roles: ["base", "bar", "panel", "surface", "overlay",
                                          "border", "muted", "subtext", "text", "bright"]

            Repeater {
                model: swatches.roles

                Column {
                    id: sw
                    required property string modelData
                    width: (swatches.width - swatches.spacing * (swatches.roles.length - 1)) / swatches.roles.length
                    spacing: Theme.sp(3)

                    Rectangle {
                        width: parent.width
                        height: Theme.fieldHeight
                        radius: Theme.radiusInner
                        color: Theme[sw.modelData]
                        border.width: Theme.borderWidth
                        border.color: Theme.stroke
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: sw.modelData
                        color: Theme.subtext
                        font.family: Theme.fontText
                        font.weight: Theme.weightBody
                        font.pixelSize: Theme.fontSmall
                    }
                }
            }
        }

        Item { width: 1; height: Theme.spaceM }
        FlyoutHeading { text: "ACCENTS" }

        // The look's own accent, the presets and None, with a gap after the
        // look's own; a custom accent in use joins the end. Wraps rather than
        // running under the label when the window is narrow. The wallpaper
        // palette brings its own, so the picker rests while that's on.
        SettingsField {
            id: accentField
            label: "Accent"
            lookKey: "accent"
            hint: Settings.colourMode === "wallpaper" ? "The wallpaper's own tone is used"
                : Settings.lookAccent !== "" ? "Selection and focus. First is " + page.label(Settings.look) + "'s own"
                : "Selection, focus, the current item"

            readonly property int swatch: Theme.chipHeight
            readonly property int gap: Theme.spaceS
            // the look's own swatch is followed by a wider gap
            readonly property int lead: Settings.lookAccent !== "" ? Theme.spaceM : 0

            Flow {
                id: accentFlow
                anchors.right: parent.right
                spacing: accentField.gap
                enabled: Settings.colourMode !== "wallpaper"
                opacity: enabled ? 1 : 0.4
                width: Math.min(parent.width, Settings.accents.length * (accentField.swatch + accentField.gap)
                    + accentField.lead + noneChip.width)

                Repeater {
                    model: Settings.accents

                    Item {
                        id: swatch
                        required property string modelData
                        required property int index
                        readonly property bool current: Settings.accent === modelData
                        width: accentField.swatch + (index === 0 ? accentField.lead : 0)
                        height: accentField.swatch

                        Rectangle {
                            width: accentField.swatch
                            height: accentField.swatch
                            radius: Theme.radiusSmall
                            color: swatch.modelData
                            border.width: swatch.current ? 2 : swatchMouse.containsMouse ? Theme.borderWidth : 0
                            border.color: Theme.textStrong

                            MouseArea {
                                id: swatchMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Settings.set("accent", swatch.modelData)
                            }
                        }
                    }
                }

                FlyoutChip {
                    id: noneChip
                    text: "None"
                    selected: Settings.accent === ""
                    onClicked: Settings.set("accent", "")
                }
            }
        }

        HexAccent { label: "Custom accent"; key: "accent" }

        SettingsField {
            label: "Level colour"
            hint: "Volume, brightness and battery fills"
            Choices { key: "levelColour" }
        }

    }

    SettingsTab {
        id: tab_style
        page: page
        tabId: "style"

        FlyoutHeading { text: "STYLE" }

        Tiles { key: "style"; label: "Style"; hint: Styles.get(Settings.style).hint; art: styleArt; columns: 5 }

        Item { width: 1; height: Theme.spaceM }
        FlyoutHeading { text: "SHAPE" }

        Stepper {
            label: "Roundness"; key: "radius"; suffix: "px"
            hint: Theme.moduleStyle === "pill" ? "Panels and windows; chips are pills" : "Chips, panels, the bar and every window"
        }

        SettingsField {
            label: "Bar shape"
            hint: "Where flyouts sit follows it"
            Choices { key: "barStyle" }
        }

        Tiles { key: "density"; label: "Density"; hint: "Spacing, bar height and gaps"; art: densityArt }

        Stepper { label: "See-through"; hint: Theme.glass ? "The bar and panels; Glass adds more" : "The bar and every panel"; key: "seeThrough"; step: 5; suffix: "%" }

        Stepper { label: "Overlay dimming"; hint: "Behind full-screen overlays"; key: "scrim"; step: 5; suffix: "%" }

        Item { width: 1; height: Theme.spaceM }
        FlyoutHeading { text: "TEXT" }

        // The box shows the font in use, set in itself, and the list sets every
        // installed choice in its own font.
        SettingsField {
            label: "Font"
            lookKey: "fontFamily"
            hint: Theme.fontText !== Settings.fontFamily
                ? page.label(Settings.fontFamily) + " isn't available, so " + page.label(Theme.fontText) + " stands in"
                : "Monospace; text and icons alike"

            SettingsDropdown {
                anchors.right: parent.right
                model: Fonts.available
                current: Theme.fontText
                labelFor: v => page.label(v)
                fontFor: v => v
                onPicked: v => Settings.set("fontFamily", v)
            }
        }

        // Fonts installed since the shell started, which Qt can't draw until
        // it's restarted (see Fonts.qml)
        SettingsField {
            visible: Fonts.pending.length > 0
            label: Fonts.pending.length === 1 ? "1 new font" : Fonts.pending.length + " new fonts"
            hint: Fonts.pending.map(f => page.label(f)).join(", ") + " — usable after a restart"

            FlyoutChip {
                anchors.right: parent.right
                text: "Restart shell"
                onClicked: Fonts.restartShell()
            }
        }

        Stepper { label: "Font size"; hint: "Everything else scales with it"; key: "fontSize"; suffix: "px" }

        Item { width: 1; height: Theme.spaceM }
        FlyoutHeading { text: "FINISH" }

        SettingsField {
            label: "Separators"
            hint: "Between the bar's modules"
            Choice { key: "barSeparator" }
        }

        FinishSwitch {
            label: "Shadows"; key: "shadows"
            live: Styles.get(Settings.style).shadow !== "none"
            hint: live ? "The style's " + Styles.get(Settings.style).shadow + " shadow, windows too" : "This style has none"
        }

        FinishSwitch { label: "Shaded grounds"; key: "gradient"; hint: "A faint shade down the bar and panels" }

        FinishSwitch {
            label: "Heavy lines"; key: "heavyLines"
            live: Styles.get(Settings.style).lines
            hint: live ? "Every stroke 2px, windows' borders too" : "This style has no lines"
        }

        FinishSwitch { label: "Capital headings"; key: "headingUpper"; hint: "VOLUME or Volume" }

        FinishSwitch { label: "Heading rule"; key: "headingRule"; hint: "A line out to the panel's edge" }

    }

    SettingsTab {
        id: tab_bar
        page: page
        tabId: "bar"

        FlyoutHeading { text: "LAYOUT" }

        SettingsField {
            label: "Position"
            lookKey: "barPosition"
            hint: "Flyouts open from whichever edge it's on"

            FlyoutSegmented {
                anchors.right: parent.right
                fill: false
                model: [{ value: "top", text: "Top" }, { value: "bottom", text: "Bottom" }]
                current: Settings.barPosition
                onPicked: v => Settings.set("barPosition", v)
            }
        }

        Item { width: 1; height: Theme.spaceM }
        FlyoutHeading { text: "MODULES" }

        SettingsField {
            label: "Visualizer"
            hint: "The audio spectrum while sound plays"
            Choices { key: "vizStyle" }
        }

        SettingsField {
            label: "Tray drawer"
            hint: Settings.trayDrawer ? "Icons fold behind a chevron"
                : "Every tray icon shows"

            Switch {
                anchors.right: parent.right
                checked: Settings.trayDrawer
                onToggled: Settings.set("trayDrawer", !Settings.trayDrawer)
            }
        }

        Item { width: 1; height: Theme.spaceM }
        FlyoutHeading { text: "WORKSPACES" }

        SettingsField {
            label: "Workspaces"
            hint: "How the workspace indicator marks each one"
            Choice { key: "workspaceStyle" }
        }

        // the names the Names workspace style shows, comma-separated in
        // workspace order; a blank one falls back to the number
        SettingsField {
            label: "Workspace names"
            visible: Theme.workspaceStyle === "names"
            hint: Theme.workspaceStyle === "names" ? "Comma-separated, Enter to apply"
                : "For the Names workspace style"

            FlyoutInput {
                id: wsNames
                anchors.right: parent.right
                width: Theme.fit(240)
                echoPassword: false
                placeholder: "web, code, chat"
                text: Settings.workspaceNames
                onAccepted: {
                    Settings.set("workspaceNames", text.trim())
                    page.say("Workspace names saved", false)
                }
                onEscapePressed: text = Settings.workspaceNames
            }
        }

        Item { width: 1; height: Theme.spaceM }
        FlyoutHeading { text: "OPEN WINDOWS" }

        SettingsField {
            label: "Open windows"
            hint: "How open windows are drawn"
            Choice { key: "windowStyle" }
        }

        SettingsField {
            label: "Windows shown"
            hint: "All workspaces, grouped with a rule"
            Choices { key: "windowScope" }
        }

        SettingsField {
            label: "App icons"
            hint: "The open windows' and the tray's"
            Choices { key: "iconTint" }
        }

        Item { width: 1; height: Theme.spaceM }
        FlyoutHeading { text: "CLOCK" }

        SettingsField {
            label: "Clock"
            hint: "What the clock chip shows"
            Choice { key: "clockStyle" }
        }

        // the Custom clock style's pattern, in Qt's date format
        SettingsField {
            label: "Clock format"
            visible: Theme.clockStyle === "custom"
            hint: Theme.clockStyle !== "custom" ? "For the Custom clock style"
                : "Now: " + Qt.formatDateTime(new Date(), Theme.hours(clockFmt.text || "HH:mm"))
                  + ", Enter to apply"

            FlyoutInput {
                id: clockFmt
                anchors.right: parent.right
                width: Theme.fit(240)
                echoPassword: false
                placeholder: "ddd HH:mm"
                text: Settings.clockFormat
                onAccepted: {
                    Settings.set("clockFormat", text.trim() || "HH:mm")
                    page.say("Clock format saved", false)
                }
                onEscapePressed: text = Settings.clockFormat
            }
        }

        SettingsField {
            label: "Clock island"
            hint: !Settings.widgetVisible("clock") ? "Needs the clock on the bar"
                : Settings.clockIsland ? "Volume and layout show in the clock"
                : "Separate toasts under the bar"

            Switch {
                anchors.right: parent.right
                checked: Settings.clockIsland
                onToggled: Settings.setClockIsland(!Settings.clockIsland)
            }
        }

    }

    SettingsTab {
        id: tab_panels
        page: page
        tabId: "panels"

        FlyoutHeading { text: "LAUNCHER" }

        SettingsField {
            label: "Launcher layout"
            hint: "Rows, an icon grid, or one line"
            Choices { key: "launcherLayout" }
        }

        SettingsField {
            label: "Launcher position"
            hint: "Centred, under the bar, or full screen"
            Choices { key: "launcherPosition" }
        }

        SettingsField {
            label: "Launcher details"
            lookKey: "launcherDetails"
            hint: Settings.launcherDetails ? "Second lines and key hints"
                : "Names only"

            Switch {
                anchors.right: parent.right
                checked: Settings.launcherDetails
                onToggled: Settings.set("launcherDetails", !Settings.launcherDetails)
            }
        }

        Item { width: 1; height: Theme.spaceM }
        FlyoutHeading { text: "NOTIFICATIONS" }

        SettingsField {
            label: "Notification popups"
            hint: "How much each popup shows"
            Choices { key: "notifStyle" }
        }

        Item { width: 1; height: Theme.spaceM }
        FlyoutHeading { text: "OVERLAYS" }

        SettingsField {
            label: "Window switcher"
            hint: "ALT+Tab's cards"
            Choices { key: "altTabStyle" }
        }

        SettingsField {
            label: "Workspace overview"
            hint: "SUPER+W's layout"
            Choices { key: "overviewLayout" }
        }

        SettingsField {
            label: "Overview backdrop"
            hint: "Behind the overview"
            Choices { key: "overviewBackdrop" }
        }

        SettingsField {
            label: "Power menu"
            hint: "How the power menu lays out"
            Choices { key: "powerStyle" }
        }

        SettingsField {
            label: "Level popup"
            hint: Settings.islandActive ? "Shown in the clock island instead"
                : "The volume and brightness popup"
            Choices { key: "levelStyle"; live: !Settings.islandActive }
        }

    }

    SettingsTab {
        id: tab_windows
        page: page
        tabId: "windows"

        FlyoutHeading { text: "WINDOWS" }

        HyprInt { label: "Gaps between windows"; path: ["general"]; key: "gaps_in"; max: 20 }
        HyprInt { label: "Gaps at screen edges"; path: ["general"]; key: "gaps_out"; max: 40 }
        HyprPercent { label: "Focused opacity"; path: ["decoration"]; key: "active_opacity" }
        HyprPercent { label: "Unfocused opacity"; path: ["decoration"]; key: "inactive_opacity" }
        HyprToggle { label: "Dim unfocused"; path: ["decoration"]; key: "dim_inactive" }
        HyprPercent { label: "Dim strength"; visible: page.hyprField(["decoration"], "dim_inactive").value === true; path: ["decoration"]; key: "dim_strength"; min: 0 }
        HyprToggle { label: "Blur"; note: "Behind translucent windows and layers"; path: ["decoration", "blur"]; key: "enabled" }
        HyprInt { label: "Blur size"; visible: page.blurOn; note: "How far each pass spreads"; path: ["decoration", "blur"]; key: "size"; min: 1; max: 20 }
        HyprInt { label: "Blur passes"; visible: page.blurOn; note: "More is smoother and costs more"; path: ["decoration", "blur"]; key: "passes"; min: 1; max: 4; suffix: "" }

    }

    SettingsTab {
        id: tab_system
        page: page
        tabId: "system"

        FlyoutHeading { text: "MOTION" }

        SettingsField {
            label: "Animations"
            hint: "The shell's and Hyprland's"
            FlyoutSliderRow {
                anchors.right: parent.right
                width: Theme.fit(260)
                label: ""
                suffix: "%"
                value: Settings.animTime
                minimum: Settings.limits.animTime.min
                maximum: Settings.limits.animTime.max
                marks: Settings.animTimeMarks
                onMoved: v => Settings.set("animTime", v)
            }
        }

        SettingsField {
            label: "Window animation"
            hint: "Open, close, minimize, scratchpad"
            Choice { key: "windowAnim" }
        }

        SettingsField {
            label: "Flyouts open"
            hint: Theme.flyoutGrown ? "Grown flyouts always fade" : "How flyouts appear"
            Choice { key: "flyoutAnim" }
        }

        Item { width: 1; height: Theme.spaceM }
        FlyoutHeading { text: "APPS OUTSIDE THE SHELL" }

        // GTK/Qt apps' own font -- independent of the shell's Font under Text. Every
        // choice here is always installed (see Looks.systemFonts), so there's no
        // pending/restart state to show like the shell font has.
        SettingsField {
            label: "System font"
            hint: "GTK and Qt apps outside the shell"

            SettingsDropdown {
                anchors.right: parent.right
                model: Looks.systemFonts
                current: Settings.systemFontFamily
                labelFor: v => page.label(v)
                fontFor: v => v
                onPicked: v => Settings.set("systemFontFamily", v)
            }
        }

        SettingsField {
            label: "Icons"
            hint: "GTK now, Qt when next opened"

            SettingsDropdown {
                anchors.right: parent.right
                model: DesktopThemes.icons
                current: Settings.iconTheme
                labelFor: v => DesktopThemes.label(v)
                onPicked: v => Settings.set("iconTheme", v)
            }
        }

        SettingsField {
            label: "Cursor"
            hint: "Apps pick it up when next opened"

            SettingsDropdown {
                anchors.right: parent.right
                model: DesktopThemes.cursors
                current: Settings.cursorTheme
                labelFor: v => DesktopThemes.label(v)
                onPicked: v => Settings.set("cursorTheme", v)
            }
        }

        Stepper { label: "Cursor size"; key: "cursorSize"; step: 4; suffix: "px" }

    }

    // --- windows: reading and writing hyprland.lua ---------------------------

    // { "general": {key: {editable, value}}, "decoration.blur": ... }, a
    // table being null when the file doesn't have it
    property var conf: ({})
    readonly property var tablePaths: [["general"], ["decoration"], ["decoration", "blur"]]

    // Hyprland's own defaults, for keys the file leaves out
    readonly property var hyprDefaults: ({
        "general.gaps_in": 5, "general.gaps_out": 20,
        "decoration.active_opacity": 1, "decoration.inactive_opacity": 1,
        "decoration.dim_inactive": false, "decoration.blur.enabled": true,
        "decoration.dim_strength": 0.5, "decoration.blur.size": 8, "decoration.blur.passes": 1,
    })

    readonly property bool blurOn: hyprField(["decoration", "blur"], "enabled").value === true

    function hyprField(path, key) {
        var t = conf[path.join(".")]
        if (!t) return { editable: false, value: hyprDefaults[path.join(".") + "." + key] }
        var f = t[key]
        return f === undefined ? { editable: true, value: hyprDefaults[path.join(".") + "." + key], unset: true } : f
    }

    function reread() {
        luaFile.reload()
        luaFile.waitForJob()
        var src = luaFile.text()
        var out = {}
        tablePaths.forEach(p => out[p.join(".")] = src === "" ? null : HyprTables.readConfig(src, p))
        conf = out
        if (src === "") say("Couldn't read " + HyprLuaWrite.confPath, true)
    }

    function setHypr(path, key, v, message) {
        HyprLuaWrite.patch(src => HyprTables.setConfig(src, path, key, v), message,
            path.join(".") + "." + key + " isn't a plain value in hyprland.lua, edit it by hand",
            (ok, msg) => {
                page.say(msg, !ok)
                page.reread()
            })
    }

    Component.onCompleted: {
        reread()
        // picks up fonts and themes installed since the shell started
        Fonts.refresh()
        DesktopThemes.refresh()
    }

    FileView {
        id: luaFile
        path: HyprLuaWrite.confPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: if (!HyprLuaWrite.busy) page.reread()
    }

    component HyprInt: SettingsField {
        id: hi
        property var path: []
        property string key: ""
        property int min: 0
        property int max: 20
        property string suffix: "px"
        // the hint when the value is editable
        property string note: ""
        readonly property var field: page.hyprField(path, key)
        // gaps can be a "top,right,bottom,left" string; that stays hand-edited
        readonly property bool live: field.editable && typeof field.value === "number"

        hint: !field.editable ? "Not a plain value in hyprland.lua"
            : !live ? "Set per side in hyprland.lua (" + field.value + ")" : note

        FlyoutStepper {
            anchors.right: parent.right
            width: Theme.fit(160)
            value: hi.live ? hi.field.value : 0
            minimum: hi.live ? hi.min : 0
            maximum: hi.live ? hi.max : 0
            suffix: hi.suffix
            valueWidth: 56
            onStepped: d => page.setHypr(hi.path, hi.key,
                Math.max(hi.min, Math.min(hi.max, value + d)), hi.label + " " + (value + d) + hi.suffix)
        }
    }

    // A 0-1 opacity, shown and stepped as a percentage
    component HyprPercent: SettingsField {
        id: hp
        property var path: []
        property string key: ""
        property int min: 50
        readonly property var field: page.hyprField(path, key)
        readonly property bool live: field.editable && typeof field.value === "number"
        readonly property int pct: live ? Math.round(field.value * 100) : 100

        hint: live ? "" : "Not a plain value in hyprland.lua"

        FlyoutStepper {
            anchors.right: parent.right
            width: Theme.fit(160)
            value: Math.round(hp.pct / 5)
            // min == max when not editable, which greys both buttons
            minimum: hp.live ? Math.round(hp.min / 5) : 20
            maximum: 20
            displayValue: hp.pct + "%"
            valueWidth: 56
            onStepped: d => {
                var p = Math.max(hp.min, Math.min(100, (value + d) * 5))
                page.setHypr(hp.path, hp.key, p / 100, hp.label + " " + p + "%")
            }
        }
    }

    component HyprToggle: SettingsField {
        id: ht
        property var path: []
        property string key: ""
        readonly property var field: page.hyprField(path, key)

        hint: field.editable ? note : "Not a plain value in hyprland.lua"
        property string note: ""

        Switch {
            anchors.right: parent.right
            checked: ht.field.value === true
            enabled: ht.field.editable
            onToggled: page.setHypr(ht.path, ht.key, !checked, ht.label + " " + (checked ? "off" : "on"))
        }
    }
}
