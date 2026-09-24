// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageAppearance.qml
//
// The Control Centre's Appearance page, laid out with room to see it: every
// look as a card, every wallpaper as a thumbnail rather than one at a time,
// each choice as a row of chips rather than a cycle, and the palette's roles
// as swatches.
//
// A look (LookStore) is a starting point: picking one sets everything in the
// Look and Bar sections, which can then be adjusted one by one. The card
// marks a look that has been adjusted, and Reset look puts it back. Every
// look but the fallback can be removed from its card, which deletes it from
// looks.json.
//
// Two stores behind it. The shell's own look (wallpaper, colours, bar, text,
// motion) is Settings.qml, the same values the flyout edits, so the two
// always agree and a change here applies the moment it's made. The Windows
// section is the `general` and `decoration` tables in hyprland.lua, written
// as the Input page writes `input`: through HyprLuaWrite, then a reload.

import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import "../services/HyprTables.js" as HyprTables
import "../services/Looks.js" as Looks
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    title: "Appearance"
    description: "The shell's look, wallpaper, colours, the bar, text and motion, and how Hyprland draws windows. Shell changes apply as you make them; window changes are saved to hyprland.lua and Hyprland reloads."

    function label(v) { return Settings.choiceLabel(v) }

    // --- shell pieces --------------------------------------------------------

    // One chip per value of a Settings choice, lit on the current one.
    // Past four values the row runs out of room, so those are a dropdown.
    component Choice: SettingsDropdown {
        property string key: ""
        anchors.right: parent.right
        model: Settings.choices[key] || []
        current: Settings[key]
        labelFor: v => page.label(v)
        onPicked: v => Settings.set(key, v)
    }

    component Choices: FlyoutSegmented {
        id: ch
        property string key: ""
        property bool live: true

        anchors.right: parent.right
        fill: false
        enabled: live
        model: Settings.choices[key] || []
        labelFor: v => page.label(v)
        current: Settings[key]
        onPicked: v => {
            page.holdInPlace(ch)
            Settings.set(key, v)
        }
    }

    // A Settings integer, stepped by `step` and clamped by Settings.limits.
    component Stepper: SettingsField {
        id: st
        property string key: ""
        property int step: 1
        property string suffix: ""

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

    // --- look ----------------------------------------------------------------

    FlyoutHeading { text: "LOOK" }

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
        readonly property var ls: look.settings
        readonly property color accent: look.accent || pal.bright
        readonly property int r: ls.radius
        readonly property int bw: look.borderWidth
        readonly property bool floating: ls.barStyle === "floating"
        // islands and bare: no one bar ground, just what's behind the chips
        readonly property bool notch: ls.barStyle === "notch"
        readonly property bool groundless: ls.barStyle === "islands" || ls.barStyle === "bare" || notch
        readonly property bool inset: ls.barStyle !== "full" && !notch
        readonly property bool atBottom: ls.barPosition === "bottom"
        readonly property string mod: ls.moduleStyle
        readonly property bool bevelled: ls.frameStyle === "bevel"
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

            // the notch: a centre ground flush with the screen edge
            Rectangle {
                visible: pv.notch
                x: miniChips.x - 8
                width: miniChips.width + 16
                height: parent.height
                radius: Math.min(pv.r, height / 2)
                color: pv.pal.bar
                Rectangle {
                    y: pv.atBottom ? parent.height - height : 0
                    width: parent.width
                    height: parent.radius
                    color: parent.color
                }
            }

            Row {
                id: miniChips
                anchors.verticalCenter: parent.verticalCenter
                x: pv.notch ? Math.round((parent.width - width) / 2) : pv.ls.barStyle === "islands" ? 6 : 4
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
                            : pv.mod === "outline" ? "transparent" : pv.pal.surface
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
            border.width: pv.bevelled ? 0 : pv.bw
            border.color: pv.pal.border

            Bevel {
                visible: pv.bevelled
                anchors.fill: parent
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
                raised: false
                light: pv.pal.surface
                dark: pv.pal.base
                thickness: pv.bw
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
                        text: pv.look.heading.upper ? "SOUND" : "Sound"
                        color: pv.look.heading.accent ? pv.accent : pv.pal.bright
                        font.family: Fonts.resolve(pv.ls.fontFamily)
                        font.pixelSize: Theme.fs(10)
                        font.bold: pv.look.heading.bold
                        font.letterSpacing: pv.look.heading.spacing / 2
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
                        color: pv.look.meterAccent ? pv.accent : pv.pal.text
                    }
                }
            }
        }
    }

    Item {
        id: carousel
        width: parent.width
        height: lookStrip.height + Theme.spaceL + dots.height

        readonly property int cardWidth: Theme.fit(210)

        ListView {
            id: lookStrip
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: prevChip.width + Theme.spaceS
            anchors.rightMargin: nextChip.width + Theme.spaceS
            height: Theme.fit(200)
            orientation: ListView.Horizontal
            spacing: Theme.spaceL
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            snapMode: ListView.SnapToItem
            highlightMoveDuration: Theme.durSlow
            model: LookStore.order
            // open on the current look
            Component.onCompleted: positionViewAtIndex(Math.max(0, LookStore.order.indexOf(Settings.look)), ListView.Center)

            function page(d) {
                var i = Math.max(0, Math.min(count - 1, indexAt(contentX + 1, 1) + d))
                currentIndex = i
                positionViewAtIndex(i, ListView.Beginning)
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
                    lookStrip.contentX = Math.max(0, Math.min(lookStrip.contentWidth - lookStrip.width,
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
                    height: Math.round(width * 0.58)
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

                // Remove, in the preview's corner. First click arms, second
                // deletes the look from looks.json -- there's no undo short
                // of git. Its own ground, so it reads over any preview.
                Rectangle {
                    id: removeBox
                    property bool armed: false
                    visible: LookStore.removable(card.modelData)
                             && (cardMouse.containsMouse || removeHover.hovered || armed)
                    anchors.right: preview.right
                    anchors.top: preview.top
                    anchors.margins: Theme.spaceXs
                    width: removeChip.width
                    height: removeChip.height
                    radius: Theme.radiusInner
                    color: Theme.surface

                    HoverHandler { id: removeHover }
                    Timer { id: removeDisarm; interval: 3000; onTriggered: removeBox.armed = false }

                    FlyoutChip {
                        id: removeChip
                        glyph: !removeBox.armed
                        text: removeBox.armed ? "Remove" : "󰅖"
                        selected: removeBox.armed
                        onClicked: {
                            if (!removeBox.armed) { removeBox.armed = true; removeDisarm.restart(); return }
                            removeBox.armed = false
                            removeDisarm.stop()
                            Settings.removeLook(card.modelData, (ok, msg) => page.say(msg, !ok))
                        }
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
                        onClicked: lookStrip.positionViewAtIndex(parent.index, ListView.Contain)
                    }
                }
            }
        }
    }

    SettingsField {
        label: "Modules"
        hint: "How the bar's chips are drawn"
        Choice { key: "moduleStyle" }
    }

    SettingsField {
        label: "Bar"
        hint: "Edge to edge, floating, an island per group, or no bar at all"
        Choice { key: "barStyle" }
    }

    SettingsField {
        label: "Workspaces"
        hint: "How the workspace indicator marks each one"
        Choices { key: "workspaceStyle" }
    }

    SettingsField {
        label: "Clock"
        hint: "What the clock chip shows"
        Choices { key: "clockStyle" }
    }

    SettingsField {
        label: "Frames"
        hint: "Double draws a second stroke inside every panel and bar module"
        Choices { key: "frameStyle" }
    }

    Stepper { label: "Stroke width"; hint: "Every frame, chip and divider the shell draws"; key: "borderWidth"; suffix: "px" }

    SettingsField {
        label: "Density"
        hint: "Space between and inside rows, panels and windows"
        Choices { key: "density" }
    }

    // Case as a pair, the rest as chips that toggle -- they're independent
    SettingsField {
        label: "Headings"
        hint: "Section titles in flyouts, windows and here"

        Row {
            anchors.right: parent.right
            spacing: Theme.spaceS

            FlyoutSegmented {
                fill: false
                model: [{ value: true, text: "CAPS" }, { value: false, text: "Title" }]
                current: Settings.headingUpper
                onPicked: v => Settings.set("headingUpper", v)
            }
            FlyoutChip {
                text: "Bold"
                selected: Settings.headingBold
                onClicked: Settings.set("headingBold", !Settings.headingBold)
            }
            FlyoutChip {
                text: "Rule"
                selected: Settings.headingRule
                onClicked: Settings.set("headingRule", !Settings.headingRule)
            }
            FlyoutChip {
                text: "Accent"
                enabled: Theme.hasAccent
                selected: Settings.headingAccent && Theme.hasAccent
                onClicked: Settings.set("headingAccent", !Settings.headingAccent)
            }
        }
    }

    // The box shows the font in use, set in itself, and the list sets every
    // installed choice in its own font.
    SettingsField {
        label: "Font"
        hint: Theme.fontText !== Settings.fontFamily
            ? page.label(Settings.fontFamily) + " isn't available, so " + page.label(Theme.fontText) + " stands in"
            : "Monospace only. Text and icons alike, across the shell, launcher and notifications"

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
        hint: Fonts.pending.map(f => page.label(f)).join(", ") + " -- installed since the shell started, and usable after a restart"

        FlyoutChip {
            anchors.right: parent.right
            text: "Restart shell"
            onClicked: Fonts.restartShell()
        }
    }

    SettingsField {
        label: "Reset look"
        hint: Settings.lookPristine ? "Everything here and under Bar is as the look was designed"
            : "Frames, density, font, headings, accent, corners and the bar back to " + page.label(Settings.look) + "'s own"

        FlyoutChip {
            anchors.right: parent.right
            text: "Reset"
            enabled: !Settings.lookPristine
            onClicked: {
                Settings.resetLook()
                page.say(page.label(Settings.look) + " look restored", false)
            }
        }
    }

    // --- wallpaper -----------------------------------------------------------

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
        label: "At login"
        hint: Settings.wallpaperShuffle ? "A different wallpaper every login" : "The one showing now, until you pick another"

        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            model: [{ value: true, text: "Random" }, { value: false, text: "Static" }]
            current: Settings.wallpaperShuffle
            onPicked: v => Settings.setWallpaperShuffle(v)
        }
    }

    SettingsField {
        label: "Change every"
        hint: Settings.wallpaperInterval > 0 ? "A random wallpaper on this interval, counted from the last change"
            : "The wallpaper stays until you pick another"

        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            model: [{ value: 0, text: "Never" }, { value: 15, text: "15 min" }, { value: 30, text: "30 min" },
                    { value: 60, text: "1 hour" }, { value: 180, text: "3 hours" }]
            current: Settings.wallpaperInterval
            onPicked: v => Settings.set("wallpaperInterval", v)
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
        font.pixelSize: Theme.fontBody
    }

    // --- colours -------------------------------------------------------------

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "COLOURS" }

    SettingsField {
        label: "Palette"
        hint: "Grayscale, or tones taken from the wallpaper. Wofi and notifications follow."
        Choices { key: "colourMode" }
    }

    SettingsField {
        label: "Intensity"
        hint: Settings.colourMode !== "wallpaper" ? "Wallpaper palette only"
            : Wallpaper.generating ? "Generating palette…"
            : "How much of the wallpaper's colour comes through"
        Choices { key: "colourScheme"; live: Settings.colourMode === "wallpaper" }
    }

    SettingsField {
        label: "Shade"
        hint: Settings.colourMode !== "wallpaper" ? "Wallpaper palette only -- a look sets its own"
            : "Dark or light grounds from the wallpaper. GTK and Qt apps follow"
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
                    font.pixelSize: Theme.fontSmall
                }
            }
        }
    }

    // Every look's accent as a swatch, and None. The wallpaper palette
    // brings its own, so the picker rests while that's on.
    SettingsField {
        label: "Accent"
        hint: Settings.colourMode === "wallpaper" ? "The wallpaper palette's own tone is used instead"
            : "Selection, focus and the current item"

        Row {
            anchors.right: parent.right
            spacing: Theme.spaceS
            enabled: Settings.colourMode !== "wallpaper"
            opacity: enabled ? 1 : 0.4

            Repeater {
                model: Settings.accents

                Rectangle {
                    id: swatch
                    required property string modelData
                    readonly property bool current: Settings.accent === modelData
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.chipHeight
                    height: Theme.chipHeight
                    radius: Theme.radiusSmall
                    color: modelData
                    border.width: current ? 2 : swatchMouse.containsMouse ? Theme.borderWidth : 0
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

            FlyoutChip {
                text: "None"
                selected: Settings.accent === ""
                onClicked: Settings.set("accent", "")
            }
        }
    }

    Stepper { label: "Panel opacity"; hint: "Flyouts, the shell's windows, wofi and notifications. Below 100% the blur behind shows through"; key: "panelOpacity"; step: 5; suffix: "%" }
    Stepper { label: "Overlay dimming"; hint: "How dark the desktop goes behind full-screen overlays"; key: "scrim"; step: 5; suffix: "%" }

    // --- bar -----------------------------------------------------------------

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "BAR" }

    SettingsField {
        label: "Position"
        hint: "Flyouts open from whichever edge it's on"

        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            model: [{ value: "top", text: "Top" }, { value: "bottom", text: "Bottom" }]
            current: Settings.barPosition
            onPicked: v => Settings.set("barPosition", v)
        }
    }

    SettingsField {
        label: "Clock island"
        hint: !Settings.widgetVisible("clock") ? "Needs the clock on the bar -- toasts show until then"
            : Settings.clockIsland ? "Volume, brightness, layout and notifications show in the clock for a moment"
            : "Those show as separate toasts under the bar"

        Switch {
            anchors.right: parent.right
            checked: Settings.clockIsland
            onToggled: Settings.setClockIsland(!Settings.clockIsland)
        }
    }

    Stepper { label: "Height"; key: "barHeight"; suffix: "px" }
    Stepper { label: "Module gap"; hint: "Space between modules"; key: "moduleGap"; suffix: "px" }
    Stepper { label: "Corner radius"; hint: "Modules, flyouts, windows of the shell, wofi and notifications"; key: "radius"; suffix: "px" }
    Stepper { label: "Opacity"; hint: "The bar's background only"; key: "barOpacity"; step: 5; suffix: "%" }

    // --- text & motion -------------------------------------------------------

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "TEXT & MOTION" }

    Stepper { label: "Font size"; hint: "Body text size for the shell, launcher and notifications. Headings, captions and rows scale with it."; key: "fontSize"; suffix: "px" }
    Stepper { label: "Bar text size"; hint: "The bar's labels and icons, on their own. The bar's height caps how large they get."; key: "barFontSize"; suffix: "px" }


    SettingsField {
        label: "Animations"
        hint: "The shell's and Hyprland's alike"
        Choices { key: "animSpeed" }
    }

    // --- system --------------------------------------------------------------
    // Preferences for the apps outside the shell. Not part of a look, and
    // kept by Reset and Set as default, like the wallpaper.

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "SYSTEM" }

    // GTK/Qt apps' own font -- independent of the shell's Font under Look. Every
    // choice here is always installed (see Looks.systemFonts), so there's no
    // pending/restart state to show like the shell font has.
    SettingsField {
        label: "System font"
        hint: "GTK and Qt apps outside the shell -- terminal, file manager, and the rest. Doesn't change the bar, launcher or notifications"

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
        hint: "GTK apps change now, Qt apps when next opened, and the shell's own app icons at the next login"

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
        hint: "Changes on the desktop now, and in apps when they're next opened"

        SettingsDropdown {
            anchors.right: parent.right
            model: DesktopThemes.cursors
            current: Settings.cursorTheme
            labelFor: v => DesktopThemes.label(v)
            onPicked: v => Settings.set("cursorTheme", v)
        }
    }

    Stepper { label: "Cursor size"; key: "cursorSize"; step: 4; suffix: "px" }

    // --- windows -------------------------------------------------------------

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "WINDOWS" }

    HyprInt { label: "Gaps between windows"; path: ["general"]; key: "gaps_in"; max: 20 }
    HyprInt { label: "Gaps at screen edges"; path: ["general"]; key: "gaps_out"; max: 40 }
    HyprInt { label: "Border width"; note: "0 hides the border"; path: ["general"]; key: "border_size"; max: 6 }
    HyprInt { label: "Corner radius"; path: ["decoration"]; key: "rounding"; max: 20 }
    HyprPercent { label: "Focused opacity"; path: ["decoration"]; key: "active_opacity" }
    HyprPercent { label: "Unfocused opacity"; path: ["decoration"]; key: "inactive_opacity" }
    HyprToggle { label: "Dim unfocused"; path: ["decoration"]; key: "dim_inactive" }
    HyprToggle { label: "Blur"; note: "Behind translucent windows and layers"; path: ["decoration", "blur"]; key: "enabled" }
    HyprToggle { label: "Shadows"; path: ["decoration", "shadow"]; key: "enabled" }

    // --- default --------------------------------------------------------------
    // "Default" is what Reset returns to: stock until something is saved over
    // it. Covers the look and everything under Look, Colours, Bar and Text &
    // Motion; the wallpaper and the System and Windows sections are kept
    // either way.

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "DEFAULT" }

    SettingsField {
        id: saveField
        // first click arms, second saves -- overwriting the old default
        // can't be undone
        property bool armed: false
        label: "Set as default"
        hint: armed ? "Click again to replace the saved default"
            : Settings.isDefault ? "This is the default"
            : "Make everything as it is now what Reset returns to"

        Timer { id: saveDisarm; interval: 3000; onTriggered: saveField.armed = false }

        FlyoutChip {
            anchors.right: parent.right
            text: saveField.armed ? "Confirm" : "Save"
            selected: saveField.armed
            enabled: !Settings.isDefault
            onClicked: {
                if (!saveField.armed) { saveField.armed = true; saveDisarm.restart(); return }
                saveField.armed = false
                saveDisarm.stop()
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
            : "No saved default -- stock is the default"

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

    // --- windows: reading and writing hyprland.lua ---------------------------

    // { "general": {key: {editable, value}}, "decoration.blur": ... }, a
    // table being null when the file doesn't have it
    property var conf: ({})
    readonly property var tablePaths: [["general"], ["decoration"], ["decoration", "blur"], ["decoration", "shadow"]]

    // Hyprland's own defaults, for keys the file leaves out
    readonly property var hyprDefaults: ({
        "general.gaps_in": 5, "general.gaps_out": 20, "general.border_size": 1,
        "decoration.rounding": 0, "decoration.active_opacity": 1, "decoration.inactive_opacity": 1,
        "decoration.dim_inactive": false,
        "decoration.blur.enabled": true, "decoration.shadow.enabled": true,
    })

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
            suffix: "px"
            valueWidth: 56
            onStepped: d => page.setHypr(hi.path, hi.key,
                Math.max(hi.min, Math.min(hi.max, value + d)), hi.label + " " + (value + d) + "px")
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
