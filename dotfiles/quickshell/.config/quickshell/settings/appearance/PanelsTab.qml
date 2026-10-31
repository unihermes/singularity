// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/PanelsTab.qml
//
// Appearance's Panels tab: POPUPS (notifications, the level popup, the
// flyouts' size), LAUNCHER, OVERLAYS and DESKTOP WIDGETS (which show on the
// desktop, the sidebar, and their edit mode). Each section's rarely changed
// rows fold behind its Advanced; neighbours go two to a line.

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    id: panelsTab
    tabId: "panels"

    // a row in a two-column grid, and its label's share beside a stepper
    // or a switch
    readonly property real half: (width - Theme.spaceXl * 2) / 2
    readonly property real halfLabel: half - Theme.fit(160) - Theme.spaceL
    readonly property real switchLabel: half - Theme.switchWidth - Theme.spaceL

    FlyoutHeading { text: "POPUPS" }

    SettingsField {
        label: "Notification popups"
        Choices { key: "notifStyle" }
    }

    SettingsField {
        label: "Level popup"
        hint: Settings.islandActive ? "Shown in the clock island instead"
            : "The volume and brightness popup"
        Choices { key: "levelStyle"; live: !Settings.islandActive }
    }

    SettingsAdvanced {
        Stepper { label: "Popup width"; key: "notifWidth"; step: 20; suffix: "px" }

        Grid {
            width: parent.width
            columns: 2
            columnSpacing: Theme.spaceXl * 2

            Stepper { width: panelsTab.half; labelWidth: panelsTab.halfLabel; label: "Flyout width"; key: "flyoutWidth"; step: 10; suffix: "%" }
            Stepper { width: panelsTab.half; labelWidth: panelsTab.halfLabel; label: "Overlay dimming"; key: "scrim"; step: 5; suffix: "%" }
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "LAUNCHER" }

    Tiles { key: "launcherLayout"; label: "Launcher layout"; art: launcherArt; columns: 3; tileHeight: Theme.fs(64) }

    SettingsField {
        label: "Launcher position"
        Choices { key: "launcherPosition" }
    }

    SettingsAdvanced {
        Grid {
            width: parent.width
            columns: 2
            columnSpacing: Theme.spaceXl * 2

            SettingsField {
                width: panelsTab.half
                labelWidth: panelsTab.switchLabel
                label: "Launcher details"
                defaultKey: "launcherDetails"
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

    Tiles { key: "powerStyle"; label: "Power menu"; art: powerArt; columns: 3; tileHeight: Theme.fs(64) }

    SettingsAdvanced {
        SettingsField {
            label: "Overview backdrop"
            Choices { key: "overviewBackdrop" }
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "DESKTOP WIDGETS" }

    Grid {
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl * 2

        Repeater {
            model: [{ key: "clock", label: "Clock", hint: "The day, the time and the week" },
                    { key: "weather", label: "Weather", hint: "Now and the next five days" },
                    { key: "music", label: "Now playing", hint: "The Music module's player" },
                    { key: "stats", label: "System", hint: "CPU, GPU, memory, temperature" },
                    { key: "sysinfo", label: "System info", hint: "Distro, kernel, uptime, IP" }]

            SettingsField {
                required property var modelData
                width: panelsTab.half
                labelWidth: panelsTab.switchLabel
                label: modelData.label
                hint: modelData.hint
                Switch {
                    anchors.right: parent.right
                    checked: Settings.deskWidget(modelData.key).on
                    onToggled: Settings.setDeskWidget(modelData.key, { on: !checked })
                }
            }
        }
    }

    SettingsField {
        label: "Sidebar"
        hint: "System readings down the right edge of the main display"
        Switch {
            anchors.right: parent.right
            checked: Settings.deskSidebar
            onToggled: Settings.set("deskSidebar", !checked)
        }
    }

    SettingsField {
        labelWidth: parent.width - placeChip.width - Theme.spaceL
        label: "Placement"
        FlyoutChip {
            id: placeChip
            anchors.right: parent.right
            text: "Edit placement"
            onClicked: Quickshell.execDetached(["qs", "ipc", "call", "widgets", "edit"])
        }
    }

    Component { id: launcherArt; ModuleArt { kind: "launcherLayout" } }
    Component { id: powerArt; ModuleArt { kind: "powerStyle" } }
}
