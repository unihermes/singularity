// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/BarTab.qml
//
// Appearance's Bar tab: BAR (where it sits, its shape and size, then the
// layout of its modules), MODULES (a subhead per module) and MUSIC AND
// TRAY. Each section's rarely changed rows fold behind its Advanced.

import Quickshell
import QtQuick
import "../../services/Styles.js" as Styles
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    tabId: "bar"

    FlyoutHeading { text: "BAR" }

    SettingsField {
        label: "Position"
        defaultKey: "barPosition"

        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            model: [{ value: "top", text: "Top" }, { value: "bottom", text: "Bottom" }]
            current: Settings.barPosition
            onPicked: v => Settings.set("barPosition", v)
        }
    }

    SettingsField {
        label: "Bar shape"
        hint: Theme.barPlain ? "Plain (Shape) is always full width" : ""
        Choices { key: "barStyle"; live: !Theme.barPlain }
    }

    Stepper { label: "Height"; key: "barHeight"; step: 2; suffix: "px" }

    SettingsField {
        visible: Styles.get(Settings.style).options.every(o => o.key !== "barSeparator")
        label: "Separators"
        Choice { key: "barSeparator" }
    }

    SettingsSubhead { caption: "LAYOUT" }

    BarZones {}

    SettingsField {
        label: "Bar widgets"
        FlyoutChip {
            anchors.right: parent.right
            text: "Reset layout"
            confirmText: "Reset?"
            enabled: !Settings.widgetsDefault
            onClicked: Settings.resetWidgets()
        }
    }

    SettingsAdvanced {
        Stepper { label: "Icon size"; hint: "The bar's glyphs, at the base font size"; key: "barIconSize"; suffix: "px" }

        Stepper { label: "Module padding"; key: "modulePad"; suffix: "px" }

        // The centre module pinned to the bar's exact middle, the rest of the
        // centre stacking outward from it; none centres the whole group
        SettingsField {
            label: "Centre anchor"
            hint: "The module that stays dead centre"
            SettingsDropdown {
                anchors.right: parent.right
                model: [""].concat(Settings.widgetOrder("centre").filter(k => Settings.widgetVisible(k)))
                current: Settings.centreAnchor
                labelFor: v => v === "" ? "None" : (Settings.widgetMeta[v] || { label: v }).label
                onPicked: v => Settings.setCentreAnchor(v)
            }
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "MODULES" }

    SettingsSubhead { caption: "WORKSPACES" }

    Tiles { key: "workspaceStyle"; label: "Workspaces"; art: wsArt }

    // the names the Names workspace style shows, comma-separated in
    // workspace order; a blank one falls back to the number
    SettingsField {
        label: "Workspace names"
        visible: Theme.workspaceStyle === "names"
        hint: Theme.workspaceStyle === "names" ? "Comma-separated, Enter to apply"
            : "For the Names workspace style"

        FlyoutInput {
            anchors.right: parent.right
            width: Theme.fit(240)
            echoPassword: false
            placeholder: "web, code, chat"
            text: Settings.workspaceNames
            onAccepted: {
                Settings.set("workspaceNames", text.trim())
                page.say("Workspace names saved", false)
            }
            onEscapePressed: text = Settings.workspaceNames
        }
    }

    SettingsSubhead { caption: "OPEN WINDOWS" }

    Tiles { key: "windowStyle"; label: "Open windows"; art: winArt; columns: 5 }

    Stepper { label: "Window icon size"; hint: "App icons, capped to fit the bar's height"; key: "windowIconSize"; suffix: "px" }
    Stepper { label: "Window icon padding"; hint: "Room on each side of an app icon"; key: "windowIconPadding"; suffix: "px" }

    SettingsField {
        id: windowsShown
        label: "Windows shown"
        // held at every workspace while ALT+Tab offers them all
        // (Theme.windowScope)
        readonly property bool forced: Settings.altTabScope === "all"
        dimmed: forced
        hint: forced ? "All workspaces, as the window switcher is set to"
            : "All workspaces, grouped with a rule"
        Choices {
            key: "windowScope"
            live: !windowsShown.forced
            value: windowsShown.forced ? "all" : Settings.windowScope
            opacity: live ? 1 : 0.4
        }
    }

    SettingsField {
        label: "App icons"
        hint: "The open windows' and the tray's"
        Choices { key: "iconTint" }
    }

    SettingsSubhead { caption: "CLOCK" }

    Tiles { key: "clockStyle"; label: "Clock"; art: clockArt }

    // the Custom clock style's pattern, in Qt's date format
    SettingsField {
        label: "Clock format"
        visible: Theme.clockStyle === "custom"
        hint: Theme.clockStyle !== "custom" ? "For the Custom clock style"
            : "Now: " + Qt.formatDateTime(new Date(), Theme.hours(clockFmt.text || "HH:mm"))
              + ", Enter to apply"

        FlyoutInput {
            id: clockFmt
            anchors.right: parent.right
            width: Theme.fit(240)
            echoPassword: false
            placeholder: "ddd HH:mm"
            text: Settings.clockFormat
            onAccepted: {
                Settings.set("clockFormat", text.trim() || "HH:mm")
                page.say("Clock format saved", false)
            }
            onEscapePressed: text = Settings.clockFormat
        }
    }

    SettingsSubhead { caption: "CONTROL CENTRE" }

    Tiles { key: "controlIcon"; label: "Control Centre icon"; art: iconArt; columns: 6; tileHeight: Theme.fs(58) }

    SettingsAdvanced {
        SettingsField {
            label: "Clock island"
            defaultKey: "clockIsland"
            hint: !Settings.widgetVisible("clock") ? "Needs the clock on the bar"
                : Settings.clockIsland ? "Volume and layout show in the clock"
                : "Separate toasts under the bar"

            Switch {
                anchors.right: parent.right
                checked: Settings.clockIsland
                onToggled: Settings.setClockIsland(!Settings.clockIsland)
            }
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "MUSIC AND TRAY" }

    SettingsField {
        label: "Music visualizer"
        hint: Settings.vizShown ? "The spectrum of everything playing, in place of the player's icon"
            : "Off"

        Switch {
            anchors.right: parent.right
            checked: Settings.vizShown
            onToggled: Settings.set("vizShown", !Settings.vizShown)
        }
    }

    SettingsField {
        label: "Music title"
        hint: Settings.musicTitle ? "Artist and title after the spectrum or icon"
            : "The spectrum or icon alone"

        Switch {
            anchors.right: parent.right
            checked: Settings.musicTitle
            onToggled: Settings.set("musicTitle", !Settings.musicTitle)
        }
    }

    Tiles { key: "vizStyle"; label: "Visualizer"; hint: "The audio spectrum while sound plays"; art: vizArt }

    SettingsField {
        label: "Tray drawer"
        hint: Settings.trayDrawer ? "Icons fold behind a chevron"
            : "Every tray icon shows"

        Switch {
            anchors.right: parent.right
            checked: Settings.trayDrawer
            onToggled: Settings.set("trayDrawer", !Settings.trayDrawer)
        }
    }

    // apps hidden from the tray menu's Hide from the tray, a chip each to
    // bring one back
    SettingsField {
        label: "Hidden tray icons"
        hint: Settings.trayHidden.length > 0 ? "Click one to show it again"
            : "Hide an app from its tray menu"

        Flow {
            anchors.right: parent.right
            width: parent.width
            layoutDirection: Qt.RightToLeft
            spacing: Theme.spaceS

            Repeater {
                model: Settings.trayHidden
                FlyoutChip {
                    required property string modelData
                    icon: "󰈈"
                    text: modelData
                    onClicked: Settings.setTrayHidden(modelData, false)
                }
            }
        }
    }

    SettingsAdvanced {
        Stepper { label: "Visualizer bars"; key: "vizBars" }

        SettingsField {
            label: "Hide when silent"
            hint: Settings.vizHideSilent ? "The Music module shows only while sound plays"
                : "The Music module stays while a player is open"

            Switch {
                anchors.right: parent.right
                checked: Settings.vizHideSilent
                onToggled: Settings.set("vizHideSilent", !Settings.vizHideSilent)
            }
        }
    }

    Component { id: wsArt; ModuleArt { kind: "workspaceStyle" } }
    Component { id: winArt; ModuleArt { kind: "windowStyle" } }
    Component { id: clockArt; ModuleArt { kind: "clockStyle" } }
    Component { id: iconArt; ModuleArt { kind: "controlIcon" } }
    Component { id: vizArt; ModuleArt { kind: "vizStyle" } }
}
