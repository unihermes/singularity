// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/ShapeTab.qml
//
// Appearance's Shape tab, how everything is drawn and spaced: STYLE (with
// its finish), SPACE (the shell's and the windows' gaps), GLASS (opacity,
// dim and blur) and WINDOWS (corners, shadow, the rules a click away).
// Numbers are sliders, written when the drag ends; a slider that doesn't
// apply (Dim strength with Dim off) rests rather than hiding. The finish
// is a line of toggle chips. Nothing folds away.

import Quickshell
import QtQuick
import "../../services/Styles.js" as Styles
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    id: shapeTab
    tabId: "shape"

    FlyoutHeading { text: "STYLE" }

    Tiles { key: "style"; label: "Style"; hint: Styles.get(Settings.style).hint; art: styleArt; columns: 5 }

    Stepper {
        slider: true
        label: "Roundness"; key: "radius"; suffix: " px"
        enabled: !Styles.get(Settings.style).square
        hint: !enabled ? Styles.get(Settings.style).name + (Settings.style === "notch" ? " keeps its cut corners" : " keeps every corner square")
            : "Chips, panels, the bar and every window"
    }

    // the shared switches its options don't already stand for
    readonly property var optionKeys: Styles.get(Settings.style).options.map(o => o.key || "")

    // the finish as a line of toggle chips under its label, lit while on:
    // the style's own options, then the shared ones it doesn't already
    // offer, then Plain over any style; a chip the style gives nothing to
    // do rests
    SettingsField {
        label: "Finish"
        hint: Settings.plain ? "Plain: bare chips, flyouts flush under the bar, no shadows"
            : Styles.get(Settings.style).name + "'s own touches, then Plain over any style"
    }

    Flow {
        width: parent.width
        spacing: Theme.spaceS

        Repeater {
            model: Styles.get(Settings.style).options

            FlyoutChip {
                id: opt
                required property var modelData
                readonly property string key: modelData.key || ""
                readonly property bool on: key === "" ? Theme.opt(modelData.id)
                    : modelData.value !== undefined ? Settings[key] === modelData.value : !!Settings[key]
                text: modelData.label
                icon: on ? "󰄬" : ""
                selected: on
                onClicked: {
                    if (opt.key === "") Settings.setStyleOption(opt.modelData.id, !opt.on)
                    else if (opt.modelData.value !== undefined) Settings.set(opt.key, opt.on ? Styles.offValue(opt.modelData) : opt.modelData.value)
                    else Settings.set(opt.key, !opt.on)
                }
            }
        }
        FlyoutChip {
            readonly property bool live: Styles.get(Settings.style).shadow !== "none" && !Settings.plain
            visible: shapeTab.optionKeys.indexOf("shadows") === -1
            enabled: live
            text: "Shadows"
            icon: Settings.shadows && live ? "󰄬" : ""
            selected: Settings.shadows && live
            onClicked: Settings.set("shadows", !Settings.shadows)
        }
        FlyoutChip {
            visible: shapeTab.optionKeys.indexOf("gradient") === -1
            text: "Shaded grounds"
            icon: Settings.gradient ? "󰄬" : ""
            selected: Settings.gradient
            onClicked: Settings.set("gradient", !Settings.gradient)
        }
        FlyoutChip {
            readonly property bool live: Styles.get(Settings.style).lines && !Settings.plain
            visible: shapeTab.optionKeys.indexOf("heavyLines") === -1
            enabled: live
            text: "Heavy lines"
            icon: Settings.heavyLines && live ? "󰄬" : ""
            selected: Settings.heavyLines && live
            onClicked: Settings.set("heavyLines", !Settings.heavyLines)
        }
        FlyoutChip {
            text: "Plain"
            icon: Settings.plain ? "󰄬" : ""
            selected: Settings.plain
            onClicked: Settings.set("plain", !Settings.plain)
        }
    }

    SettingsField {
        label: "Bar chips"
        hint: Settings.barChips !== "auto" ? "Bare, outlined or one strip per group, whatever the style"
            : Settings.plain ? "Bare, as Plain draws them" : "Framed as the style draws them"
        Choice { key: "barChips" }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "SPACE" }

    // a preset for the three dials (Spacing and Row height here, Height on
    // the Bar tab); moving a dial off every preset reads as Custom
    Tiles {
        key: "density"; label: "Density"; art: densityArt; columns: 4
        tileHeight: Theme.fs(64)
        hint: ({ compact: "Tighter gaps and shorter rows", normal: "The shell as designed",
                 roomy: "Wider gaps and taller rows", custom: "Your own, from the dials below" })[Settings.density] || ""
    }

    Stepper { slider: true; label: "Spacing"; hint: "Every gap and padding"; key: "spacing"; step: 5; suffix: "%" }
    Stepper { slider: true; label: "Row height"; hint: "Lists, fields and chips"; key: "rowScale"; step: 5; suffix: "%" }
    HyprInt { slider: true; label: "Window gaps"; note: "Between windows"; path: ["general"]; key: "gaps_in"; max: 20 }
    Stepper {
        slider: true; label: "Edge gaps"; key: "edgeGap"; suffix: " px"
        hint: Theme.barFull ? "Windows to the screen edges" : "The bar and windows to the screen edges"
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "GLASS" }

    Stepper { slider: true; label: "See-through"; hint: Theme.glass ? "The bar and panels; Glass adds more" : "The bar and every panel"; key: "seeThrough"; step: 5; suffix: "%" }
    Stepper { slider: true; label: "Focused opacity"; hint: "The window with focus"; key: "focusedOpacity"; step: 5; suffix: "%" }
    Stepper { slider: true; label: "Unfocused opacity"; hint: "Every other window"; key: "unfocusedOpacity"; step: 5; suffix: "%" }

    // on/off as a lit chip, a level beside it resting while it's off
    component HyprChip: FlyoutChip {
        property var path: []
        property string key: ""
        property string what: ""
        readonly property var field: shapeTab.page.hyprField(path, key)
        enabled: field.editable
        text: field.value === true ? "On" : "Off"
        icon: field.value === true ? "󰄬" : ""
        selected: field.value === true
        onClicked: shapeTab.page.setHypr(path, key, field.value !== true, what + (field.value === true ? " off" : " on"))
    }

    SettingsField {
        label: "Dim unfocused"
        hint: "Darken the windows you're not in"
        HyprChip { anchors.right: parent.right; path: ["decoration"]; key: "dim_inactive"; what: "Dim unfocused" }
    }
    HyprPercent {
        slider: true; label: "Dim strength"; path: ["decoration"]; key: "dim_strength"; min: 0
        enabled: page.hyprField(["decoration"], "dim_inactive").value === true
        hint: !live ? "Not a plain value in looks.lua" : enabled ? "How dark" : "With Dim unfocused"
    }

    SettingsField {
        label: "Blur"
        hint: "Behind translucent windows and the shell"
        HyprChip { anchors.right: parent.right; path: ["decoration", "blur"]; key: "enabled"; what: "Blur" }
    }
    HyprInt { slider: true; enabled: page.blurOn; label: "Blur size"; note: page.blurOn ? "Each pass's spread" : "With Blur"; path: ["decoration", "blur"]; key: "size"; min: 1; max: 20; suffix: "" }
    HyprInt { slider: true; enabled: page.blurOn; label: "Blur passes"; note: page.blurOn ? "More is smoother" : "With Blur"; path: ["decoration", "blur"]; key: "passes"; min: 1; max: 4; suffix: "" }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "WINDOWS" }

    SettingsField {
        label: "Window corners"
        hint: Settings.windowRounding === "shell" ? "Rounded like the shell's panels" : "A rounding of their own"
        Choices { key: "windowRounding" }
    }

    Stepper {
        slider: true; label: "Window rounding"; key: "windowRadius"; suffix: " px"
        enabled: Settings.windowRounding === "own"
        hint: enabled ? "Corner radius" : "With a rounding of their own"
    }

    SettingsField {
        label: "Window shadow"
        hint: Settings.windowShadow === "style" ? (Theme.shadow === "none" ? "The style's: none, or Shadows is off" : "The style's soft shadow")
            : "Under every window"
        Choices { key: "windowShadow" }
    }

    SettingsField {
        label: "Tab bar"
        hint: "Over grouped windows: the open tab's fill"
        Choices { key: "tabBar" }
    }

    FlyoutRow {
        leadingIcon: "󰖲"
        label: "Window rules"
        note: "Per app: where it opens and its size; popups and dialogs; workspace layouts"
        trailing: "󰅂"
        onActivated: shapeTab.page.goTo("windowrules")
    }

    // Four rows of a list at the preset's gap and height
    Component {
        id: densityArt
        Column {
            readonly property var d: ({ compact: [2, 5], normal: [4, 6], roomy: [7, 7], custom: [4, 6] })[parent ? parent.value : "normal"] || [4, 6]
            width: Theme.fs(56)
            spacing: Theme.fs(d[0])
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: parent.width * (index === 3 && parent.parent && parent.parent.value === "custom" ? 0.6 : 1)
                    height: Theme.fs(parent.d[1])
                    radius: Theme.pill(height)
                    color: index === 0 ? Theme.accent : Theme.overlay
                }
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
            readonly property int r: ya.v === "capsule" ? Theme.fs(8)
                : Styles.get(ya.v) && Styles.get(ya.v).square ? 0 : Math.min(Theme.radius, 5)
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
                            visible: ["channel", "flat", "rail", "notch", "pane", "bevel"].indexOf(ya.v) === -1
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
                        StyleFrame {
                            visible: ["rail", "notch", "pane", "bevel"].indexOf(ya.v) !== -1
                            kind: Styles.get(ya.v) ? Styles.get(ya.v).frame : "none"
                            ground: chip.lit ? Theme.overlay : Theme.surface
                            stroke: chip.lit ? Theme.accent : Theme.muted
                            control: true
                            sunken: chip.lit
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
                            color: chip.lit && (ya.v === "solid" || ya.v === "glass" || ya.v === "capsule") ? Theme.textOnAccent : Theme.text
                        }
                    }
                }
            }
        }
    }
}
