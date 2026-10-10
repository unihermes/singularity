// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageAutostart.qml
//
// Which OS the PC starts, on a machine with more than one, then what runs
// when you log in: the entries in ~/.config/autostart, the ones packages
// left in /etc/xdg/autostart, and a way to add an installed application to
// either.
//
// The OS is systemd-boot's default entry. Its menu is hidden, so the
// default is what boots. Both reading the entries and setting the default
// need root, so they go through install.sh's singularity-boot helper and
// pkexec (no password for the active session). The section only shows
// when the helper is there and systemd-boot lists a second OS.
//
// Hyprland runs no XDG autostart of its own -- the entries only mean anything
// because ~/.config/singularity/autostart.sh runs them from autostart.lua, and
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
    description: "What starts when the PC boots and when you log in."

    Component.onCompleted: {
        Autostart.refresh()
        bootRead()
    }

    // --- boot ------------------------------------------------------------------

    readonly property string bootHelper: "/usr/local/bin/singularity-boot"
    // [{ id, text }]: the entries an OS boots from, in menu order -- not the
    // firmware setup, the EFI default loader or the power entries
    property var bootEntries: []
    property string bootDefault: ""
    // what's running now, to say so under the choice
    property string bootSelected: ""
    property bool bootBusy: false

    function bootRead() { bootReader.running = true }

    function bootName(e) {
        if (e.id === "auto-windows") return "Windows"
        if (e.id === "auto-osx") return "macOS"
        return e.showTitle || e.title || e.id
    }

    Process {
        id: bootReader
        command: ["sh", "-c", "[ -x " + page.bootHelper + " ] && exec pkexec " + page.bootHelper + " list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var list
                try { list = JSON.parse(text) } catch (e) { list = [] }
                if (!Array.isArray(list)) list = []
                var oses = list.filter(e => e.type !== "loader" && e.type !== "auto" || /^auto-(windows|osx)$/.test(e.id))
                page.bootEntries = oses.map(e => ({ id: e.id, text: page.bootName(e) }))
                var d = oses.find(e => e.isDefault), s = oses.find(e => e.isSelected)
                page.bootDefault = d ? d.id : ""
                page.bootSelected = s ? s.id : ""
            }
        }
    }

    Process {
        id: bootWriter
        stderr: StdioCollector { id: bootErr }
        onExited: code => {
            page.bootBusy = false
            var e = bootErr.text.trim()
            var name = (page.bootEntries.find(b => b.id === page.bootDefault) || { text: page.bootDefault }).text
            if (code === 0) page.say(name + " starts from now on", false)
            // 126/127: pkexec was dismissed or refused
            else page.say("Not changed" + (e ? ": " + e : ""), true)
            page.bootRead()
        }
    }

    function bootSet(id) {
        bootBusy = true
        bootDefault = id
        bootWriter.command = ["pkexec", bootHelper, "default", id]
        bootWriter.running = true
    }

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

    FlyoutHeading {
        visible: page.bootEntries.length > 1
        text: "WHEN THE PC STARTS"
    }

    SettingsField {
        visible: page.bootEntries.length > 1
        label: "Start"
        hint: page.bootSelected === "" ? "Boots straight in, no menu"
            : "Running " + (page.bootEntries.find(b => b.id === page.bootSelected) || { text: page.bootSelected }).text + " now"

        FlyoutSegmented {
            visible: page.bootEntries.length <= 3
            anchors.right: parent.right
            fill: false
            model: page.bootEntries.map(b => ({ value: b.id, text: b.text }))
            current: page.bootDefault
            enabled: !page.bootBusy
            onPicked: v => page.bootSet(v)
        }
        SettingsDropdown {
            visible: page.bootEntries.length > 3
            anchors.right: parent.right
            width: Theme.fit(220)
            model: page.bootEntries.map(b => b.id)
            labelFor: v => (page.bootEntries.find(b => b.id === v) || { text: v }).text
            current: page.bootDefault
            enabled: !page.bootBusy
            onPicked: v => page.bootSet(v)
        }
    }

    Item {
        visible: page.bootEntries.length > 1
        width: 1
        height: Theme.spaceM
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

    // Only what could run here: an entry for another desktop (GNOME's
    // keyring and accessibility bus) never runs in this session, so it isn't
    // offered at all.
    readonly property var packageEntries: Autostart.systemEntries.filter(e => e.runnable)

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
        visible: Autostart.loaded && page.packageEntries.length === 0
        enabled: false
        label: "No package entries left to add"
    }
}
