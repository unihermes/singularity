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

import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    sectioned: true

    title: "Startup"
    description: "What starts at login, as entries in ~/.config/autostart."

    // the app picked in the Add row, held until + Add is clicked
    property var chosen: null

    readonly property var apps: Apps.list("")

    Component.onCompleted: Autostart.refresh()

    Connections {
        target: Autostart
        function onWrote(message, isError) { page.say(message, isError) }
    }

    // One entry: what it is, what it runs, and the chips that change it.
    component Entry: SettingsField {
        id: row
        required property var entry

        label: entry.name
        // the command is the honest answer to "what is this", and for an
        // entry with no Comment it is the only one available
        hint: (entry.runnable ? "" : "Unavailable here · ")
            + (entry.comment !== "" ? entry.comment : entry.exec)

        // No verticalCenter on anything in here: the field's control slot
        // takes its height from childrenRect, so a child that centres itself
        // in the slot is a binding loop. Centring inside the Row is fine: its
        // height is its tallest child's, whatever their positions.
        Row {
            anchors.right: parent.right
            spacing: Theme.spaceS

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
                confirmText: "Confirm"
                enabled: !AtomicFileWrite.busy
                onClicked: Autostart.remove(row.entry)
            }
        }
    }

    FlyoutHeading { text: "AT LOGIN" }

    FlyoutRow {
        visible: Autostart.loaded && Autostart.userEntries.length === 0
        enabled: false
        label: "Nothing starts at login yet"
    }

    Repeater {
        model: Autostart.userEntries
        Entry {
            required property var modelData
            entry: modelData
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "ADD AN APPLICATION" }

    SettingsField {
        label: "Application"
        hint: "Adds a desktop entry to ~/.config/autostart"

        // An Item of its own height rather than a Row, so the dropdown and
        // the button can centre against something fixed -- see the note in
        // Entry above for why centring against the slot itself cannot work.
        Item {
            anchors.right: parent.right
            width: picker.width + Theme.spaceS + addChip.width
            height: Theme.rowHeightTall

            SettingsDropdown {
                id: picker
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.fit(240)
                model: page.apps
                current: page.chosen
                placeholder: "Choose an application…"
                labelFor: v => v ? v.name : ""
                onPicked: v => page.chosen = v
            }

            FlyoutChip {
                id: addChip
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                // as tall as the box beside it, so the two read as one control
                height: picker.height
                text: "+ Add"
                enabled: page.chosen !== null && !AtomicFileWrite.busy
                onClicked: {
                    Autostart.add(page.chosen)
                    page.chosen = null
                }
            }
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "FROM INSTALLED PACKAGES" }

    SettingsNote { text: "Off until turned on; some repeat a user unit" }

    Repeater {
        model: Autostart.systemEntries
        Entry {
            required property var modelData
            entry: modelData
        }
    }

    FlyoutRow {
        visible: Autostart.loaded && Autostart.systemEntries.length === 0
        enabled: false
        label: "No package entries left to add"
    }
}
