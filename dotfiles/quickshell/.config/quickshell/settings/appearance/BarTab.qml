// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/BarTab.qml
//
// Appearance's Bar tab, worked from the bar itself: the live preview over
// the tab draws the bar with every module as it's set, and a click on one
// picks it (page.barModule). BAR is the bar's own settings; under it, the
// picked module's: the Control Centre's icon, the workspaces, the open
// windows, the clock, the music or the tray. Numbers are sliders, on/off
// lit chips, and a setting another choice leaves idle rests dimmed. The
// layout of the modules is the bar's own edit mode, not a section here.

import Quickshell
import QtQuick
import "../../services/Styles.js" as Styles
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    id: barTab
    tabId: "bar"

    readonly property string picked: page.barModule
    readonly property var moduleNames: ({ controlcentre: "CONTROL CENTRE", workspaces: "WORKSPACES",
        windows: "OPEN WINDOWS", clock: "CLOCK", music: "MUSIC", tray: "TRAY" })
    // the module a searched field sits under, so a search opens it
    readonly property var fieldModule: ({
        "Control Centre icon": "controlcentre", "Workspaces": "workspaces", "Workspace names": "workspaces",
        "Open windows": "windows", "Window icon size": "windows", "Window icon padding": "windows",
        "Windows shown": "windows", "App icons": "windows", "Clock": "clock", "Clock format": "clock",
        "Clock island": "clock", "Music visualizer": "music", "Music title": "music", "Visualizer": "music",
        "Visualizer bars": "music", "Hide when silent": "music", "Tray drawer": "tray", "Hidden tray icons": "tray",
    })
    Connections {
        target: page
        function onHighlightChanged() {
            var m = barTab.fieldModule[page.highlight]
            if (m) page.barModule = m
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

    Stepper { slider: true; label: "Height"; hint: "Its chips grow with it"; key: "barHeight"; step: 2; suffix: " px" }
    Stepper { slider: true; label: "Icon size"; hint: "The bar's glyphs, at the base font size"; key: "barIconSize"; suffix: " px" }
    Stepper { slider: true; label: "Module padding"; hint: "Room either side of each module"; key: "modulePad"; suffix: " px" }

    SettingsField {
        id: separators
        readonly property bool styleOwns: !Styles.get(Settings.style).options.every(o => o.key !== "barSeparator")
        label: "Separators"
        dimmed: styleOwns
        hint: styleOwns ? Styles.get(Settings.style).name + " sets them itself" : "Between modules"
        Choice { key: "barSeparator"; enabled: !separators.styleOwns }
    }

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

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: barTab.moduleNames[barTab.picked] || "MODULE" }

    SettingsNote { text: "Click a module on the bar above for its settings" }

    // --- Control Centre ----------------------------------------------------

    Tiles {
        visible: barTab.picked === "controlcentre"
        key: "controlIcon"; label: "Control Centre icon"; art: iconArt; columns: 6; tileHeight: Theme.fs(58)
    }

    // --- workspaces --------------------------------------------------------

    Column {
        visible: barTab.picked === "workspaces"
        width: parent.width
        spacing: Theme.spaceM

        Tiles { key: "workspaceStyle"; label: "Workspaces"; art: wsArt }

        // the names the Names workspace style shows, comma-separated in
        // workspace order; a blank one falls back to the number
        SettingsField {
            label: "Workspace names"
            dimmed: Theme.workspaceStyle !== "names"
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
    }

    // --- open windows ------------------------------------------------------

    Column {
        visible: barTab.picked === "windows"
        width: parent.width
        spacing: Theme.spaceM

        Tiles { key: "windowStyle"; label: "Open windows"; art: winArt; columns: 5 }
        Stepper { slider: true; label: "Window icon size"; hint: "App icons, capped to fit the bar's height"; key: "windowIconSize"; suffix: " px" }
        Stepper { slider: true; label: "Window icon padding"; hint: "Room on each side of an app icon"; key: "windowIconPadding"; suffix: " px" }
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

    }

    // --- clock -------------------------------------------------------------

    Column {
        visible: barTab.picked === "clock"
        width: parent.width
        spacing: Theme.spaceM

        Tiles { key: "clockStyle"; label: "Clock"; art: clockArt }
        // the Custom clock style's pattern, in Qt's date format
        SettingsField {
            label: "Clock format"
            dimmed: Theme.clockStyle !== "custom"
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
            defaultKey: "clockIsland"
            hint: !Settings.widgetVisible("clock") ? "Needs the clock on the bar"
                : Settings.clockIsland ? "Volume and layout show in the clock"
                : "Separate toasts under the bar"
            OnChip { on: Settings.clockIsland; onClicked: Settings.setClockIsland(!Settings.clockIsland) }
        }
    }

    // --- music -------------------------------------------------------------

    Column {
        visible: barTab.picked === "music"
        width: parent.width
        spacing: Theme.spaceM

        SettingsField {
            label: "Music visualizer"
            hint: Settings.vizShown ? "The spectrum of everything playing, in place of the player's icon" : "The player's icon"
            OnChip { on: Settings.vizShown; onClicked: Settings.set("vizShown", !Settings.vizShown) }
        }
        SettingsField {
            label: "Music title"
            hint: Settings.musicTitle ? "Artist and title after the spectrum or icon" : "The spectrum or icon alone"
            OnChip { on: Settings.musicTitle; onClicked: Settings.set("musicTitle", !Settings.musicTitle) }
        }
        Tiles { key: "vizStyle"; label: "Visualizer"; hint: "The audio spectrum while sound plays"; art: vizArt }
        Stepper { slider: true; label: "Visualizer bars"; hint: "How many bands"; key: "vizBars" }
        SettingsField {
            label: "Hide when silent"
            hint: Settings.vizHideSilent ? "The Music module shows only while sound plays"
                : "The Music module stays while a player is open"
            OnChip { on: Settings.vizHideSilent; onClicked: Settings.set("vizHideSilent", !Settings.vizHideSilent) }
        }
    }

    // --- tray --------------------------------------------------------------

    Column {
        visible: barTab.picked === "tray"
        width: parent.width
        spacing: Theme.spaceM

        SettingsField {
            label: "Tray drawer"
            hint: Settings.trayDrawer ? "Icons fold behind a chevron" : "Every tray icon shows"
            OnChip { on: Settings.trayDrawer; onClicked: Settings.set("trayDrawer", !Settings.trayDrawer) }
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

    }

    Component { id: wsArt; ModuleArt { kind: "workspaceStyle" } }
    Component { id: winArt; ModuleArt { kind: "windowStyle" } }
    Component { id: clockArt; ModuleArt { kind: "clockStyle" } }
    Component { id: iconArt; ModuleArt { kind: "controlIcon" } }
    Component { id: vizArt; ModuleArt { kind: "vizStyle" } }
}
