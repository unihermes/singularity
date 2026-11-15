// Appearance's Colour tab, laid out round the palette itself (the
// "palette workshop"). SCHEME: where the colours come from, the looks as
// a carousel each with its own strip, then the palette in use as a ramp of
// labelled swatches (the ten greys, then accent, good and alert); a click
// on one opens it in the editor under the ramp (its hex, and for the
// accent the presets, Hue and Lightness), and Level colour. Nothing folds
// away.

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
}
