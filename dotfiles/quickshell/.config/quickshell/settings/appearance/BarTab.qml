// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/BarTab.qml
//
// The Appearance page's Bar tab.

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    tabId: "bar"

    FlyoutHeading { text: "LAYOUT" }

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

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "MODULES" }

    SettingsField {
        label: "Control Centre icon"
        hint: "The button at the bar's start"
        Choice { key: "controlIcon"; glyphs: Theme.controlGlyphs }
    }

    SettingsField {
        label: "Visualizer"
        hint: "The audio spectrum while sound plays"
        Choices { key: "vizStyle" }
    }

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

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "WORKSPACES" }

    SettingsField {
        label: "Workspaces"
        hint: "How the workspace indicator marks each one"
        Choice { key: "workspaceStyle" }
    }

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

    SettingsField {
        label: "Open windows"
        hint: "How open windows are drawn"
        Choice { key: "windowStyle" }
    }

    SettingsField {
        label: "Windows shown"
        hint: "All workspaces, grouped with a rule"
        Choices { key: "windowScope" }
    }

    SettingsField {
        label: "App icons"
        hint: "The open windows' and the tray's"
        Choices { key: "iconTint" }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "CLOCK" }

    SettingsField {
        label: "Clock"
        hint: "What the clock chip shows"
        Choice { key: "clockStyle" }
    }

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

}
