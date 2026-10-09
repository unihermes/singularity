// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/PanelsTab.qml
//
// The Appearance page's Panels tab.

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    tabId: "panels"

    FlyoutHeading { text: "LAUNCHER" }

    SettingsField {
        label: "Launcher layout"
        hint: "Rows, an icon grid, or one line"
        Choices { key: "launcherLayout" }
    }

    SettingsField {
        label: "Launcher position"
        hint: "Centred, under the bar, or full screen"
        Choices { key: "launcherPosition" }
    }

    SettingsField {
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

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "NOTIFICATIONS" }

    SettingsField {
        label: "Notification popups"
        hint: "How much each popup shows"
        Choices { key: "notifStyle" }
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

    SettingsField {
        label: "Power menu"
        hint: "How the power menu lays out"
        Choices { key: "powerStyle" }
    }

    SettingsField {
        label: "Level popup"
        hint: Settings.islandActive ? "Shown in the clock island instead"
            : "The volume and brightness popup"
        Choices { key: "levelStyle"; live: !Settings.islandActive }
    }

}
