// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/ColourTab.qml
//
// Appearance's Colour tab, laid out round the palette itself (the
// "palette workshop"). SCHEME: where the colours come from, the looks as
// a carousel each with its own strip, then the palette in use as a ramp of
// labelled swatches (the ten greys, then accent, good and alert); a click
// on one opens it in the editor under the ramp (its hex, and for the
// accent the presets, Hue and Lightness), and Level colour. WINDOW
// BORDERS: what the focused and other windows take, each with the colour
// it comes to, and the width. WALLPAPER: the arrows on the heading, every
// image, New wallpaper, Fit and the folder. Nothing folds away.

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

    // the ramp's swatch open in the editor
    property string role: "accent"
    readonly property var greys: ["base", "bar", "panel", "surface", "overlay",
                                  "border", "muted", "subtext", "text", "bright"]
    readonly property var roleHints: ({
        base: "The deepest ground: meter tracks, fields", bar: "The bar's ground",
        panel: "Flyouts' and windows' ground", surface: "Cards, chips, a lit tab",
        overlay: "Hover fills, the selected row", border: "Strokes and rules",
        muted: "Inactive marks, the channel's outer line", subtext: "Hints and secondary text",
        text: "Body text", bright: "Headings, values, emphasis",
        accent: "Selection, focus, the current item",
        good: "Charging, connected, done", alert: "Critical battery, errors, armed buttons",
    })
    function roleKey(r) {
        return r === "accent" ? "accent" : r === "good" ? "colourGood" : r === "alert" ? "colourAlert"
            : "palette" + r.charAt(0).toUpperCase() + r.slice(1)
    }
    function roleName(r) { return r.charAt(0).toUpperCase() + r.slice(1) }
    // set apart from the look's own
    function changed(r) {
        return r === "accent" ? Settings.accent !== Settings.lookAccent : (Settings[roleKey(r)] || "") !== ""
    }

    // a search for one of the editor's fields opens its swatch
    Connections {
        target: page
        function onHighlightChanged() {
            var h = page.highlight
            if (h === "Good" || h === "Alert") colourTab.role = h.toLowerCase()
            else if (h === "Custom accent" || h === "Hue" || h === "Lightness") colourTab.role = "accent"
            else if (h === "Palette roles") colourTab.role = "base"
        }
    }

    FlyoutHeading { text: "SCHEME" }

    SettingsField {
        label: "Palette"
        hint: Settings.colourMode === "wallpaper" ? "Tones from the wallpaper, made again when it changes"
            : "The look's own colours, as designed"
        Choices { key: "colourMode" }
    }

    SettingsField {
        label: "Look"
        hint: (Looks.looks[Settings.look] ? Looks.looks[Settings.look].description : "")
            + (Settings.colourMode === "wallpaper" ? "; its greys rest while the wallpaper's are on" : "")
    }

    // browse the looks without expanding the page vertically
    Row {
        width: parent.width
        spacing: Theme.spaceS

        IconButton {
            icon: "󰅁"
            enabled: looks.contentX > 0
            onClicked: looks.contentX = Math.max(0, looks.contentX - looks.width / 2)
        }
        ListView {
            id: looks
            width: parent.width - 2 * (Theme.controlSize + parent.spacing)
            height: Theme.rowHeight
            orientation: ListView.Horizontal
            spacing: Theme.spaceS
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: Looks.order
            currentIndex: Looks.order.indexOf(Settings.look)
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            Component.onCompleted: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Item {
                id: lookRow
                required property string modelData
                readonly property var look: Looks.looks[modelData]
                readonly property bool current: Settings.look === modelData
                width: Math.max(Theme.fs(200), (looks.width - looks.spacing) / 2)
                height: Theme.rowHeight

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusInner
                    color: lookRow.current || lookMouse.containsMouse ? Theme.hoverFill : "transparent"
                }
                Rectangle {
                    visible: lookRow.current
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.indicatorWidth
                    height: parent.height - Theme.spaceM
                    radius: Theme.pill(width)
                    color: Theme.accent
                }
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spaceS
                    anchors.right: strip.left
                    anchors.rightMargin: Theme.spaceM
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: lookRow.look.name
                    color: Theme.textStrong
                    font.family: Theme.fontText
                    font.weight: lookRow.current ? Theme.weightStrong : Theme.weightBody
                    font.pixelSize: Theme.fontBody
                }
                // its ten greys, then its accent a little wider
                Row {
                    id: strip
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spaceS
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: Settings.colourMode === "wallpaper" ? 0.5 : 1

                    Repeater {
                        model: colourTab.greys
                        Rectangle {
                            required property string modelData
                            width: Theme.fs(10)
                            height: Theme.fs(14)
                            color: lookRow.look.palette[modelData]
                        }
                    }
                    Rectangle {
                        width: Theme.fs(16)
                        height: Theme.fs(14)
                        color: lookRow.look.accent || lookRow.look.palette.bright
                    }
                }
                MouseArea {
                    id: lookMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Settings.set("look", lookRow.modelData)
                }
            }
        }
        IconButton {
            icon: "󰅂"
            enabled: looks.contentX < looks.contentWidth - looks.width
            onClicked: looks.contentX = Math.min(looks.contentWidth - looks.width, looks.contentX + looks.width / 2)
        }
    }

    SettingsField {
        label: "Shade"
        visible: Settings.colourMode === "wallpaper"
        hint: "Dark or light grounds; apps follow"
        Choices { key: "colourVariant"; live: Settings.colourMode === "wallpaper" }
    }

    SettingsField {
        label: "Intensity"
        visible: Settings.colourMode === "wallpaper"
        hint: Wallpaper.generating ? "Generating palette…" : "How much wallpaper colour comes through"
        Choices { key: "colourScheme"; live: Settings.colourMode === "wallpaper" }
    }

    // The palette in use, darkest to brightest, then the accent and the
    // status hues set a little apart: each swatch with its name and hex, a
    // dot on one set apart from the look's own; a click opens it below.
    Row {
        id: ramp
        width: parent.width
        spacing: Theme.spaceXs
        readonly property int count: colourTab.greys.length + 3
        readonly property real gapAfterGreys: Theme.spaceM
        readonly property real cell: (width - spacing * (count - 1) - gapAfterGreys) / count

        Repeater {
            model: colourTab.greys.concat(["accent", "good", "alert"])

            Column {
                id: sw
                required property string modelData
                required property int index
                readonly property bool picked: colourTab.role === modelData
                readonly property color shade: Theme[modelData]
                width: ramp.cell + (index === colourTab.greys.length ? ramp.gapAfterGreys : 0)
                spacing: 2

                Rectangle {
                    x: sw.index === colourTab.greys.length ? ramp.gapAfterGreys : 0
                    width: ramp.cell
                    height: Theme.fs(44)
                    radius: Theme.radiusInner
                    color: sw.shade
                    border.width: sw.picked ? 2 : Theme.borderWidth
                    border.color: sw.picked ? Theme.textStrong : swMouse.containsMouse ? Theme.strokeHover : Theme.stroke

                    Rectangle {
                        visible: colourTab.changed(sw.modelData)
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
                        onClicked: colourTab.role = sw.modelData
                    }
                }
                Text {
                    x: sw.index === colourTab.greys.length ? ramp.gapAfterGreys : 0
                    width: ramp.cell
                    elide: Text.ElideRight
                    text: sw.modelData
                    color: sw.picked ? Theme.textStrong : Theme.text
                    font.family: Theme.fontText
                    font.weight: sw.picked ? Theme.weightStrong : Theme.weightBody
                    font.pixelSize: Theme.fontCaption
                }
                Text {
                    x: sw.index === colourTab.greys.length ? ramp.gapAfterGreys : 0
                    width: ramp.cell
                    elide: Text.ElideRight
                    text: String(sw.shade).slice(1)
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontEyebrow
                }
            }
        }
    }

    // the swatch opened above, by hex; "" is the look's own. A grey rests
    // while the wallpaper palette is on; the accent too, as it brings its own
    HexColour {
        label: colourTab.role === "accent" ? "Custom accent" : colourTab.roleName(colourTab.role)
        key: colourTab.roleKey(colourTab.role)
        fallback: colourTab.role === "accent" ? Theme.accent
            : colourTab.role === "good" ? Theme.look.good
            : colourTab.role === "alert" ? Theme.look.alert
            : Theme.look.palette[colourTab.role]
        grayscaleOnly: colourTab.role !== "good" && colourTab.role !== "alert"
        hint: !live ? "The wallpaper palette sets it" : colourTab.roleHints[colourTab.role]
    }

    // the accent's presets: the look's own first, a gap, the rest, None
    SettingsField {
        id: accentField
        visible: colourTab.role === "accent"
        label: "Accent"
        hint: Settings.colourMode === "wallpaper" ? "The wallpaper's own tone is used"
            : Settings.lookAccent !== "" ? "First is " + page.label(Settings.look) + "'s own" : "A preset"

        readonly property int swatch: Theme.chipHeight
        readonly property int lead: Settings.lookAccent !== "" ? Theme.spaceM : 0

        Flow {
            anchors.right: parent.right
            spacing: Theme.spaceS
            enabled: Settings.colourMode !== "wallpaper"
            opacity: enabled ? 1 : 0.4
            width: Math.min(parent.width, (Settings.accents.length + 1) * (accentField.swatch + spacing)
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

    // The picker: the accent's hue and lightness, its saturation kept (with
    // a floor, so a grey accent still has a hue to move through)
    SettingsField {
        id: hueField
        visible: colourTab.role === "accent" && Settings.colourMode !== "wallpaper"
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

    SettingsField {
        label: "Level colour"
        hint: "Volume, brightness and battery fills"
        Choices { key: "levelColour" }
    }

    // --- window borders ------------------------------------------------

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "WINDOW BORDERS" }

    // what each takes, the colour it comes to beside the choice
    component BorderSwatch: Rectangle {
        width: Theme.chipHeight
        height: Theme.chipHeight
        radius: Theme.radiusSmall
        border.width: Theme.borderWidth
        border.color: Theme.stroke
    }

    SettingsField {
        label: "Focused border"
        hint: "The window with focus"
        Choices { id: focusedChoice; key: "windowBorderFocused" }
        BorderSwatch {
            anchors.right: focusedChoice.left
            anchors.rightMargin: Theme.spaceM
            y: (focusedChoice.height - height) / 2
            color: Settings.windowBorderFocused === "text" ? Theme.text
                : Settings.windowBorderFocused === "custom" ? (Settings.windowBorderFocusedHex || Theme.strokeFocus)
                : Theme.strokeFocus
        }
    }

    HexColour {
        visible: Settings.windowBorderFocused === "custom"
        label: "Focused colour"
        key: "windowBorderFocusedHex"
        fallback: Theme.strokeFocus
        grayscaleOnly: false
    }

    SettingsField {
        label: "Unfocused border"
        hint: "Every other window"
        Choices { id: unfocusedChoice; key: "windowBorderUnfocused" }
        BorderSwatch {
            anchors.right: unfocusedChoice.left
            anchors.rightMargin: Theme.spaceM
            y: (unfocusedChoice.height - height) / 2
            color: Settings.windowBorderUnfocused === "none" ? "transparent"
                : Settings.windowBorderUnfocused === "custom" ? (Settings.windowBorderUnfocusedHex || Theme.border)
                : Theme.border
        }
    }

    HexColour {
        visible: Settings.windowBorderUnfocused === "custom"
        label: "Unfocused colour"
        key: "windowBorderUnfocusedHex"
        fallback: Theme.border
        grayscaleOnly: false
    }

    SettingsField {
        label: "Border width"
        hint: Settings.windowBorderWidth === "style" ? "As thick as the shell's strokes" : "Every window's border"
        Choices { key: "windowBorderWidth" }
    }

    // --- wallpaper ------------------------------------------------------

    Item { width: 1; height: Theme.spaceM }

    // the heading shares its line with the current image's name and arrows
    Item {
        readonly property bool isSectionBreak: true
        readonly property bool sectioned: true
        width: parent.width
        height: Math.max(Theme.controlSize, wpHeading.implicitHeight)

        FlyoutHeading {
            id: wpHeading
            firstInColumn: false
            anchors.left: parent.left
            anchors.right: arrows.left
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            text: "WALLPAPER" + (Wallpaper.title !== "" ? "  " + Wallpaper.title : "")
        }

        Row {
            id: arrows
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: wpHeading.lift
            spacing: Theme.spaceS

            FlyoutChip { glyph: true; text: "󰒮"; enabled: Wallpaper.images.length > 1; onClicked: Wallpaper.step(-1) }
            FlyoutChip { glyph: true; text: "󰒝"; enabled: Wallpaper.images.length > 1; onClicked: Wallpaper.shuffle() }
            FlyoutChip { glyph: true; text: "󰒭"; enabled: Wallpaper.images.length > 1; onClicked: Wallpaper.step(1) }
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

    SettingsField {
        label: "Fit"
        hint: "How it fills the screen"
        Choices { key: "wallpaperFill" }
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
}
