// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/StyleTab.qml
//
// The Appearance page's Style tab.

import Quickshell
import QtQuick
import "../../services/Styles.js" as Styles
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    tabId: "style"

    FlyoutHeading { text: "STYLE" }

    Tiles { key: "style"; label: "Style"; hint: Styles.get(Settings.style).hint; art: styleArt; columns: 5 }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "SHAPE" }

    Stepper {
        label: "Roundness"; key: "radius"; suffix: "px"
        enabled: !Styles.get(Settings.style).square
        hint: !enabled ? Styles.get(Settings.style).name + " keeps every corner square"
            : Theme.moduleStyle === "pill" ? "Panels and windows; chips are pills" : "Chips, panels, the bar and every window"
    }

    SettingsField {
        label: "Bar shape"
        hint: "Where flyouts sit and the gaps at screen edges follow it"
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
            onClicked: Session.restartShell()
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
            radius: Theme.radius > 0 ? Theme.radius + 2 : 0
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
}
