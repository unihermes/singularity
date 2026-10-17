// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/BarTab.qml
//
// The Appearance page's Bar tab.

import Quickshell
import QtQuick
import "../../services/Styles.js" as Styles
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    tabId: "bar"

    FlyoutHeading { text: "LAYOUT" }

    BarZones {}

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

    SettingsField {
        label: "Bar widgets"
        hint: Settings.widgetsDefault ? "As it comes" : "Put every module back where it started"
        FlyoutChip {
            anchors.right: parent.right
            text: "Reset layout"
            confirmText: "Reset?"
            enabled: !Settings.widgetsDefault
            onClicked: Settings.resetWidgets()
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "BAR" }

    SettingsField {
        label: "Position"
        lookKey: "barPosition"
        hint: "Flyouts open from whichever edge it's on"

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
        hint: "Where flyouts sit and the gaps at screen edges follow it"
        Choices { key: "barStyle" }
    }

    Stepper { label: "Height"; hint: "The bar; its chips grow with it"; key: "barHeight"; step: 2; suffix: "px" }

    Stepper { label: "Icon size"; hint: "The bar's glyphs, at the base font size"; key: "barIconSize"; suffix: "px" }

    Stepper { label: "Module padding"; hint: "Room either side of each module"; key: "modulePad"; suffix: "px" }

    SettingsField {
        visible: Styles.get(Settings.style).options.every(o => o.key !== "barSeparator")
        label: "Separators"
        hint: "Between the bar's modules"
        Choice { key: "barSeparator" }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "WORKSPACES" }

    Tiles { key: "workspaceStyle"; label: "Workspaces"; hint: "How the workspace indicator marks each one"; art: wsArt }

    // the names the Names workspace style shows, comma-separated in
    // workspace order; a blank one falls back to the number
    SettingsField {
        label: "Workspace names"
        visible: Theme.workspaceStyle === "names"
        hint: Theme.workspaceStyle === "names" ? "Comma-separated, Enter to apply"
            : "For the Names workspace style"

        FlyoutInput {
            id: wsNames
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

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "OPEN WINDOWS" }

    Tiles { key: "windowStyle"; label: "Open windows"; hint: "How open windows are drawn"; art: winArt; columns: 5 }

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

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "CLOCK" }

    Tiles { key: "clockStyle"; label: "Clock"; hint: "What the clock chip shows"; art: clockArt }

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

    SettingsField {
        label: "Clock island"
        hint: !Settings.widgetVisible("clock") ? "Needs the clock on the bar"
            : Settings.clockIsland ? "Volume and layout show in the clock"
            : "Separate toasts under the bar"

        Switch {
            anchors.right: parent.right
            checked: Settings.clockIsland
            onToggled: Settings.setClockIsland(!Settings.clockIsland)
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "CONTROL CENTRE" }

    Tiles { key: "controlIcon"; label: "Control Centre icon"; hint: "The button at the bar's start"; art: iconArt; columns: 6; tileHeight: Theme.fs(58) }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "VISUALIZER AND TRAY" }

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

    Component { id: wsArt; ModuleArt { kind: "workspaceStyle" } }
    Component { id: winArt; ModuleArt { kind: "windowStyle" } }
    Component { id: clockArt; ModuleArt { kind: "clockStyle" } }
    Component { id: iconArt; ModuleArt { kind: "controlIcon" } }
    Component { id: vizArt; ModuleArt { kind: "vizStyle" } }
}
