// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/PanelsTab.qml
//
// Appearance's Panels tab: POPUPS (notifications, the level popup, the
// flyouts' size), LAUNCHER, OVERLAYS (the switcher, the overview, the power
// menu, the backdrop behind them) and DESKTOP WIDGETS. Each section is a
// picture of its panels as they're set (PanelArt) beside its settings:
// choices as segments, sizes as sliders, on/off as lit chips. A size that
// doesn't apply rests dimmed. Nothing folds away.

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    tabId: "panels"

    // a section's picture on the left, its settings beside it
    component Beside: Item {
        id: bs
        property string kind: ""
        default property alias rows: col.data
        width: parent ? parent.width : 0
        height: Math.max(pic.height, col.implicitHeight)

        PanelArt {
            id: pic
            kind: bs.kind
            width: Theme.fit(220)
            height: Math.round(width * 0.72)
        }
        Column {
            id: col
            readonly property real labelWidth: Theme.fit(178)
            x: pic.width + Theme.spaceXl
            width: bs.width - x
            spacing: Theme.spaceM
        }
    }

    // a Settings boolean as a lit chip, On or Off
    component OnChip: FlyoutChip {
        property bool on: false
        anchors.right: parent ? parent.right : undefined
        text: on ? "On" : "Off"
        icon: on ? "󰄬" : ""
        selected: on
    }

    FlyoutHeading { text: "POPUPS" }

    Beside {
        kind: "popups"

        SettingsField {
            labelWidth: parent.labelWidth
            label: "Notification popups"
            Choices { key: "notifStyle" }
        }
        Stepper {
            slider: true; labelWidth: parent.labelWidth
            label: "Popup width"; key: "notifWidth"; step: 20; suffix: " px"
            enabled: Settings.notifStyle !== "banner"
            hint: enabled ? "Each notification popup" : "Banners span the top"
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
            visible: Theme.glass
            labelWidth: parent.labelWidth
            label: "Control Centre"
            hint: "Glass's home"
            Choices { key: "controlLayout" }
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

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "DESKTOP WIDGETS" }

    Beside {
        kind: "widgets"

        Repeater {
            model: [{ key: "clock", label: "Clock", hint: "The day, the time and the week" },
                    { key: "weather", label: "Weather", hint: "Now and the next five days" },
                    { key: "music", label: "Now playing", hint: "The Music module's player" },
                    { key: "stats", label: "System", hint: "CPU, GPU, memory, temperature" },
                    { key: "sysinfo", label: "System info", hint: "Distro, kernel, uptime, IP" }]

            SettingsField {
                id: widget
                required property var modelData
                readonly property bool on: Settings.deskWidget(modelData.key).on
                labelWidth: parent.labelWidth
                label: modelData.label
                hint: modelData.hint
                OnChip { on: widget.on; onClicked: Settings.setDeskWidget(widget.modelData.key, { on: !widget.on }) }
            }
        }

        SettingsField {
            labelWidth: parent.labelWidth
            label: "Sidebar"
            hint: "System readings down the right edge"
            OnChip { on: Settings.deskSidebar; onClicked: Settings.set("deskSidebar", !Settings.deskSidebar) }
        }

        SettingsField {
            visible: Settings.deskSidebar
            labelWidth: parent.labelWidth
            label: "Sidebar style"
            hint: Settings.deskSidebarStyle === "floating" ? "A card like the widgets, clear of the edges" : "Flush down the screen's edge"
            FlyoutSegmented {
                anchors.right: parent.right
                fill: false
                model: [{ value: "edge", text: "Edge" }, { value: "floating", text: "Floating" }]
                current: Settings.deskSidebarStyle
                onPicked: v => Settings.set("deskSidebarStyle", v)
            }
        }

        SettingsField {
            labelWidth: parent.labelWidth
            label: "Placement"
            hint: "Drag them about on the desktop"
            FlyoutChip {
                anchors.right: parent.right
                text: "Edit placement"
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "widgets", "edit"])
            }
        }
    }

    Component { id: launcherArt; LauncherArt {} }
}
