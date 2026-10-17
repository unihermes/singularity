// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/ThemeTab.qml
//
// The Appearance page's Theme tab: what restyles all of the chrome at
// once -- the style and its shape, the colours, spacing, text and the
// finishing touches.

import Quickshell
import QtQuick
import "../../services/Styles.js" as Styles
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    id: styleTab
    tabId: "theme"

    FlyoutHeading { text: "STYLE" }

    Tiles { key: "style"; label: "Style"; hint: Styles.get(Settings.style).hint; art: styleArt; columns: 5 }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "SHAPE" }

    Stepper {
        label: "Roundness"; key: "radius"; suffix: "px"
        enabled: !Styles.get(Settings.style).square
        hint: !enabled ? Styles.get(Settings.style).name + " keeps every corner square"
            : "Chips, panels, the bar and every window"
    }

    Stepper { label: "See-through"; hint: Theme.glass ? "The bar and panels; Glass adds more" : "The bar and every panel"; key: "seeThrough"; step: 5; suffix: "%" }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "FINISH" }

    // the style's own three options first
    Repeater {
        model: Styles.get(Settings.style).options
        StyleOption { required property var modelData; option: modelData }
    }

    // then the shared switches its options don't already stand for
    readonly property var optionKeys: Styles.get(Settings.style).options.map(o => o.key || "")

    FinishSwitch {
        visible: styleTab.optionKeys.indexOf("shadows") === -1
        label: "Shadows"; key: "shadows"
        live: Styles.get(Settings.style).shadow !== "none"
        hint: live ? "The style's " + Styles.get(Settings.style).shadow + " shadow, windows too" : "This style has none"
    }

    FinishSwitch { visible: styleTab.optionKeys.indexOf("gradient") === -1; label: "Shaded grounds"; key: "gradient"; hint: "A faint shade down the bar and panels" }

    FinishSwitch {
        visible: styleTab.optionKeys.indexOf("heavyLines") === -1
        label: "Heavy lines"; key: "heavyLines"
        live: Styles.get(Settings.style).lines
        hint: live ? "Every stroke 2px, windows' borders too" : "This style has no lines"
    }


    Item { width: 1; height: Theme.spaceM }
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
                        radius: width / 2
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

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "ACCENT" }

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
                id: customSwatch
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
        hint: "Around the colour wheel"
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
        hint: "From deep to pale"

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

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "STATUS" }

    HexColour { label: "Good"; key: "colourGood"; fallback: Theme.look.good; grayscaleOnly: false; hint: "Charging, connected, done; Enter to apply" }

    HexColour { label: "Alert"; key: "colourAlert"; fallback: Theme.look.alert; grayscaleOnly: false; hint: "Critical battery, errors, armed buttons" }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "SPACE" }

    // a preset for the three dials: Spacing and Row height here, Height on
    // the Bar tab; Custom shows once a dial leaves every preset
    SettingsField {
        label: "Density"
        hint: Settings.density === "custom" ? "Your own: set by the dials" : "Presets for Spacing, Row height, bar height"
        Choices {
            key: "density"
            model: Settings.density === "custom" ? Settings.choices.density : Settings.choices.density.slice(0, 3)
        }
    }

    Stepper { label: "Spacing"; hint: "Every gap and padding"; key: "spacing"; step: 5; suffix: "%" }

    Stepper { label: "Row height"; hint: "Lists, fields and chips; text never clips"; key: "rowScale"; step: 5; suffix: "%" }

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
            onClicked: Session.restartShell()
        }
    }

    Stepper { label: "Font size"; hint: "Everything else scales with it"; key: "fontSize"; suffix: "px" }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "HEADINGS" }

    // The mark before every heading: a preset, none, or up to four
    // characters of your own
    readonly property var markPresets: ["//", "▸", "•", ""]
    property bool customMark: markPresets.indexOf(Settings.headingMark) === -1

    SettingsField {
        label: "Mark"
        lookKey: "headingMark"
        hint: "Drawn before every heading"
        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            model: [{ value: "//", text: "//" }, { value: "▸", text: "▸" }, { value: "•", text: "•" },
                    { value: "", text: "None" }, { value: "custom", text: "Custom" }]
            current: styleTab.customMark ? "custom" : Settings.headingMark
            onPicked: v => {
                styleTab.customMark = v === "custom"
                if (v !== "custom") Settings.set("headingMark", v)
            }
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

    SettingsField {
        label: "Mark colour"
        hint: "The accent, lightened, or a grey"
        Choices { key: "headingMarkColour" }
    }

    SettingsField {
        label: "Case"
        lookKey: "headingUpper"
        hint: "Capitals, or as a title"
        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            model: [{ value: true, text: "VOLUME" }, { value: false, text: "Volume" }]
            current: Settings.headingUpper
            onPicked: v => Settings.set("headingUpper", v)
        }
    }

    FinishSwitch { label: "Heading rule"; key: "headingRule"; hint: "A line out to the panel's edge" }

    SettingsField {
        label: "Heading size"
        hint: "Against body text"
        Choices { key: "headingSize" }
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
                            id: face
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
