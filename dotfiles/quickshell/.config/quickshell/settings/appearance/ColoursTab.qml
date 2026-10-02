// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/ColoursTab.qml
//
// The Appearance page's Colours tab.

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
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
