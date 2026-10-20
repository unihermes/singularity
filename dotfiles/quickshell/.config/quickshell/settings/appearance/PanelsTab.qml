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
        hint: Theme.flyoutGrown ? "Grown flyouts always fade" : "How flyouts appear"
        Choice { key: "flyoutAnim" }
    }

    Grid {
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl * 2

        Stepper { width: panelsTab.half; labelWidth: panelsTab.halfLabel; label: "Flyout width"; hint: "For long names"; key: "flyoutWidth"; step: 10; suffix: "%" }
        Stepper { width: panelsTab.half; labelWidth: panelsTab.halfLabel; label: "Overlay dimming"; hint: "Behind overlays"; key: "scrim"; step: 5; suffix: "%" }
    }

    SettingsSubhead { caption: "NOTIFICATIONS" }

    SettingsField {
        label: "Notification popups"
        hint: "How much each popup shows"
        Choices { key: "notifStyle" }
    }

    Stepper { label: "Popup width"; hint: "Each notification popup"; key: "notifWidth"; step: 20; suffix: "px" }

    SettingsSubhead { caption: "LEVEL POPUP" }

    SettingsField {
        label: "Level popup"
        hint: Settings.islandActive ? "Shown in the clock island instead"
            : "The volume and brightness popup"
        Choices { key: "levelStyle"; live: !Settings.islandActive }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "LAUNCHER" }

    Tiles { key: "launcherLayout"; label: "Launcher layout"; hint: "Rows, an icon grid, or one line"; art: launcherArt; columns: 3; tileHeight: Theme.fs(64) }

    SettingsField {
        label: "Launcher position"
        hint: "Centred, under the bar, or full screen"
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
            hint: Settings.launcherDetails ? "Second lines and key hints"
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
        hint: "ALT+Tab's cards"
        Choices { key: "altTabStyle" }
    }

    SettingsField {
        label: "Switcher windows"
        hint: Settings.altTabScope === "all" ? "Every workspace's, in the bar too"
            : "Which windows ALT+Tab offers"
        Choices { key: "altTabScope" }
    }

    SettingsField {
        label: "Workspace overview"
        hint: "SUPER+W's layout"
        Choices { key: "overviewLayout" }
    }

    SettingsField {
        label: "Overview backdrop"
        hint: "Behind the overview"
        Choices { key: "overviewBackdrop" }
    }

    Tiles { key: "powerStyle"; label: "Power menu"; hint: "How the power menu lays out"; art: powerArt; columns: 3; tileHeight: Theme.fs(64) }

    Component { id: launcherArt; ModuleArt { kind: "launcherLayout" } }
    Component { id: powerArt; ModuleArt { kind: "powerStyle" } }
}
