// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/WindowsTab.qml
//
// The Windows page: WINDOWS (gaps, borders, corners, shadow, tab bar),
// EFFECTS (opacity, dim, blur) and MOTION, with neighbouring steppers,
// switches and segments two to a line and the three per-part speeds folded
// away; then RULES, the app rules' page a click away.

import Quickshell
import Quickshell.Widgets
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    id: windowsTab
    tabId: "windows"

    // a row in a two-column grid, and its label's share beside a stepper
    readonly property real half: (width - Theme.spaceXl * 2) / 2
    readonly property real halfLabel: half - Theme.fit(160) - Theme.spaceL
    readonly property real switchLabel: half - Theme.switchWidth - Theme.spaceL

    // the per-part speeds, folded away; a search for one opens them
    property bool speedsOpen: false
    readonly property var speedLabels: ["Window speed", "Workspace speed", "Shell speed"]
    Connections {
        target: windowsTab.page
        function onHighlightChanged() {
            if (windowsTab.speedLabels.indexOf(windowsTab.page.highlight) !== -1) windowsTab.speedsOpen = true
        }
    }

    FlyoutHeading { text: "WINDOWS" }

    Grid {
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl * 2

        HyprInt { width: windowsTab.half; labelWidth: windowsTab.halfLabel; label: "Window gaps"; note: "Between windows"; path: ["general"]; key: "gaps_in"; max: 20 }
        Stepper { width: windowsTab.half; labelWidth: windowsTab.halfLabel; label: "Edge gaps"; hint: Theme.barFull ? "At the screen edges" : "The bar floats in too"; key: "edgeGap"; suffix: "px" }
    }

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
            width: windowsTab.half
            labelWidth: windowsTab.half - focusedChoices.width - Theme.spaceL
            label: "Focused border"
            hint: "The one with focus"
            Choices { id: focusedChoices; key: "windowBorderFocused" }
        }

        SettingsField {
            width: windowsTab.half
            labelWidth: windowsTab.half - unfocusedChoices.width - Theme.spaceL
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

    SettingsField {
        label: "Tab bar"
        hint: "Over grouped windows: the open tab's fill"
        Choices { key: "tabBar" }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "EFFECTS" }

    Grid {
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl * 2

        Stepper { width: windowsTab.half; labelWidth: windowsTab.halfLabel; label: "Focused opacity"; key: "focusedOpacity"; step: 5; suffix: "%" }
        Stepper { width: windowsTab.half; labelWidth: windowsTab.halfLabel; label: "Unfocused opacity"; key: "unfocusedOpacity"; step: 5; suffix: "%" }
        HyprToggle { width: windowsTab.half; labelWidth: windowsTab.switchLabel; label: "Dim unfocused"; path: ["decoration"]; key: "dim_inactive" }
        HyprPercent { width: windowsTab.half; labelWidth: windowsTab.halfLabel; label: "Dim strength"; visible: page.hyprField(["decoration"], "dim_inactive").value === true; path: ["decoration"]; key: "dim_strength"; min: 0 }
    }

    HyprToggle { label: "Blur"; note: "Behind translucent windows and layers"; path: ["decoration", "blur"]; key: "enabled" }

    Grid {
        visible: page.blurOn
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl * 2

        HyprInt { width: windowsTab.half; labelWidth: windowsTab.halfLabel; label: "Blur size"; note: "Each pass's spread"; path: ["decoration", "blur"]; key: "size"; min: 1; max: 20 }
        HyprInt { width: windowsTab.half; labelWidth: windowsTab.halfLabel; label: "Blur passes"; note: "More is smoother"; path: ["decoration", "blur"]; key: "passes"; min: 1; max: 4; suffix: "" }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "MOTION" }

    SettingsField {
        label: "Animations"
        hint: "The shell's and Hyprland's"
        FlyoutSliderRow {
            anchors.right: parent.right
            width: Theme.fit(260)
            label: ""
            suffix: "%"
            value: Settings.animTime
            minimum: Settings.limits.animTime.min
            maximum: Settings.limits.animTime.max
            marks: Settings.animTimeMarks
            onMoved: v => Settings.set("animTime", v)
        }
    }

    FlyoutRow {
        label: "Per-part speeds…"
        note: Settings.animWindows === Settings.animWorkspaces && Settings.animWindows === Settings.animShell
            ? "windows, workspaces, shell · all " + Settings.animWindows + "%"
            : "windows " + Settings.animWindows + "% · workspaces " + Settings.animWorkspaces + "% · shell " + Settings.animShell + "%"
        trailing: windowsTab.speedsOpen ? "󰅀" : "󰅂"
        highlighted: windowsTab.speedsOpen
        onActivated: windowsTab.speedsOpen = !windowsTab.speedsOpen
    }

    SettingsIndent {
        visible: windowsTab.speedsOpen

        Stepper { label: "Window speed"; hint: "Open, close, move; lower is quicker"; key: "animWindows"; step: 25; suffix: "%" }
        Stepper { label: "Workspace speed"; hint: "Switching, and the scratchpad"; key: "animWorkspaces"; step: 25; suffix: "%" }
        Stepper { label: "Shell speed"; hint: "Flyouts, hovers and meters"; key: "animShell"; step: 25; suffix: "%" }
    }

    // each tile plays its animation while the pointer is on it
    Tiles { key: "windowAnim"; label: "Window animation"; hint: "Open, close, minimize, scratchpad"; art: animArt; columns: 4; tileHeight: Theme.fs(64) }

    Component { id: animArt; ModuleArt { kind: "windowAnim" } }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "RULES" }

    FlyoutRow {
        leadingIcon: "󰖲"
        label: "Window rules"
        note: "Per app: where it opens and its size; popups and dialogs; workspace layouts"
        trailing: "󰅂"
        onActivated: windowsTab.page.goTo("windowrules")
    }
}
