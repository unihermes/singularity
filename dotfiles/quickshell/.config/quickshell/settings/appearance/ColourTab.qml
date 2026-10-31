// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/ColourTab.qml
//
// Appearance's Colour tab, every colour on screen: SCHEME (the look and the
// palette), ACCENT (with the status hues), WINDOW BORDERS and WALLPAPER.
// Each section's rarely changed rows fold behind its Advanced.

import Quickshell
import Quickshell.Widgets
import QtQuick
import "../../services/Looks.js" as Looks
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    id: colourTab
    tabId: "colour"

    // a row in a two-column grid, and its label's share
    readonly property real half: (width - Theme.spaceXl * 2) / 2

    FlyoutHeading { text: "SCHEME" }

    Tiles {
        key: "look"; label: "Look"; art: lookArt; columns: 4
        hint: Looks.looks[Settings.look] ? Looks.looks[Settings.look].description : ""
    }

    SettingsField {
        label: "Palette"
        hint: "Grayscale, or tones from the wallpaper"
        Choices { key: "colourMode" }
    }

    SettingsField {
        label: "Shade"
        visible: Settings.colourMode === "wallpaper"
        hint: "Dark or light grounds; apps follow"
        Choices { key: "colourVariant"; live: Settings.colourMode === "wallpaper" }
    }

    SettingsAdvanced {
        SettingsField {
            label: "Intensity"
            visible: Settings.colourMode === "wallpaper"
            hint: Wallpaper.generating ? "Generating palette…" : "How much wallpaper colour comes through"
            Choices { key: "colourScheme"; live: Settings.colourMode === "wallpaper" }
        }

        // The palette in use, role by role, darkest to brightest: a swatch
        // picks that role for the field under the strip; a role set apart
        // from the look's own carries a dot. Grayscale only.
        SettingsField {
            id: rolesField
            visible: Settings.colourMode !== "wallpaper"
            label: "Palette roles"
            hint: "Each shade of the ramp, by hex"
        }

        Row {
            id: swatches
            visible: rolesField.visible
            width: parent.width
            spacing: Theme.spaceS

            readonly property var roles: ["base", "bar", "panel", "surface", "overlay",
                                          "border", "muted", "subtext", "text", "bright"]

            Repeater {
                model: swatches.roles

                Column {
                    id: sw
                    required property string modelData
                    readonly property bool picked: colourTab.paletteRole === modelData
                    width: (swatches.width - swatches.spacing * (swatches.roles.length - 1)) / swatches.roles.length
                    spacing: Theme.sp(3)

                    Rectangle {
                        width: parent.width
                        height: Theme.fieldHeight
                        radius: Theme.radiusInner
                        color: Theme[sw.modelData]
                        border.width: sw.picked ? 2 : Theme.borderWidth
                        border.color: sw.picked ? Theme.accent : swMouse.containsMouse ? Theme.strokeHover : Theme.stroke

                        Rectangle {
                            visible: (Settings[colourTab.roleKey(sw.modelData)] || "") !== ""
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
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: colourTab.paletteRole = sw.modelData
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
            visible: rolesField.visible
            label: colourTab.paletteRole.charAt(0).toUpperCase() + colourTab.paletteRole.slice(1)
            key: colourTab.roleKey(colourTab.paletteRole)
            fallback: Theme.look.palette[colourTab.paletteRole]
            hint: colourTab.roleHints[colourTab.paletteRole]
        }
    }

    property string paletteRole: "base"
    readonly property var roleHints: ({
        base: "The deepest ground: meter tracks, fields", bar: "The bar's ground",
        panel: "Flyouts' and windows' ground", surface: "Cards, chips, a lit tab",
        overlay: "Hover fills, the selected row", border: "Strokes and rules",
        muted: "Inactive marks, the channel's outer line", subtext: "Hints and secondary text",
        text: "Body text", bright: "Headings, values, emphasis",
    })
    function roleKey(r) { return "palette" + r.charAt(0).toUpperCase() + r.slice(1) }

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

    // Good and Alert as two swatches on one row; a click opens that one's
    // hex field under it (as does a search for it)
    property string openStatus: ""

    SettingsAdvanced {
        HexColour { label: "Custom accent"; key: "accent"; fallback: Theme.accent }

        SettingsField {
            label: "Level colour"
            hint: "Volume, brightness and battery fills"
            Choices { key: "levelColour" }
        }

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
                            border.width: colourTab.openStatus === modelData.key ? Theme.borderWidth * 2 : Theme.borderWidth
                            border.color: colourTab.openStatus === modelData.key ? Theme.textStrong : Theme.stroke

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: colourTab.openStatus = colourTab.openStatus === modelData.key ? "" : modelData.key
                            }
                        }
                    }
                }
            }
        }

        HexColour {
            visible: colourTab.openStatus === "colourGood" || page.highlight === "Good"
            label: "Good"; key: "colourGood"; fallback: Theme.look.good; grayscaleOnly: false; hint: "Charging, connected, done; Enter to apply"
        }

        HexColour {
            visible: colourTab.openStatus === "colourAlert" || page.highlight === "Alert"
            label: "Alert"; key: "colourAlert"; fallback: Theme.look.alert; grayscaleOnly: false; hint: "Critical battery, errors, armed buttons"
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "WINDOW BORDERS" }

    SettingsField {
        label: "Border width"
        hint: Settings.windowBorderWidth === "style" ? "As thick as the shell's strokes" : "Every window's border"
        Choices { key: "windowBorderWidth" }
    }

    Grid {
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl * 2

        SettingsField {
            width: colourTab.half
            labelWidth: colourTab.half - focusedChoices.width - Theme.spaceL
            label: "Focused border"
            hint: "The one with focus"
            Choices { id: focusedChoices; key: "windowBorderFocused" }
        }

        SettingsField {
            width: colourTab.half
            labelWidth: colourTab.half - unfocusedChoices.width - Theme.spaceL
            label: "Unfocused border"
            hint: "Every other window"
            Choices { id: unfocusedChoices; key: "windowBorderUnfocused" }
        }
    }

    HexColour {
        visible: Settings.windowBorderFocused === "custom"
        label: "Focused colour"
        key: "windowBorderFocusedHex"
        fallback: Theme.strokeFocus
        grayscaleOnly: false
    }

    HexColour {
        visible: Settings.windowBorderUnfocused === "custom"
        label: "Unfocused colour"
        key: "windowBorderUnfocusedHex"
        fallback: Theme.border
        grayscaleOnly: false
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "WALLPAPER" }

    // the current image beside its name and the arrows
    Item {
        width: parent.width
        height: Math.max(currentThumb.height, currentField.implicitHeight)

        ClippingRectangle {
            id: currentThumb
            visible: Wallpaper.current !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: visible ? Math.round(height * 16 / 9) : 0
            height: Theme.fs(48)
            radius: Theme.radiusInner
            color: Theme.base
            border.width: 2
            border.color: Theme.accent

            Image {
                anchors.fill: parent
                source: Wallpaper.current !== "" ? "file://" + Wallpaper.current : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 240
            }
        }

        SettingsField {
            id: currentField
            anchors.verticalCenter: parent.verticalCenter
            x: currentThumb.visible ? currentThumb.width + Theme.spaceL : 0
            width: parent.width - x
            label: "Current"
            hint: Wallpaper.title !== "" ? Wallpaper.title : "No wallpaper"

            Row {
                anchors.right: parent.right
                spacing: Theme.spaceS

                FlyoutChip { glyph: true; text: "󰒮"; enabled: Wallpaper.images.length > 1; onClicked: Wallpaper.step(-1) }
                FlyoutChip { glyph: true; text: "󰒝"; enabled: Wallpaper.images.length > 1; onClicked: Wallpaper.shuffle() }
                FlyoutChip { glyph: true; text: "󰒭"; enabled: Wallpaper.images.length > 1; onClicked: Wallpaper.step(1) }
            }
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

    // every image, six to a row; click one to show it
    Flow {
        id: grid
        width: parent.width
        spacing: Theme.spaceM

        readonly property int columns: 6
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
                    sourceSize.width: 240
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

    SettingsField {
        labelWidth: parent.width - folderChip.width - Theme.spaceL
        label: "Folder"
        hint: Wallpaper.images.length + " images in wallpapers/"
        FlyoutChip {
            id: folderChip
            anchors.right: parent.right
            text: "Open folder"
            onClicked: Quickshell.execDetached(["xdg-open", Wallpaper.folder])
        }
    }

    SettingsAdvanced {
        SettingsField {
            label: "Fit"
            Choices { key: "wallpaperFill" }
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
}
