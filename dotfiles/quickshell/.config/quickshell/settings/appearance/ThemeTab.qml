// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/ThemeTab.qml
//
// The Theme page: what restyles all of the chrome at once, in four
// sections: Look (the look, the style and space), Colour (palette, accent
// and status), Shape (with the finish) and Headings. Switches and short
// rows go two to a line. The shell's font is on Fonts & Icons.

import Quickshell
import QtQuick
import "../../services/Styles.js" as Styles
import "../../services/Looks.js" as Looks
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    id: styleTab
    tabId: "theme"

    FlyoutHeading { text: "LOOK" }

    Tiles {
        key: "look"; label: "Look"; art: lookArt; columns: 4
        hint: Looks.looks[Settings.look] ? Looks.looks[Settings.look].description : ""
    }

    SettingsSubhead { caption: "STYLE" }

    Tiles { key: "style"; label: "Style"; hint: Styles.get(Settings.style).hint; art: styleArt; columns: 5 }

    SettingsSubhead { caption: "SPACE" }

    // a preset for the three dials: Spacing and Row height here, Height on
    // the Bar tab; the dials only show on Custom (or once one leaves every
    // preset)
    property bool customSpace: Settings.density === "custom"

    SettingsField {
        label: "Density"
        hint: styleTab.customSpace ? "Your own: set by the dials"
            : ({ compact: "Tighter gaps and shorter rows", normal: "The shell as designed",
                 roomy: "Wider gaps and taller rows" })[Settings.density] || ""
        Choices {
            id: densityChoices
            key: "density"
            value: styleTab.customSpace ? "custom" : Settings.density
        }
        Connections {
            target: densityChoices
            function onPicked(v) { styleTab.customSpace = v === "custom" }
        }
    }

    Stepper { visible: styleTab.customSpace || page.highlight === "Spacing"; label: "Spacing"; hint: "Every gap and padding"; key: "spacing"; step: 5; suffix: "%" }

    Stepper { visible: styleTab.customSpace || page.highlight === "Row height"; label: "Row height"; hint: "Lists, fields and chips"; key: "rowScale"; step: 5; suffix: "%" }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "SHAPE" }

    Stepper {
        label: "Roundness"; key: "radius"; suffix: "px"
        enabled: !Styles.get(Settings.style).square
        hint: !enabled ? Styles.get(Settings.style).name + " keeps every corner square"
            : "Chips, panels, the bar and every window"
    }

    Stepper { label: "See-through"; hint: Theme.glass ? "The bar and panels; Glass adds more" : "The bar and every panel"; key: "seeThrough"; step: 5; suffix: "%" }

    SettingsSubhead { caption: "FINISH" }

    // the shared switches its options don't already stand for
    readonly property var optionKeys: Styles.get(Settings.style).options.map(o => o.key || "")
    // a row in a two-column grid, and its label's share
    readonly property real half: (width - Theme.spaceXl * 2) / 2
    readonly property real halfLabel: half - Theme.switchWidth - Theme.spaceL

    // the style's own options first, then the shared switches, two to a line
    Grid {
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl * 2

        // the style's own three options first
        Repeater {
            model: Styles.get(Settings.style).options
            StyleOption { required property var modelData; option: modelData; width: styleTab.half; labelWidth: styleTab.halfLabel }
        }

        FinishSwitch {
            width: styleTab.half; labelWidth: styleTab.halfLabel
            visible: styleTab.optionKeys.indexOf("shadows") === -1
            label: "Shadows"; key: "shadows"
            live: Styles.get(Settings.style).shadow !== "none"
            hint: live ? "The style's " + Styles.get(Settings.style).shadow + " shadow, windows too" : "This style has none"
        }

        FinishSwitch { width: styleTab.half; labelWidth: styleTab.halfLabel; visible: styleTab.optionKeys.indexOf("gradient") === -1; label: "Shaded grounds"; key: "gradient"; hint: "A faint shade down the bar and panels" }

        FinishSwitch {
            width: styleTab.half; labelWidth: styleTab.halfLabel
            visible: styleTab.optionKeys.indexOf("heavyLines") === -1
            label: "Heavy lines"; key: "heavyLines"
            live: Styles.get(Settings.style).lines
            hint: live ? "Every stroke 2px, windows' borders too" : "This style has no lines"
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "COLOUR" }

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

    // The palette in use, role by role, darkest to brightest. In grayscale
    // a swatch picks that role for the field under the strip; a role set
    // apart from the look's own carries a dot.
    property string paletteRole: "base"
    readonly property var roleHints: ({
        base: "The deepest ground: meter tracks, fields", bar: "The bar's ground",
        panel: "Flyouts' and windows' ground", surface: "Cards, chips, a lit tab",
        overlay: "Hover fills, the selected row", border: "Strokes and rules",
        muted: "Inactive marks, the channel's outer line", subtext: "Hints and secondary text",
        text: "Body text", bright: "Headings, values, emphasis",
    })
    function roleKey(r) { return "palette" + r.charAt(0).toUpperCase() + r.slice(1) }

    Row {
        id: swatches
        width: parent.width
        spacing: Theme.spaceS

        readonly property var roles: ["base", "bar", "panel", "surface", "overlay",
                                      "border", "muted", "subtext", "text", "bright"]
        readonly property bool editable: Settings.colourMode !== "wallpaper"

        Repeater {
            model: swatches.roles

            Column {
                id: sw
                required property string modelData
                readonly property bool picked: swatches.editable && styleTab.paletteRole === modelData
                width: (swatches.width - swatches.spacing * (swatches.roles.length - 1)) / swatches.roles.length
                spacing: Theme.sp(3)

                Rectangle {
                    width: parent.width
                    height: Theme.fieldHeight
                    radius: Theme.radiusInner
                    color: Theme[sw.modelData]
                    border.width: sw.picked ? 2 : Theme.borderWidth
                    border.color: sw.picked ? Theme.accent : swMouse.containsMouse && swatches.editable ? Theme.strokeHover : Theme.stroke

                    Rectangle {
                        visible: (Settings[styleTab.roleKey(sw.modelData)] || "") !== ""
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spaceXs + 1
                        width: Theme.fs(7)
                        height: width
                        radius: Theme.pill(width)
                        color: Theme.accent
                        border.width: 1
                        border.color: Theme.base
                    }

                    MouseArea {
                        id: swMouse
                        anchors.fill: parent
                        enabled: swatches.editable
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: styleTab.paletteRole = sw.modelData
                    }
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: sw.modelData
                    color: sw.picked ? Theme.textStrong : Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontSmall
                }
            }
        }
    }

    // the role picked above, by hex; "" is the look's own
    HexColour {
        visible: swatches.editable
        label: styleTab.paletteRole.charAt(0).toUpperCase() + styleTab.paletteRole.slice(1)
        key: styleTab.roleKey(styleTab.paletteRole)
        fallback: Theme.look.palette[styleTab.paletteRole]
        hint: styleTab.roleHints[styleTab.paletteRole]
    }

    SettingsSubhead { caption: "ACCENT" }

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
            anchors.right: parent.right
            spacing: accentField.gap
            enabled: Settings.colourMode !== "wallpaper"
            opacity: enabled ? 1 : 0.4
            width: Math.min(parent.width, (Settings.accents.length + 1) * (accentField.swatch + accentField.gap)
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

            // any colour: opens the picker below
            Rectangle {
                width: accentField.swatch
                height: accentField.swatch
                radius: Theme.radiusSmall
                border.width: accentField.picking ? 2 : customMouse.containsMouse ? Theme.borderWidth : 0
                border.color: Theme.textStrong
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#e5484d" }
                    GradientStop { position: 0.25; color: "#f5b70a" }
                    GradientStop { position: 0.5; color: "#30a46c" }
                    GradientStop { position: 0.75; color: "#0091ff" }
                    GradientStop { position: 1.0; color: "#8e4ec6" }
                }

                MouseArea {
                    id: customMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: accentField.picking = !accentField.picking
                }
            }

            FlyoutChip {
                id: noneChip
                text: "None"
                selected: Settings.accent === ""
                onClicked: Settings.set("accent", "")
            }
        }

        property bool picking: false
    }

    // The picker: the accent's hue and lightness, its saturation kept (with
    // a floor, so a grey accent still has a hue to move through)
    SettingsField {
        id: hueField
        visible: accentField.picking && Settings.colourMode !== "wallpaper"
        label: "Hue"
        readonly property color base: Settings.accent !== "" ? Settings.accent : "#5555c8"
        function setHsl(h, l) {
            Settings.set("accent", String(Qt.hsla(h, Math.max(0.3, base.hslSaturation), l, 1)))
        }

        Slider {
            anchors.right: parent.right
            width: Theme.fit(260)
            value: Math.max(0, hueField.base.hslHue) * 100
            onMoved: v => hueField.setHsl(v / 100, hueField.base.hslLightness)
        }
    }

    SettingsField {
        visible: hueField.visible
        label: "Lightness"

        Slider {
            anchors.right: parent.right
            width: Theme.fit(260)
            value: hueField.base.hslLightness * 100
            onMoved: v => hueField.setHsl(Math.max(0, hueField.base.hslHue), Math.max(0.15, Math.min(0.85, v / 100)))
        }
    }

    HexColour { label: "Custom accent"; key: "accent"; fallback: Theme.accent }

    SettingsField {
        label: "Text on the accent"
        hint: Settings.accentText === "auto" ? "White, or dark when the accent is too bright"
            : "On tabs, chosen segments and lit chips"
        Choices { key: "accentText" }
    }

    SettingsField {
        label: "Level colour"
        hint: "Volume, brightness and battery fills"
        Choices { key: "levelColour" }
    }

    SettingsSubhead { caption: "STATUS" }

    // Good and Alert as two swatches on one row; a click opens that one's
    // hex field under it (as does a search for it)
    property string openStatus: ""

    SettingsField {
        label: "Status"

        Row {
            anchors.right: parent.right
            spacing: Theme.spaceM

            Repeater {
                model: [{ key: "colourGood", name: "Good", colour: Settings.colourGood || Theme.look.good },
                        { key: "colourAlert", name: "Alert", colour: Settings.colourAlert || Theme.look.alert }]

                Row {
                    required property var modelData
                    spacing: Theme.spaceS

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        color: Theme.subtext
                        font.family: Theme.fontText
                        font.weight: Theme.weightBody
                        font.pixelSize: Theme.fontSmall
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.fs(22)
                        height: width
                        radius: Theme.radiusSmall
                        color: modelData.colour
                        border.width: styleTab.openStatus === modelData.key ? Theme.borderWidth * 2 : Theme.borderWidth
                        border.color: styleTab.openStatus === modelData.key ? Theme.textStrong : Theme.stroke

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: styleTab.openStatus = styleTab.openStatus === modelData.key ? "" : modelData.key
                        }
                    }
                }
            }
        }
    }

    HexColour {
        visible: styleTab.openStatus === "colourGood" || page.highlight === "Good"
        label: "Good"; key: "colourGood"; fallback: Theme.look.good; grayscaleOnly: false; hint: "Charging, connected, done; Enter to apply"
    }

    HexColour {
        visible: styleTab.openStatus === "colourAlert" || page.highlight === "Alert"
        label: "Alert"; key: "colourAlert"; fallback: Theme.look.alert; grayscaleOnly: false; hint: "Critical battery, errors, armed buttons"
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "HEADINGS" }


    // The mark before every heading: a preset, a shape, none, or up to
    // four characters of your own
    readonly property var markNames: ({
        "//": "//  Slashes", "::": "::  Colons", "»": "»  Guillemet", "❯": "❯  Prompt",
        ">_": ">_  Terminal", "├─": "├─  Branch", "▸": "▸  Arrow", "•": "•  Dot",
        "shape-bar": "Accent bar", "shape-brackets": "[ Brackets ]", "shape-tab": "Rule tab",
        "shape-tag": "Filled tag", "": "None", "custom": "Custom…"
    })
    readonly property var markPresets: Object.keys(markNames).filter(k => k !== "custom")
    property bool customMark: markPresets.indexOf(Settings.headingMark) === -1

    SettingsField {
        label: "Mark"
        lookKey: "headingMark"
        hint: "Drawn before every heading, in its colour"

        Row {
            anchors.right: parent.right
            spacing: Theme.spaceM

            SettingsDropdown {
                width: Theme.fit(160)
                model: Object.keys(styleTab.markNames)
                maxRows: model.length
                labelFor: v => styleTab.markNames[v]
                current: styleTab.customMark ? "custom" : Settings.headingMark
                onPicked: v => {
                    styleTab.customMark = v === "custom"
                    if (v !== "custom") Settings.set("headingMark", v)
                }
            }
            // the mark's colour
            Choices { key: "headingMarkColour"; anchors.right: undefined }
        }
    }

    SettingsField {
        visible: styleTab.customMark
        label: "Your mark"
        hint: "Up to four characters, Enter to apply"
        FlyoutInput {
            anchors.right: parent.right
            width: Theme.fit(120)
            echoPassword: false
            placeholder: "»"
            text: styleTab.markPresets.indexOf(Settings.headingMark) === -1 ? Settings.headingMark : ""
            onAccepted: {
                Settings.set("headingMark", text)
                page.say("Heading mark set", false)
            }
        }
    }

    // Case, the rule and the size, two to a line

    Grid {
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl * 2

        SettingsField {
            width: styleTab.half; labelWidth: styleTab.half / 2
            label: "Case"
            lookKey: "headingUpper"
            FlyoutSegmented {
                anchors.right: parent.right
                fill: false
                model: [{ value: true, text: "VOLUME" }, { value: false, text: "Volume" }]
                current: Settings.headingUpper
                onPicked: v => Settings.set("headingUpper", v)
            }
        }

        FinishSwitch { width: styleTab.half; labelWidth: styleTab.halfLabel; label: "Heading rule"; key: "headingRule"; hint: "A line out to the panel's edge" }

        SettingsField {
            width: styleTab.half; labelWidth: styleTab.half / 2
            label: "Heading size"
            hint: "Relative to body text"
            Choices { key: "headingSize" }
        }
    }

    // A look in its own colours: the bar along the top, a line of text and
    // a hint, and its accent as a pill
    Component {
        id: lookArt
        Rectangle {
            id: la
            readonly property var look: Looks.looks[parent ? parent.value : ""] || Looks.looks[Looks.fallback]
            readonly property var p: look.palette
            readonly property color mark: look.accent || p.bright
            width: Theme.fs(64)
            height: Theme.fs(34)
            radius: Math.min(Theme.radius, 5)
            color: p.panel
            border.color: p.border
            clip: true

            Rectangle {
                width: parent.width; height: Theme.fs(7)
                color: p.bar
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: p.border }
            }
            Column {
                x: Theme.fs(6); y: Theme.fs(12)
                spacing: Theme.fs(4)
                Rectangle { width: Theme.fs(30); height: Theme.fs(3); radius: Theme.pill(height); color: la.p.text }
                Rectangle { width: Theme.fs(20); height: Theme.fs(3); radius: Theme.pill(height); color: la.p.subtext }
            }
            Rectangle {
                anchors { right: parent.right; bottom: parent.bottom; margins: Theme.fs(5) }
                width: Theme.fs(14); height: Theme.fs(7); radius: Theme.pill(height)
                color: la.mark
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
            // Flat: the taskbar the slots sit in
            Rectangle {
                visible: ya.v === "flat"
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: ya.ch + 8
                color: Theme.bar
                Rectangle { width: parent.width; height: 1; color: Theme.border }
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
                            visible: ya.v !== "channel" && ya.v !== "flat"
                            radius: ya.r
                            color: ya.v === "glass" ? (chip.lit ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.7) : Qt.rgba(1, 1, 1, 0.08))
                                : ya.v === "double" ? (chip.lit ? Theme.overlay : Theme.panel)
                                : chip.lit ? Theme.accent : Theme.surface
                            border.width: ya.v === "double" || ya.v === "glass" ? 1 : 0
                            border.color: ya.v === "glass" ? Qt.rgba(1, 1, 1, 0.2)
                                : chip.lit ? Theme.accent : Theme.border

                            Rectangle {
                                visible: ya.v === "double"
                                anchors.fill: parent; anchors.margins: 2
                                radius: Math.max(0, parent.radius - 2)
                                color: "transparent"
                                border.width: 1; border.color: chip.lit ? Theme.muted : Theme.surface
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
                        // Flat's open slot: a fill the taskbar's height, an
                        // accent rule on its bottom edge
                        Rectangle {
                            visible: ya.v === "flat" && chip.lit
                            y: -4
                            width: parent.width; height: ya.ch + 8
                            color: Theme.overlay
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: Theme.accent }
                        }
                        // the icon
                        Rectangle {
                            anchors.centerIn: parent
                            width: Theme.fs(8); height: Theme.fs(5)
                            radius: 1
                            color: chip.lit && (ya.v === "solid" || ya.v === "glass") ? "#ffffff" : Theme.text
                        }
                    }
                }
            }
        }
    }
}
