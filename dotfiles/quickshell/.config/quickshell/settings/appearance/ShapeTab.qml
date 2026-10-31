// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/ShapeTab.qml
//
// Appearance's Shape tab, how everything is drawn and spaced: STYLE (with
// its finish), SPACE (the shell's and the windows' gaps), GLASS (opacity,
// dim and blur) and WINDOWS (corners, shadow, the rules a click away).
// Each section's rarely changed rows fold behind its Advanced.

import Quickshell
import QtQuick
import "../../services/Styles.js" as Styles
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    id: shapeTab
    tabId: "shape"

    // a row in a two-column grid, and its label's share beside a stepper
    // or a switch
    readonly property real half: (width - Theme.spaceXl * 2) / 2
    readonly property real halfLabel: half - Theme.fit(160) - Theme.spaceL
    readonly property real switchLabel: half - Theme.switchWidth - Theme.spaceL

    FlyoutHeading { text: "STYLE" }

    Tiles { key: "style"; label: "Style"; hint: Styles.get(Settings.style).hint; art: styleArt; columns: 5 }

    Stepper {
        label: "Roundness"; key: "radius"; suffix: "px"
        enabled: !Styles.get(Settings.style).square
        hint: !enabled ? Styles.get(Settings.style).name + " keeps every corner square"
            : "Chips, panels, the bar and every window"
    }

    FinishSwitch {
        label: "Plain"; key: "plain"
        hint: "Flat over any style: bare chips on a full bar, flyouts flush under it, no shadows or frames round rows"
    }

    SettingsField {
        label: "Bar chips"
        hint: Settings.barChips !== "auto" ? "Bare, outlined or one strip per group, whatever the style"
            : Settings.plain ? "Bare, as Plain draws them" : "Framed as the style draws them"
        Choice { key: "barChips" }
    }

    // the shared switches its options don't already stand for
    readonly property var optionKeys: Styles.get(Settings.style).options.map(o => o.key || "")

    // the finish: the style's own options first, then the shared switches,
    // two to a line
    SettingsAdvanced {
        Grid {
            width: parent.width
            columns: 2
            columnSpacing: Theme.spaceXl * 2

            Repeater {
                model: Styles.get(Settings.style).options
                StyleOption { required property var modelData; option: modelData; width: shapeTab.half; labelWidth: shapeTab.switchLabel }
            }

            FinishSwitch {
                width: shapeTab.half; labelWidth: shapeTab.switchLabel
                visible: shapeTab.optionKeys.indexOf("shadows") === -1
                label: "Shadows"; key: "shadows"
                live: Styles.get(Settings.style).shadow !== "none" && !Settings.plain
                hint: Settings.plain ? "Plain has none" : live ? "The style's " + Styles.get(Settings.style).shadow + " shadow, windows too" : "This style has none"
            }

            FinishSwitch { width: shapeTab.half; labelWidth: shapeTab.switchLabel; visible: shapeTab.optionKeys.indexOf("gradient") === -1; label: "Shaded grounds"; key: "gradient"; hint: "A faint shade down the bar and panels" }

            FinishSwitch {
                width: shapeTab.half; labelWidth: shapeTab.switchLabel
                visible: shapeTab.optionKeys.indexOf("heavyLines") === -1
                label: "Heavy lines"; key: "heavyLines"
                live: Styles.get(Settings.style).lines && !Settings.plain
                hint: Settings.plain ? "Plain keeps hairlines" : live ? "Every stroke 2px, windows' borders too" : "This style has no lines"
            }
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "SPACE" }

    // a preset for the three dials: Spacing and Row height here, Height on
    // the Bar tab; the dials only show on Custom (or once one leaves every
    // preset)
    property bool customSpace: Settings.density === "custom"

    SettingsField {
        label: "Density"
        hint: shapeTab.customSpace ? "Your own: set by the dials"
            : ({ compact: "Tighter gaps and shorter rows", normal: "The shell as designed",
                 roomy: "Wider gaps and taller rows" })[Settings.density] || ""
        Choices {
            id: densityChoices
            key: "density"
            value: shapeTab.customSpace ? "custom" : Settings.density
        }
        Connections {
            target: densityChoices
            function onPicked(v) { shapeTab.customSpace = v === "custom" }
        }
    }

    Stepper { visible: shapeTab.customSpace || page.highlight === "Spacing"; label: "Spacing"; hint: "Every gap and padding"; key: "spacing"; step: 5; suffix: "%" }

    Stepper { visible: shapeTab.customSpace || page.highlight === "Row height"; label: "Row height"; hint: "Lists, fields and chips"; key: "rowScale"; step: 5; suffix: "%" }

    Grid {
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl * 2

        HyprInt { width: shapeTab.half; labelWidth: shapeTab.halfLabel; label: "Window gaps"; note: "Between windows"; path: ["general"]; key: "gaps_in"; max: 20 }
        Stepper { width: shapeTab.half; labelWidth: shapeTab.halfLabel; label: "Edge gaps"; hint: Theme.barFull ? "At the screen edges" : "The bar floats in too"; key: "edgeGap"; suffix: "px" }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "GLASS" }

    Stepper { label: "See-through"; hint: Theme.glass ? "The bar and panels; Glass adds more" : "The bar and every panel"; key: "seeThrough"; step: 5; suffix: "%" }

    Grid {
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl * 2

        Stepper { width: shapeTab.half; labelWidth: shapeTab.halfLabel; label: "Focused opacity"; key: "focusedOpacity"; step: 5; suffix: "%" }
        Stepper { width: shapeTab.half; labelWidth: shapeTab.halfLabel; label: "Unfocused opacity"; key: "unfocusedOpacity"; step: 5; suffix: "%" }
        HyprToggle { width: shapeTab.half; labelWidth: shapeTab.switchLabel; label: "Dim unfocused"; path: ["decoration"]; key: "dim_inactive" }
        HyprPercent { width: shapeTab.half; labelWidth: shapeTab.halfLabel; label: "Dim strength"; visible: page.hyprField(["decoration"], "dim_inactive").value === true; path: ["decoration"]; key: "dim_strength"; min: 0 }
    }

    HyprToggle { label: "Blur"; note: "Behind translucent windows and layers"; path: ["decoration", "blur"]; key: "enabled" }

    SettingsAdvanced {
        Grid {
            visible: page.blurOn
            width: parent.width
            columns: 2
            columnSpacing: Theme.spaceXl * 2

            HyprInt { width: shapeTab.half; labelWidth: shapeTab.halfLabel; label: "Blur size"; note: "Each pass's spread"; path: ["decoration", "blur"]; key: "size"; min: 1; max: 20 }
            HyprInt { width: shapeTab.half; labelWidth: shapeTab.halfLabel; label: "Blur passes"; note: "More is smoother"; path: ["decoration", "blur"]; key: "passes"; min: 1; max: 4; suffix: "" }
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "WINDOWS" }

    SettingsField {
        label: "Window corners"
        hint: Settings.windowRounding === "shell" ? "Rounded like the shell's panels" : "A rounding of their own"
        Choices { key: "windowRounding" }
    }

    Stepper { visible: Settings.windowRounding === "own"; label: "Window rounding"; hint: "Corner radius"; key: "windowRadius"; suffix: "px" }

    SettingsField {
        label: "Window shadow"
        hint: Settings.windowShadow === "style" ? (Theme.shadow === "none" ? "The style's: none, or Shadows is off" : "The style's soft shadow")
            : "Under every window"
        Choices { key: "windowShadow" }
    }

    FlyoutRow {
        leadingIcon: "󰖲"
        label: "Window rules"
        note: "Per app: where it opens and its size; popups and dialogs; workspace layouts"
        trailing: "󰅂"
        onActivated: shapeTab.page.goTo("windowrules")
    }

    SettingsAdvanced {
        SettingsField {
            label: "Tab bar"
            hint: "Over grouped windows: the open tab's fill"
            Choices { key: "tabBar" }
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
