// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/PanelsTab.qml
//
// The Appearance page's Panels tab: POPUPS (flyouts, notifications, the
// level popup), LAUNCHER and OVERLAYS; neighbouring steppers and switches
// two to a line.

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    id: panelsTab
    tabId: "panels"

    // a row in a two-column grid, and its label's share beside a stepper
    readonly property real half: (width - Theme.spaceXl * 2) / 2
    readonly property real halfLabel: half - Theme.fit(160) - Theme.spaceL

    FlyoutHeading { text: "POPUPS" }

    SettingsField {
        label: "Flyouts open"
        hint: Theme.flyoutGrown ? "Expanded flyouts always fade" : ""
        Choice { key: "flyoutAnim" }
    }

    Grid {
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl * 2

        Stepper { width: panelsTab.half; labelWidth: panelsTab.halfLabel; label: "Flyout width"; key: "flyoutWidth"; step: 10; suffix: "%" }
        Stepper { width: panelsTab.half; labelWidth: panelsTab.halfLabel; label: "Overlay dimming"; key: "scrim"; step: 5; suffix: "%" }
    }

    SettingsSubhead { caption: "NOTIFICATIONS" }

    SettingsField {
        label: "Notification popups"
        Choices { key: "notifStyle" }
    }

    Stepper { label: "Popup width"; key: "notifWidth"; step: 20; suffix: "px" }

    SettingsSubhead { caption: "LEVEL POPUP" }

    SettingsField {
        label: "Level popup"
        hint: Settings.islandActive ? "Shown in the clock island instead"
            : "The volume and brightness popup"
        Choices { key: "levelStyle"; live: !Settings.islandActive }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "LAUNCHER" }

    Tiles { key: "launcherLayout"; label: "Launcher layout"; art: launcherArt; columns: 3; tileHeight: Theme.fs(64) }

    SettingsField {
        label: "Launcher position"
        Choices { key: "launcherPosition" }
    }

    Grid {
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl * 2

        SettingsField {
            width: panelsTab.half
            labelWidth: panelsTab.half - Theme.switchWidth - Theme.spaceL
            label: "Launcher details"
            lookKey: "launcherDetails"
            hint: Settings.launcherDetails ? "Descriptions and keyboard hints"
                : "Names only"

            Switch {
                anchors.right: parent.right
                checked: Settings.launcherDetails
                onToggled: Settings.set("launcherDetails", !Settings.launcherDetails)
            }
        }
        Stepper { width: panelsTab.half; labelWidth: panelsTab.halfLabel; label: "Rows shown"; hint: "Before it scrolls"; key: "launcherRows" }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "OVERLAYS" }

    SettingsField {
        label: "Window switcher"
        hint: "ALT+Tab"
        Choices { key: "altTabStyle" }
    }

    SettingsField {
        label: "Switcher windows"
        hint: "Also applies to the window list in the bar"
        Choices { key: "altTabScope" }
    }

    SettingsField {
        label: "Workspace overview"
        hint: "SUPER+W"
        Choices { key: "overviewLayout" }
    }

    SettingsField {
        label: "Overview backdrop"
        Choices { key: "overviewBackdrop" }
    }

    Tiles { key: "powerStyle"; label: "Power menu"; art: powerArt; columns: 3; tileHeight: Theme.fs(64) }

    Component { id: launcherArt; ModuleArt { kind: "launcherLayout" } }
    Component { id: powerArt; ModuleArt { kind: "powerStyle" } }
}
