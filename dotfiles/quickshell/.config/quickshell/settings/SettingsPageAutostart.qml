// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageAutostart.qml
//
// What runs when you log in: the entries in ~/.config/autostart, the ones
// packages left in /etc/xdg/autostart, and a way to add an installed
// application to either.
//
// Hyprland runs no XDG autostart of its own -- the entries only mean anything
// because ~/.config/singularity/autostart.sh runs them from hyprland.lua, and
// that script's header is where the rules live. The one worth repeating here,
// since it is a surprise otherwise, is that a package's own entry is off
// until it is turned on: the spec says those run by default, but none of them
// has ever run on this machine, and quietly starting four programs the first
// time someone opened this page is not a reasonable way to find that out.
//
// Services are not this page. A program that should come back after a crash,
// or start before the session, is a systemd user unit -- what's in
// dotfiles/systemd -- and the failed ones show up in System > Health.

import Quickshell
import Quickshell.Io
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    sectioned: true

    title: "Startup"
    description: "What starts when you log in."

    Component.onCompleted: Autostart.refresh()

    Connections {
        target: Autostart
        function onWrote(message, isError) { page.say(message, isError) }
    }

    // an icon name or path from a desktop entry, as an image source
    function iconSource(icon) {
        if (!icon) return ""
        return icon.startsWith("/") ? "file://" + icon : Quickshell.iconPath(icon, true)
    }

    // the user units that are enabled, to say which package entries one of
    // them already covers (xdg-user-dirs.desktop and xdg-user-dirs.service)
    property var units: []
    Process {
        running: true
        command: ["systemctl", "--user", "list-unit-files", "--state=enabled", "--no-legend", "--plain"]
        stdout: StdioCollector {
            onStreamFinished: page.units = text.split("\n").map(l => l.split(/\s+/)[0]).filter(u => u !== "")
        }
    }
    function unitFor(entry) {
        var u = entry.file.replace(/\.desktop$/, ".service")
        return units.indexOf(u) >= 0 ? u : ""
    }

    // One entry: its icon, what it is, what it runs, the switch, and Remove
    // for the user's own.
    component Entry: SettingsField {
        id: row
        required property var entry

        image: page.iconSource(entry.icon)
        label: entry.name
        // the command is the honest answer to "what is this", and for an
        // entry with no Comment it is the only one available
        hint: entry.scope === "system" && page.unitFor(entry) !== "" ? "Already run by " + page.unitFor(entry)
            : (entry.runnable ? "" : "Unavailable here · ") + (entry.comment !== "" ? entry.comment : entry.exec)

        // No verticalCenter on anything in here: the field's control slot
        // takes its height from childrenRect, so a child that centres itself
        // in the slot is a binding loop. Centring inside the Row is fine: its
        // height is its tallest child's, whatever their positions.
        Row {
            anchors.right: parent.right
            spacing: Theme.spaceM

            Switch {
                anchors.verticalCenter: parent.verticalCenter
                checked: row.entry.enabled
                // an entry whose TryExec is gone, or that asks for a desktop
                // this isn't, would never run however it is set
                enabled: row.entry.runnable && !AtomicFileWrite.busy
                onToggled: Autostart.setEnabled(row.entry, !row.entry.enabled)
            }

            FlyoutChip {
                visible: row.entry.scope === "user"
                text: "Remove"
                confirmText: "Remove " + row.entry.name + "?"
                enabled: !AtomicFileWrite.busy
                onClicked: Autostart.remove(row.entry)
            }
        }
    }

    // --- at login ------------------------------------------------------------

    FlyoutHeading { text: "AT LOGIN" + (Autostart.userEntries.length > 0 ? "  " + Autostart.userEntries.length : "") }

    FlyoutRow {
        visible: Autostart.loaded && Autostart.userEntries.length === 0
        enabled: false
        label: "Nothing of yours starts at login yet"
    }

    Repeater {
        model: Autostart.userEntries
        Entry {
            required property var modelData
            entry: modelData
        }
    }

    // Add an app…: a search and the matching apps under it, a click adding
    // one, as Add a rule… and Other network… open in place.
    property bool adding: false
    property string query: ""
    // the apps not already starting at login, best matches first
    readonly property var matches: adding
        ? Apps.list(query).filter(a => !Autostart.userEntries.some(e => e.file === a.id + ".desktop"))
        : []
    readonly property int shownMatches: 6

    FlyoutRow {
        label: "Add an app…"
        trailing: "󰐕"
        highlighted: page.adding
        onActivated: {
            page.adding = !page.adding
            page.query = ""
            search.text = ""
            if (page.adding) Qt.callLater(search.forceFocus)
        }
    }

    SettingsIndent {
        visible: page.adding

        Item {
            width: parent.width
            height: search.implicitHeight

            FlyoutInput {
                id: search
                anchors.left: parent.left
                anchors.right: cancel.left
                anchors.rightMargin: Theme.spaceM
                echoPassword: false
                glyph: "󰍉"
                placeholder: "Search apps"
                onTextChanged: page.query = text
                onAccepted: if (page.matches.length > 0) addRow.pick(page.matches[0])
                onEscapePressed: page.adding = false
            }
            FlyoutChip {
                id: cancel
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Cancel"
                onClicked: page.adding = false
            }
        }

        Repeater {
            id: addRow
            function pick(app) {
                Autostart.add(app)
                page.adding = false
            }
            model: page.matches.slice(0, page.shownMatches)

            FlyoutRow {
                required property var modelData
                leadingImage: page.iconSource(modelData.icon)
                leadingIcon: modelData.icon ? "" : "󰣆"
                label: modelData.name
                trailing: modelData.genericName || ""
                onActivated: addRow.pick(modelData)
            }
        }

        FlyoutRow {
            visible: page.matches.length > page.shownMatches
            enabled: false
            label: "and " + (page.matches.length - page.shownMatches) + " more; type to narrow"
        }
        FlyoutRow {
            visible: page.matches.length === 0
            enabled: false
            label: "No app matches"
        }
    }

    // --- from packages ---------------------------------------------------------

    // Only what could run here; entries for other desktops fold away.
    readonly property var packageEntries: Autostart.systemEntries.filter(e => e.runnable)
    readonly property var otherDesktops: Autostart.systemEntries.filter(e => !e.runnable)
    property bool showOthers: false

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "FROM PACKAGES" }

    SettingsNote { text: "Off until you turn one on" }

    Repeater {
        model: page.packageEntries
        Entry {
            required property var modelData
            entry: modelData
        }
    }

    FlyoutRow {
        visible: page.otherDesktops.length > 0
        label: (page.showOthers ? "Hide " : "Show ") + page.otherDesktops.length + " for other desktops"
        trailing: page.showOthers ? "󰅀" : "󰅂"
        onActivated: page.showOthers = !page.showOthers
    }

    SettingsIndent {
        visible: page.showOthers

        Repeater {
            model: page.otherDesktops
            FlyoutRow {
                required property var modelData
                enabled: false
                leadingImage: page.iconSource(modelData.icon)
                leadingIcon: modelData.icon ? "" : "󰣆"
                label: modelData.name
                trailing: modelData.only !== "" ? "Only for " + modelData.only : "Can't run here"
            }
        }
    }

    FlyoutRow {
        visible: Autostart.loaded && Autostart.systemEntries.length === 0
        enabled: false
        label: "No package entries left to add"
    }
}
