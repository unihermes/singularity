// Appearance's Panels tab: POPUPS (the level popup, the flyouts' size, and
// the way to the notification popups' own settings), LAUNCHER and OVERLAYS
// (the switcher, the overview, the power menu, the backdrop behind them).
// Each section is a picture of its panels as they're set (PanelArt) beside
// its settings:
// choices as segments, sizes as sliders, on/off as lit chips. A size that
// doesn't apply rests dimmed. Nothing folds away.

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    tabId: "panels"

    FlyoutHeading { text: "POPUPS" }

    Beside {
        kind: "popups"

        SettingsField {
            labelWidth: parent.labelWidth
            label: "Notification popups"
            hint: "Set on Notifications"
            FlyoutChip {
                anchors.right: parent.right
                text: "Open Notifications"
                onClicked: page.goTo("notifications")
            }
        }
        SettingsField {
            labelWidth: parent.labelWidth
            label: "Level popup"
            hint: Settings.islandActive ? "In the clock island instead" : "Volume and brightness"
            Choices { key: "levelStyle"; live: !Settings.islandActive }
        }
        Stepper { slider: true; labelWidth: parent.labelWidth; label: "Flyout width"; hint: "For long names"; key: "flyoutWidth"; step: 10; suffix: "%" }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "LAUNCHER" }

    Tiles { key: "launcherLayout"; label: "Launcher layout"; art: launcherArt; columns: 3; tileHeight: Theme.fs(100) }

    Beside {
        kind: "launcher"

        SettingsField {
            labelWidth: parent.labelWidth
            label: "Launcher position"
            hint: Theme.launcherPlaced ? "" : "Set by the layout"
            Choices { key: "launcherPosition"; live: Theme.launcherPlaced }
        }
        SettingsField {
            labelWidth: parent.labelWidth
            label: "Launcher details"
            defaultKey: "launcherDetails"
            hint: Settings.launcherDetails ? "Descriptions and key hints" : "Names only"
            OnChip { on: Settings.launcherDetails; onClicked: Settings.set("launcherDetails", !Settings.launcherDetails) }
        }
        Stepper {
            slider: true; labelWidth: parent.labelWidth
            label: "Rows shown"; key: "launcherRows"
            hint: "Before it scrolls"
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "OVERLAYS" }

    Beside {
        kind: "overlays"

        SettingsField {
            labelWidth: parent.labelWidth
            label: "Window switcher"
            hint: "ALT+Tab"
            Choices { key: "altTabStyle" }
        }
        SettingsField {
            labelWidth: parent.labelWidth
            label: "Switcher windows"
            hint: "And the bar's window list"
            Choices { key: "altTabScope" }
        }
        SettingsField {
            labelWidth: parent.labelWidth
            label: "Switcher blur"
            defaultKey: "altTabBlur"
            hint: "Frosted backdrop behind ALT+Tab"
            OnChip { on: Settings.altTabBlur; onClicked: Settings.set("altTabBlur", !Settings.altTabBlur) }
        }
        SettingsField {
            labelWidth: parent.labelWidth
            label: "Workspace overview"
            hint: "SUPER+W"
            Choices { key: "overviewLayout" }
        }
        SettingsField {
            labelWidth: parent.labelWidth
            label: "Power menu"
            Choices { key: "powerStyle" }
        }
        SettingsField {
            labelWidth: parent.labelWidth
            label: "Backdrop"
            hint: "Behind the overlays"
            Choices { key: "overviewBackdrop" }
        }
        Stepper {
            slider: true; labelWidth: parent.labelWidth
            label: "Overlay dimming"; key: "scrim"; step: 5; suffix: "%"
            enabled: Settings.overviewBackdrop === "dim"
            hint: enabled ? "How dark Dim is" : "With the Dim backdrop"
        }
    }

    Component { id: launcherArt; LauncherArt {} }
}
